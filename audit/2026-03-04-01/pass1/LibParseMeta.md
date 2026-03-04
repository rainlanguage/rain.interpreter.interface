<!-- SPDX-License-Identifier: LicenseRef-DCL-1.0 -->
<!-- SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd -->

# Pass 1 Security Review — LibParseMeta.sol

**Date:** 2026-03-04
**Agent:** A16
**File:** `src/lib/parse/LibParseMeta.sol`
**Scope:** Bloom filter + fingerprint-based word lookup library

---

## Evidence of Thorough Reading

**File:** `src/lib/parse/LibParseMeta.sol`
**License:** LicenseRef-DCL-1.0 (REUSE compliant; SPDX header at line 1)
**Copyright:** Copyright (c) 2020 Rain Open Source Software Ltd (line 2)
**Pragma:** `^0.8.25` (line 3)

### Imports

| Line | Import |
|------|--------|
| 5 | `LibCtPop` from `rain.math.binary/lib/LibCtPop.sol` |

### Constants

| Line | Name | Value | Meaning |
|------|------|-------|---------|
| 8 | `META_ITEM_SIZE` | `4` | 1 byte opcode index + 3 byte fingerprint |
| 11 | `META_PREFIX_SIZE` | `1` | 1 byte depth field |
| 23 | `FINGERPRINT_MASK` | `0xFFFFFF` | Low 3 bytes; 3-byte fingerprint |
| 26 | `META_EXPANSION_SIZE` | `0x21` (33) | 32-byte bloom expansion + 1-byte seed |

### Errors

| Line | Signature | Parameters |
|------|-----------|------------|
| 32 | `InvalidParseMeta(uint256 expected, uint256 actual)` | expected vs actual byte length |

### Library

**Library name:** `LibParseMeta` (line 38)

### Functions

| Line | Name | Visibility | Mutability | Description |
|------|------|------------|------------|-------------|
| 45 | `checkParseMetaStructure(bytes memory meta)` | `internal` | `pure` | Validates structural consistency of parse meta bytes; reverts with `InvalidParseMeta` on mismatch |
| 86 | `wordBitmapped(uint256 seed, bytes32 word)` | `internal` | `pure` | Computes single-bit bloom bitmap and 3-byte fingerprint for a word/seed pair; returns `(bitmap, hashed)` |
| 123 | `lookupWord(bytes memory meta, bytes32 word)` | `internal` | `pure` | Searches parse meta for a word; returns `(exists, index)` |

### Assembly Blocks

| Function | Lines | Annotation | Purpose |
|----------|-------|------------|---------|
| `checkParseMetaStructure` | 49-51 | `memory-safe` | Read depth byte from meta |
| `checkParseMetaStructure` | 53-55 | `memory-safe` | Initialise cursor to `meta+1` |
| `checkParseMetaStructure` | 58-63 | `memory-safe` | Advance cursor; load expansion word per depth layer |
| `wordBitmapped` | 87-109 | `memory-safe` | Write word+seed to scratch space; keccak256; derive bitmap and fingerprint |
| `lookupWord` | 131-138 | `memory-safe` | Read depth; compute `end` and `dataStart` |
| `lookupWord` | 149-154 | `memory-safe` | Read seed and expansion per layer |
| `lookupWord` | 168-170 | `memory-safe` | Load raw 32-byte item slot from data region |
| `lookupWord` | 176-178 | `memory-safe` | Extract opcode index byte |

---

## Security Findings

### P1-A16-1 — Protofire M01 Fix Verified: Bit Check Present Before Fingerprint Comparison (INFO)

**Classification:** INFO

**Location:** `src/lib/parse/LibParseMeta.sol`, line 161

**Observation:**

The Protofire audit identified M01: the bloom filter bit for a candidate word was not verified to be set in the expansion before proceeding to a fingerprint comparison. This would allow false positive matches when a word's fingerprint happened to match an item placed by a different bit.

The current code at line 161 correctly applies the bit check before any fingerprint read:

```solidity
if (expansion & shifted == 0) {
    return (false, 0);
}
```

This check is reached only after reading the expansion (line 153) and computing `shifted` via `wordBitmapped` (line 156). The item load (`posData`, line 169) and fingerprint comparison (line 174) are unreachable unless the bit is confirmed set. The fix is correctly applied and complete.

No remediation required.

---

### P1-A16-2 — Protofire L04 Fix Verified: Structural Validation Exists (INFO)

**Classification:** INFO

**Location:** `src/lib/parse/LibParseMeta.sol`, lines 45-69; `src/lib/codegen/LibGenParseMeta.sol`, line 250

**Observation:**

The Protofire audit identified L04: `lookupWord` performed no structural validation of the `meta` parameter, leaving it undefined for malformed input.

The resolution is `checkParseMetaStructure` (lines 45-69). It reads the depth byte, iterates over every expansion layer using `LibCtPop.ctpop` to accumulate the total item count, computes `expected = META_PREFIX_SIZE + depth * META_EXPANSION_SIZE + totalItems * META_ITEM_SIZE`, and reverts with `InvalidParseMeta` if `meta.length` does not match. This is called unconditionally at the end of `buildParseMetaV2` (line 250 of `LibGenParseMeta.sol`), ensuring every generated meta blob is structurally validated at build time.

`lookupWord` NatSpec (lines 117-118) explicitly documents the precondition: meta MUST be well-formed, and callers should invoke `checkParseMetaStructure` to validate externally-sourced meta. This is a reasonable design: validate once at build/load time, skip per-lookup overhead.

No remediation required.

---

### P1-A16-3 — dataStart Pointer Arithmetic: Off-by-28 Is Intentional and Correct (INFO)

**Classification:** INFO

**Location:** `src/lib/parse/LibParseMeta.sol`, lines 131-138, 168-170

**Observation:**

`lookupWord` computes `dataStart` as follows (lines 131-138):

```solidity
cursor := add(meta, 1)
let depth := and(mload(cursor), 0xFF)
end := add(cursor, mul(depth, metaExpansionSize))
dataStart := add(end, metaItemSize)
```

This gives `dataStart = meta_ptr + 1 + depth*33 + 4 = meta_ptr + 5 + depth*33`.

The actual first item in the `bytes` content resides at `meta_ptr + 0x20 + 1 + depth*33 = meta_ptr + 33 + depth*33`. So `dataStart` is exactly 28 bytes (`0x20 - META_ITEM_SIZE = 32 - 4 = 28`) before the first content item.

This is intentional. `mload` reads 32 bytes. By setting `dataStart` to 28 bytes before item 0, `mload(dataStart + pos * 4)` places item `pos` in the **lowest 4 bytes** of the loaded 256-bit word. The callers then extract data correctly:

- `byte(28, posData)`: extracts byte at offset 28 from the MSB of the 32-byte word = first byte of item `pos` = opcode index.
- `posData & FINGERPRINT_MASK`: extracts low 3 bytes = fingerprint bytes of item `pos`.

This trick is consistent between `buildParseMetaV2` (which uses the same `dataStart` formula for writes) and `lookupWord` (which uses it for reads). Both are aligned. No data corruption is possible.

Bounds safety: for `depth >= 1`, `dataStart >= meta_ptr + 38 > meta_ptr + 32` (content start), so no read is issued before the allocated region. For `depth = 0`, the `while (cursor < end)` loop does not execute and `mload(dataStart)` is never called.

No remediation required.

---

### P1-A16-4 — wordBitmapped: Scratch-Space Usage Is Safe and Memory-Safe Annotated (INFO)

**Classification:** INFO

**Location:** `src/lib/parse/LibParseMeta.sol`, lines 87-109

**Observation:**

`wordBitmapped` uses EVM scratch space (addresses `0x00–0x20`, 33 bytes) for the keccak input:

```assembly
mstore(0, word)       // bytes 0x00-0x1F
mstore8(0x20, seed)   // byte 0x20
hashed := keccak256(0, 0x21)
```

The EVM ABI scratch space is `0x00–0x3F` (64 bytes). The function uses exactly 33 bytes, well within the designated region. The free memory pointer at `0x40` is not modified. The `memory-safe` annotation is accurate: no Solidity-managed allocations are disturbed.

No remediation required.

---

### P1-A16-5 — wordBitmapped: Fingerprint-Zero Remapping Is Correct and Negligible Bias (INFO)

**Classification:** INFO

**Location:** `src/lib/parse/LibParseMeta.sol`, lines 98-108

**Observation:**

`wordBitmapped` remaps fingerprint zero to one:

```assembly
if iszero(and(hashed, 0xFFFFFF)) { hashed := 1 }
```

This is necessary because `0` is the empty-slot sentinel in `buildParseMetaV2`. The in-code comment (lines 98-108) accurately analyses the bias: two words independently hashing to fingerprint 0 (~1 in 2^24 each) would both map to fingerprint 1, appearing as a `DuplicateFingerprint` during generation (a ~1 in 2^46 event). The overall collision probability changes from 1/2^24 to (2^24+2)/2^48, which is negligibly different.

The test `testWordBitmappedFingerprintNonZero` in `test/src/lib/parse/LibParseMeta.wordBitmapped.t.sol` fuzz-verifies this invariant. No false negatives from lookup are possible: `buildParseMetaV2` always writes non-zero fingerprints, and `lookupWord` never mistakes an empty slot for a match.

No remediation required.

---

### P1-A16-6 — lookupWord: Early Return on Bit Miss Is Correct for Multi-Depth Construction (INFO)

**Classification:** INFO

**Location:** `src/lib/parse/LibParseMeta.sol`, lines 161-163

**Observation:**

```solidity
if (expansion & shifted == 0) {
    return (false, 0);
}
```

This early return on the layer-0 bit miss is correct. In `buildParseMetaV2`, layer 0's expansion is computed as the bitwise OR of `wordBitmapped(seed, word).bitmap` for **all** words in the authoring meta. Therefore, if a word is present in the meta, its bloom bit is guaranteed to be set in layer 0's expansion. A miss at layer 0 proves the word is absent from the meta entirely.

Words relegated to deeper layers (due to bit collisions) still have their bits set in layer 0's expansion (because that bit was occupied by another word). When looking up such a word, the layer-0 bit check passes (bit is set), the fingerprint comparison fails (different word is at that slot), and `cumulativeCt` accumulates before proceeding to layer 1, where the word is correctly found.

No remediation required.

---

### P1-A16-7 — checkParseMetaStructure: Validation Occurs After mload, Not Before (LOW)

**Classification:** LOW

**Location:** `src/lib/parse/LibParseMeta.sol`, lines 46-68

**Observation:**

`checkParseMetaStructure` reads the `depth` byte and then iterates over `depth` expansion layers via `mload`, accumulating `totalItems`, before comparing `meta.length` against the expected length at line 65. For sufficiently malformed input where `depth` is large and the `meta` bytes are short, the function issues `mload` calls that extend beyond the allocated content bytes.

Specifically, if an attacker passes a 1-byte meta (`[0xFF]`), `depth = 255`, and the loop issues 255 `mload` calls starting at `meta_ptr + 34`, reading up to `meta_ptr + 34 + 254*33 + 31 = meta_ptr + 8429`. The EVM zeroes memory on first access, so these reads return zero. `totalItems` accumulates `ctpop(0) = 0` for each iteration. Then `expected = 1 + 255*33 + 0 = 8416`. `meta.length = 1 ≠ 8416`, and the function correctly reverts.

The outcome is always correct: the revert fires with the right parameters. However, the excessive `mload` calls for maliciously crafted short meta consume unnecessary gas and touch a large memory region (forcing EVM memory expansion charges up to ~8kB). In a `pure` context the gas cost falls on the caller, but callers should be aware that `checkParseMetaStructure` with attacker-supplied `meta` can be gas-expensive.

**Impact:** A caller that validates untrusted bytes via `checkParseMetaStructure` without a prior length sanity-check can be tricked into spending additional gas expanding EVM memory. No state corruption, no incorrect result. Gas cost is bounded by the maximum depth (depth byte is 1 byte, max 255) times 33 bytes per expansion: at most ~8kB of memory expansion, which is a modest cost.

**Proposed Fix:**

Add a minimum-length guard before the loop:

```solidity
function checkParseMetaStructure(bytes memory meta) internal pure {
    unchecked {
        // Guard: meta must be at least META_PREFIX_SIZE bytes to contain a depth byte.
        if (meta.length < META_PREFIX_SIZE) {
            revert InvalidParseMeta(META_PREFIX_SIZE, meta.length);
        }
        uint256 depth;
        ...
    }
}
```

This allows the function to short-circuit before any looping when the meta is clearly too short to hold even the depth byte, avoiding unnecessary memory expansion. The existing length check at line 65 still runs for all other cases.

**Note:** This finding is informational in impact for most callers (build-time validation of generated meta). It becomes more relevant if the function is exposed to adversarial input in an on-chain path.

---

### P1-A16-8 — lookupWord: Undefined Behavior on Malformed Meta Is Not Callable On-Chain with Attacker-Controlled Input Without Explicit Exposure (INFO)

**Classification:** INFO

**Location:** `src/lib/parse/LibParseMeta.sol`, lines 123-186

**Observation:**

`lookupWord` explicitly documents (lines 117-118) that behavior is undefined for malformed `meta`. The function performs no bounds checking on the meta structure. If malformed meta is passed, the `mload` at line 169 could read from arbitrary memory locations:

```assembly
posData := mload(add(dataStart, mul(pos, metaItemSize)))
```

`pos` is computed from `ctpop` (max 256 per layer) plus `cumulativeCt` (accumulated across layers). For well-formed meta this is bounded by the total item count (max 256). For malformed meta, `cumulativeCt` could accumulate unboundedly across many phantom depth layers, yielding large `pos` values and thus reads far past the `meta` allocation.

In practice: `lookupWord` is a `pure` function. EVM reads past allocated memory return zeros. A large `mload` offset can expand EVM memory (gas cost), but cannot modify state. The function would return `(false, 0)` in most malformed cases (fingerprint of zeros never matches a non-zero stored fingerprint). A false positive match requires zeros in both the bit position check (non-zero required for the check to pass) and a stored fingerprint of zero (impossible by construction of non-zero fingerprints). Therefore, lookups on malformed meta cannot produce false positive matches, only false negatives.

The risk materialises if a contract passes attacker-controlled bytes directly to `lookupWord` without first calling `checkParseMetaStructure`. Reviewers of downstream contracts should verify that `checkParseMetaStructure` is called on any externally-sourced meta before it is stored and subsequently passed to `lookupWord`.

No remediation required in this library; the precondition is clearly documented.

---

## Summary

| ID | Title | Severity |
|----|-------|----------|
| P1-A16-1 | Protofire M01 fix verified: bit check present before fingerprint comparison | INFO |
| P1-A16-2 | Protofire L04 fix verified: structural validation exists and is called | INFO |
| P1-A16-3 | dataStart off-by-28 pointer arithmetic is intentional and correct | INFO |
| P1-A16-4 | wordBitmapped scratch-space usage is safe | INFO |
| P1-A16-5 | Fingerprint-zero remapping is correct with negligible bias | INFO |
| P1-A16-6 | Early return on bit miss is correct for multi-depth construction | INFO |
| P1-A16-7 | checkParseMetaStructure: validation loop runs before length guard | LOW |
| P1-A16-8 | lookupWord: undefined behavior on malformed meta cannot cause false positives | INFO |

**LOW or higher findings:** 1 (P1-A16-7)

A `.fixes/P1-A16-7.md` file has been written for the LOW finding.
