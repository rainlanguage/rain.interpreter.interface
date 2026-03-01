# Security Audit: LibBytecode.sol

**Auditor:** Agent A01
**Date:** 2026-03-01
**File:** `/src/lib/bytecode/LibBytecode.sol`
**Error definitions:** `/src/error/ErrBytecode.sol`

---

## Evidence of Thorough Reading

### Library

`LibBytecode` (line 29), a Solidity library for inspecting Rain interpreter bytecode headers.

### Functions (with line numbers)

| Function | Line |
|---|---|
| `sourceCount(bytes memory bytecode)` | 44 |
| `checkNoOOBPointers(bytes memory bytecode)` | 70 |
| `sourceRelativeOffset(bytes memory bytecode, uint256 sourceIndex)` | 188 |
| `sourcePointer(bytes memory bytecode, uint256 sourceIndex)` | 209 |
| `sourceOpsCount(bytes memory bytecode, uint256 sourceIndex)` | 227 |
| `sourceStackAllocation(bytes memory bytecode, uint256 sourceIndex)` | 246 |
| `sourceInputsOutputsLength(bytes memory bytecode, uint256 sourceIndex)` | 272 |
| `bytecodeToSources(bytes memory bytecode)` | 291 |

### Imports

- `LibPointer`, `Pointer` from `rain.solmem/lib/LibPointer.sol` (line 5)
- `LibBytes` from `rain.solmem/lib/LibBytes.sol` (line 6)
- `LibMemCpy` from `rain.solmem/lib/LibMemCpy.sol` (line 7)
- Seven custom errors from `../../error/ErrBytecode.sol` (lines 8-16)

### Custom Errors (from ErrBytecode.sol)

| Error | Description |
|---|---|
| `SourceIndexOutOfBounds(uint256, bytes)` | Source index out of bounds |
| `UnexpectedSources(bytes)` | 0 sources declared but trailing bytes exist |
| `UnexpectedTrailingOffsetBytes(bytes)` | Bytes between offsets and sources |
| `TruncatedSource(bytes)` | Source end does not match next source/end |
| `TruncatedHeader(bytes)` | Offset points past where header fits |
| `TruncatedHeaderOffsets(bytes)` | Bytecode truncated before offsets end |
| `StackSizingsNotMonotonic(bytes, uint256)` | inputs > outputs or outputs > allocation |

### Using declarations (lines 30-32)

- `LibPointer for Pointer`
- `LibBytes for bytes`
- `LibMemCpy for Pointer`

---

## Security Findings

### A01-1 | INFO | Reliance on caller discipline for bounds safety

**Lines:** 200-285 (functions `sourcePointer`, `sourceOpsCount`, `sourceStackAllocation`, `sourceInputsOutputsLength`)

**Description:** The functions `sourceOpsCount` (line 227), `sourceStackAllocation` (line 246), `sourceInputsOutputsLength` (line 272), and `sourcePointer` (line 209) all rely on the caller having previously called `checkNoOOBPointers`. Each function's NatSpec documents this requirement with "Callers MUST `checkNoOOBPointers` BEFORE attempting to traverse the bytecode." If a caller omits this prerequisite, `sourcePointer` could return a pointer to memory outside the bytecode allocation, and the subsequent `mload` in `sourceOpsCount` / `sourceStackAllocation` / `sourceInputsOutputsLength` would read arbitrary memory. This is an architectural pattern documented by design, but any consumer of the library that misses the prerequisite would silently read garbage data rather than revert.

This is noted as INFO because the NatSpec is explicit about the contract, and there is no way to enforce this at the library level without duplicating the full validation check in every accessor.

---

### A01-2 | LOW | `bytecodeToSources` does not call `checkNoOOBPointers` internally

**Lines:** 291-316

**Description:** The function `bytecodeToSources` iterates over sources using `sourcePointer` and `sourceOpsCount` (lines 297-298) but does not call `checkNoOOBPointers` first. If called on malformed bytecode, the `sourcePointer` call at line 297 could return a pointer outside the bytecode memory, and the `unsafeCopyBytesTo` at line 300 would then copy from that out-of-bounds location into a newly allocated `bytes` array. This could read arbitrary memory contents from the EVM process memory (within the same transaction context).

The function is documented as "not recommended for production code but useful for testing" (line 290), which mitigates the severity. However, a test helper that silently reads out-of-bounds memory could mask bugs rather than surface them.

**Recommendation:** Consider adding a `checkNoOOBPointers(bytecode)` call at the beginning of `bytecodeToSources`, or at minimum documenting the prerequisite in the NatSpec the same way the other functions do.

---

### A01-3 | INFO | `checkNoOOBPointers` allows sources with zero opcodes

**Lines:** 136, 150-153

**Description:** A source header may declare `opsCount = 0` (line 136). In that case, `sourceEnd = headerEnd + 0 * 4 = headerEnd` (line 150). This is a valid 4-byte source (header only, no opcode body). The validation passes because `sourceEnd == endCursor` is checked at line 151. This is correct behavior and does not represent a vulnerability, but consumers of the library should be aware that a source may contain zero opcodes and handle that case accordingly if they iterate over opcodes.

---

### A01-4 | INFO | `unchecked` arithmetic throughout `checkNoOOBPointers` is safe

**Lines:** 71-176

**Description:** The entire `checkNoOOBPointers` body is wrapped in `unchecked` (line 71). The arithmetic operations within are:

- `sourcesRelativeStart = 1 + count * 2` (line 75): `count` is at most 255 (a single byte), so this is at most `1 + 510 = 511`. No overflow possible.
- `headerEnd = absoluteOffset + 4` (line 115): `absoluteOffset` is a memory pointer. Adding 4 to a valid memory pointer cannot overflow a `uint256`.
- `sourceEnd = headerEnd + opsCount * 4` (line 150): `opsCount` is at most 255 (a single byte), so `opsCount * 4` is at most 1020. Adding this to a memory pointer cannot overflow.
- `uncheckedOffsetCursor -= 2` (line 158): The loop condition `uncheckedOffsetCursor >= end` at line 104 ensures this only executes while the cursor is at or above `end`. Since `end = bytecode + 0x21` and `uncheckedOffsetCursor` starts at `bytecode + 0x21 + (count-1)*2`, the subtraction always keeps the value at or above `bytecode + 0x1F` (one step past the valid range, which terminates the loop). No underflow to a dangerously large value occurs because the `while (>=)` check guards re-entry.

All unchecked arithmetic is safe. No overflow or underflow vulnerabilities identified.

---

### A01-5 | INFO | Loop termination in `checkNoOOBPointers` relies on unsigned underflow guard

**Lines:** 100-104, 158

**Description:** The backward iteration uses `while (uncheckedOffsetCursor >= end)` at line 104, where `uncheckedOffsetCursor` is decremented by 2 at line 158 inside `unchecked`. When `count == 1`, `uncheckedOffsetCursor` starts equal to `end` (both are `bytecode + 0x21`). After the single iteration, `uncheckedOffsetCursor -= 2` would set it to `bytecode + 0x1F`, which is less than `end`, so the loop terminates correctly.

If `count > 1`, the cursor walks backwards through each 2-byte offset slot. When the cursor reaches the first offset (at `end`), it processes it and then decrements once more, again going below `end`.

Because this is `unchecked` and both values are raw memory pointers (large positive numbers), the subtraction `(bytecode + 0x21) - 2 = bytecode + 0x1F` does not underflow to a dangerous value. The loop terminates correctly. This is safe as implemented.

---

### A01-6 | LOW | `checkNoOOBPointers` does not enforce monotonically increasing offsets

**Lines:** 104-159

**Description:** The backward validation loop checks that each source's `absoluteOffset + 4 + opsCount * 4 == endCursor`, ensuring sources are contiguous and non-overlapping when read backwards. However, it does not explicitly verify that offsets are monotonically increasing (i.e., `offset[i] < offset[i+1]`). This is implicitly enforced: since the loop walks backwards and checks `sourceEnd == endCursor`, then sets `endCursor = absoluteOffset`, any offset that is not strictly less than the next would cause a `TruncatedHeader` or `TruncatedSource` revert (the header check at line 116 would fail because `absoluteOffset + 4 > endCursor`).

This implicit enforcement is correct but relies on the contiguity check rather than an explicit ordering check. If a future refactor altered the contiguity logic, the ordering guarantee could be silently lost.

---

### A01-7 | INFO | `sourceRelativeOffset` memory read alignment

**Line:** 196

**Description:** In `sourceRelativeOffset`, the assembly reads a 2-byte offset via:
```
offset := and(mload(add(add(bytecode, 3), mul(sourceIndex, 2))), 0xFFFF)
```
This loads a 32-byte word starting at `bytecode + 3 + sourceIndex * 2`, then masks to the lowest 16 bits. Since `mload` always reads 32 bytes, the 2-byte offset value ends up in the least significant 16 bits of the loaded word. This is correct because:
- The offset bytes are at positions `bytecode + 0x20 + 1 + sourceIndex*2` and `bytecode + 0x20 + 1 + sourceIndex*2 + 1` in memory.
- `bytecode + 3 + sourceIndex*2` points to `bytecode_data_start - 0x1D + sourceIndex*2`, so the last 2 bytes of the 32-byte word loaded are exactly the offset bytes.

Wait: `add(bytecode, 3) = bytecode + 3`. `mload(bytecode + 3)` reads 32 bytes from `bytecode + 3`, which gives bytes at memory positions `[bytecode+3, bytecode+3+32)` = `[bytecode+3, bytecode+35)`. The last 2 bytes of this are at `bytecode+33` and `bytecode+34`, i.e., `bytecode+0x21` and `bytecode+0x22`. These are the first offset (at index 0). For `sourceIndex = 0`, `add(add(bytecode, 3), 0) = bytecode + 3`, last two bytes = positions `bytecode + 0x22` and `bytecode + 0x23` which is bytes `[2]` and `[3]` of the bytecode data (0-indexed). But the first offset starts at byte index 1 (positions `bytecode + 0x21` and `bytecode + 0x22`).

Correction: `mload(bytecode + 3)` loads 32 bytes. The 16-bit value extracted via `and(..., 0xFFFF)` takes the lowest 2 bytes, at positions `bytecode + 3 + 30` and `bytecode + 3 + 31` = `bytecode + 33` and `bytecode + 34` = `bytecode + 0x21` and `bytecode + 0x22`. These are data bytes at indices 1 and 2 of the bytecode (the first 2-byte offset pointer for `sourceIndex == 0`). This is correct.

No issue found. The read is correctly aligned.

---

### A01-8 | INFO | `bytecodeToSources` legacy opcode byte shifting

**Lines:** 303-311

**Description:** In the legacy conversion loop:
```solidity
mstore8(add(cursor, 1), byte(0, mload(cursor)))
mstore8(cursor, 0)
```
For each 4-byte opcode, this reads the first byte (the opcode index), writes it into the second byte position (the input position in legacy format), then zeros the first byte. This is a destructive in-place transformation of the freshly copied `source` bytes array. Since the source was copied into a new allocation at line 299-300, this does not corrupt the original bytecode. The logic correctly implements the legacy format transformation where opcode index moves from byte 0 to byte 1, and byte 0 becomes 0.

No issue found.

---

## Summary

No CRITICAL or HIGH severity issues were identified. The library implements careful bounds checking in `checkNoOOBPointers` that, when called as a prerequisite, ensures all subsequent accessor functions operate within valid memory. The primary risk pattern is the reliance on callers to invoke `checkNoOOBPointers` before using accessor functions, which is documented but not enforced.

| Severity | Count |
|---|---|
| CRITICAL | 0 |
| HIGH | 0 |
| MEDIUM | 0 |
| LOW | 2 |
| INFO | 5 |
