<!-- SPDX-License-Identifier: LicenseRef-DCL-1.0 -->
<!-- SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd -->

# Pass 1 Security Review: LibBytecode

**Agent:** A11
**File:** `src/lib/bytecode/LibBytecode.sol`
**Date:** 2026-03-04

---

## Evidence of Thorough Reading

### Library Name
- `LibBytecode` (line 29)

### Functions (with line numbers)
| Function | Line |
|---|---|
| `sourceCount` | 44 |
| `checkNoOOBPointers` | 72 |
| `sourceRelativeOffset` | 190 |
| `sourcePointer` | 211 |
| `sourceOpsCount` | 229 |
| `sourceStackAllocation` | 248 |
| `sourceInputsOutputsLength` | 274 |
| `bytecodeToSources` | 297 |

### Errors Imported (from `src/error/ErrBytecode.sol`)
| Error | Imported at Line |
|---|---|
| `StackSizingsNotMonotonic(bytes, uint256)` | 9 |
| `TruncatedSource(bytes)` | 10 |
| `UnexpectedTrailingOffsetBytes(bytes)` | 11 |
| `TruncatedHeader(bytes)` | 12 |
| `TruncatedHeaderOffsets(bytes)` | 13 |
| `UnexpectedSources(bytes)` | 14 |
| `SourceIndexOutOfBounds(uint256, bytes)` | 15 |

### Types / Imports
- `LibPointer` from `rain.solmem/lib/LibPointer.sol` (line 5)
- `Pointer` from `rain.solmem/lib/LibPointer.sol` (line 5)
- `LibBytes` from `rain.solmem/lib/LibBytes.sol` (line 6)
- `LibMemCpy` from `rain.solmem/lib/LibMemCpy.sol` (line 7)

### Constants / Storage
None. All functions are `internal pure`.

---

## Security Findings

### P1-A11-1 — Unenforced prerequisite for `checkNoOOBPointers` across reading functions (LOW)

**Functions:** `sourceRelativeOffset` (line 190), `sourcePointer` (line 211), `sourceOpsCount` (line 229), `sourceStackAllocation` (line 248), `sourceInputsOutputsLength` (line 274), `bytecodeToSources` (line 297)

**Description:**

Every reading function other than `checkNoOOBPointers` carries a NatSpec warning that callers MUST invoke `checkNoOOBPointers` before calling it. There is no on-chain enforcement of this prerequisite. If any of these functions is invoked on structurally malformed bytecode (e.g. a `bytecode` buffer shorter than `1 + sourceCount * 2` bytes) without the prior integrity check, the assembly reads may access memory at addresses that are within the source-count-validated range of the offset table index but whose actual byte content was not verified to be within the allocated region.

Concrete example for `sourceRelativeOffset`:

The assembly computes the effective read address as `bytecode + 0x21 + sourceIndex * 2` (from the low 16 bits of `mload(bytecode + 3 + sourceIndex * 2)`). For `sourceIndex = 0` on a 2-byte buffer (one count byte, one offset byte instead of two), `mload` reads starting at `bytecode + 3` and takes the byte at `bytecode + 34` (`bytecode + 0x22`), which is one byte past the Solidity-allocated region for that buffer. This is not protected by the `sourceIndex < sourceCount` bounds check already present in `sourceRelativeOffset`; the bounds check only validates the index against the declared source count, not whether the offset table bytes themselves fit within the buffer.

The practical risk is mitigated by:
1. The clear NatSpec documentation.
2. `checkNoOOBPointers` itself being a pure function that must be called at deploy time before any downstream opcode integrity checking.
3. In production paths (Expression Deployer), the prerequisite is enforced by construction.

**Classification:** LOW — requires caller error (omitting the prerequisite check) and produces undefined reads from adjacent zero-padded or zero-initialised memory rather than exploitable memory corruption. No write paths are affected.

**References:** Lines 183-199, 204-219, 224-236, 242-259, 264-287, 292-322.

---

### P1-A11-2 — `mload` overread past bytecode allocation in `memory-safe` assembly (INFO)

**Functions:** `checkNoOOBPointers` (line 136), `sourceRelativeOffset` (line 195), `sourceCount` (line 48)

**Description:**

Several assembly blocks are annotated `("memory-safe")` but perform `mload` instructions that may read up to 31 bytes past the last valid byte of the `bytecode` allocation:

- In `checkNoOOBPointers` (line 136–142): `mload(absoluteOffset)` reads 32 bytes from the start of a source header. Only `byte(0..3)` are used; the remaining 28 bytes may fall past the end of the `bytecode` buffer when the source header is near the end of the buffer.
- In `sourceRelativeOffset` (line 195–199): `mload(bytecode + 3 + sourceIndex * 2)` reads 32 bytes; the low 16 bits (bytes at positions `+30` and `+31` relative to the load address) are used. When those bytes are at the end of the offset table, the other 30 loaded bytes are past the allocation.
- In `sourceCount` (line 51): `mload(add(bytecode, 0x20))` reads 32 bytes from the start of the data section. Only `byte(0, ...)` (the most-significant byte of the loaded word) is used.

The Solidity allocator always pads allocations to 32-byte boundaries, so in most cases the overread falls into the intra-allocation zero-padding. However, when `bytecode.length % 32 == 0`, there is no padding and the `mload` reads 28 bytes past the free-memory pointer into uninitialised EVM memory (which the EVM guarantees to be zero on first access).

In a `pure` function context with no intervening allocations, the overread values are deterministically zero and the only bytes consumed are those within the verified bounds. There is no practical exploitability, but the `memory-safe` annotation may be technically imprecise for this edge case, which could affect optimiser behaviour in future compiler versions.

**Classification:** INFO — no current exploitability; documents a latent interaction with future Solidity optimiser assumptions.

---

### P1-A11-3 — `TruncatedSource` error fires for bytecode overrun as well as truncation (INFO)

**Location:** `checkNoOOBPointers`, line 153–155

**Description:**

```solidity
uint256 sourceEnd = headerEnd + opsCount * 4;
if (sourceEnd != endCursor) {
    revert TruncatedSource(bytecode);
}
```

The strict equality check `sourceEnd != endCursor` correctly rejects both:
- Sources shorter than the remaining bytecode (`sourceEnd < endCursor`), and
- Sources that would overrun the bytecode bounds (`sourceEnd > endCursor`).

The error name `TruncatedSource` semantically implies only the first case. When `sourceEnd > endCursor`, the source header claims more opcodes than bytes remain — this is an overrun, not a truncation. Consuming this error in off-chain tooling or monitoring that treats `TruncatedSource` as "bytecode was cut short" may misclassify the overrun case.

This is a naming/documentation issue only; the safety logic is correct.

**Classification:** INFO — no exploitable security impact; purely a semantic clarity issue for error consumers.

---

### P1-A11-4 — Implicit reliance on `relativeOffset[0] == 0` without explicit assertion (INFO)

**Location:** `checkNoOOBPointers`, lines 162–168

**Description:**

The bytecode format requires that the first source's relative offset is always 0 (the sources section starts immediately at `sourcesStart`). This invariant is not checked with an explicit `assert` or guard; instead it is enforced implicitly by the final equality check:

```solidity
if (endCursor != sourcesStart) {
    revert UnexpectedTrailingOffsetBytes(bytecode);
}
```

After the loop processes all sources in reverse, `endCursor` is set to the absolute address of source 0's header, which equals `sourcesStart + relativeOffset[0]`. If `relativeOffset[0] != 0`, `endCursor != sourcesStart` and `UnexpectedTrailingOffsetBytes` is emitted.

The error name `UnexpectedTrailingOffsetBytes` implies bytes between the offset table and the first source body — which is exactly what a non-zero `relativeOffset[0]` would represent. The check is correct and the error name is appropriate.

However, the implicit nature of this invariant (no direct comparison `relativeOffset[sourceIndex=0] == 0`) makes the code less obvious to future maintainers. A comment explaining why the final equality check enforces this invariant would improve maintainability.

**Classification:** INFO — no security impact; documentation/clarity suggestion.

---

### P1-A11-5 — No arithmetic overflow risk confirmed (INFO)

**Description:**

All arithmetic in `unchecked` blocks was verified to be bounded:

- `sourceCount` returns at most 255 (extracted from a single byte via `byte(0, ...)`).
- `sourcesRelativeStart = 1 + count * 2`: maximum 511, no overflow.
- `relativeOffset` (from `shr(0xF0, ...)` or low 16 bits): maximum 65535.
- `opsCount` (from `byte(0, ...)`): maximum 255.
- `opsCount * 4`: maximum 1020, no overflow.
- `sourceEnd = headerEnd + opsCount * 4`: bounded by practical EVM memory limits, no overflow.

No division operations exist anywhere in the library. No division-by-zero risk.

**Classification:** INFO — no findings; recorded for completeness.

---

### P1-A11-6 — Stack sizing check is minimal by design (INFO)

**Location:** `checkNoOOBPointers`, lines 144–146

**Description:**

```solidity
if (inputs > outputs || outputs > stackAllocation) {
    revert StackSizingsNotMonotonic(bytecode, relativeOffset);
}
```

This check enforces `inputs <= outputs <= stackAllocation` as a necessary but not sufficient condition. It does not verify that `stackAllocation` is consistent with actual opcode behaviour, that inputs are correctly consumed, or that outputs match what each opcode produces. The NatSpec comment explicitly acknowledges this:

> "We can't know exactly what they need to be according to the opcodes without checking every opcode implementation"

The design delegates deep integrity validation to the Expression Deployer. This is appropriate for the library's stated role as a structural (not semantic) validator.

No security issue exists within `LibBytecode` itself. However, downstream consumers that call `checkNoOOBPointers` without subsequently running Expression Deployer integrity checks could accept semantically invalid bytecode where `stackAllocation = 255, outputs = 255, inputs = 0` regardless of actual opcode requirements.

**Classification:** INFO — by design; documented. Risk lives in the deployment pipeline, not in this library.

---

### P1-A11-7 — `bytecodeToSources` performs redundant `sourcePointer` calls per iteration (INFO)

**Location:** `bytecodeToSources`, lines 303–304

**Description:**

```solidity
Pointer pointer = sourcePointer(bytecode, i).unsafeAddBytes(4);
uint256 length = sourceOpsCount(bytecode, i) * 4;
```

`sourceOpsCount` internally calls `sourcePointer` (line 231), which internally calls both `sourceCount` and `sourceRelativeOffset`. This means for each loop iteration, `sourceCount` (reads bytecode first byte) and `sourceRelativeOffset` (reads the offset table) are each called twice: once through the explicit `sourcePointer` call and once through `sourceOpsCount`. Since this function is already marked as not recommended for production code, the gas cost is acceptable. No security issue.

**Classification:** INFO — efficiency note; no security impact.

---

## Summary Table

| ID | Title | Severity |
|---|---|---|
| P1-A11-1 | Unenforced prerequisite for `checkNoOOBPointers` across reading functions | LOW |
| P1-A11-2 | `mload` overread past bytecode allocation in `memory-safe` assembly | INFO |
| P1-A11-3 | `TruncatedSource` error fires for bytecode overrun as well as truncation | INFO |
| P1-A11-4 | Implicit reliance on `relativeOffset[0] == 0` without explicit assertion | INFO |
| P1-A11-5 | No arithmetic overflow risk confirmed | INFO |
| P1-A11-6 | Stack sizing check is minimal by design | INFO |
| P1-A11-7 | `bytecodeToSources` performs redundant `sourcePointer` calls per iteration | INFO |
