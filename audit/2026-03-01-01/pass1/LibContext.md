# Audit: LibContext.sol

**Agent:** A02
**Pass:** 1 (Security)
**File:** `src/lib/caller/LibContext.sol`
**Date:** 2026-03-01

## Evidence of Thorough Reading

**Library:** `LibContext` (line 45)

**Functions:**
| Function | Line | Visibility |
|----------|------|------------|
| `base()` | 63 | internal view |
| `hash(SignedContextV1 memory)` | 79 | internal pure |
| `hash(SignedContextV1[] memory)` | 108 | internal pure |
| `build(bytes32[][] memory, SignedContextV1[] memory)` | 166 | internal view |

**Error:**
- `InvalidSignature(uint256 i)` -- line 20

**Constants:**
- `CONTEXT_BASE_COLUMN = 0` -- line 25
- `CONTEXT_BASE_ROWS = 2` -- line 28
- `CONTEXT_BASE_ROW_SENDER = 0` -- line 31
- `CONTEXT_BASE_ROW_CALLING_CONTRACT = 1` -- line 34

**Imports:**
- `LibUint256Array` from rain.solmem (line 5)
- `LibHashNoAlloc`, `HASH_NIL` from rain.lib.hash (line 6)
- `SignatureChecker` from OpenZeppelin (line 8)
- `MessageHashUtils` from OpenZeppelin (line 9)
- `SignedContextV1`, offset constants from IInterpreterCallerV4 (lines 11-16)

**Struct `SignedContextV1` (defined in IInterpreterCallerV2.sol line 62):**
- `address signer` (offset 0x00)
- `bytes32[] context` (offset 0x20)
- `bytes signature` (offset 0x40)

---

## Findings

### A02-1 | INFO | No Replay Protection for Signed Contexts

**Lines:** 191-216

**Description:**
The `build` function verifies that each `SignedContextV1` has a valid signature from the claimed signer over the context data, but provides no mechanism to prevent replay of the same signed context across multiple calls or across different contracts. The same signed context can be resubmitted to `build` an unlimited number of times.

The NatDoc on `SignedContextV1` (IInterpreterCallerV2.sol lines 41-47) explicitly documents that replay protection (nonce tracking), expiry enforcement, and uniqueness enforcement are the **expression's responsibility**, not this library's. The library comment at lines 159-165 of `build` also acknowledges this, noting the expression is responsible for domain separators and ordering.

This is documented as INFO because the design intent is clear and correct -- the library is intentionally a low-level building block that delegates policy decisions to the expression layer. However, any calling contract that uses `LibContext.build` without ensuring the expression enforces nonces/uniqueness is vulnerable to signature replay. This is a critical integration consideration rather than a bug in LibContext itself.

---

### A02-2 | INFO | Scratch Space Usage in `hash(SignedContextV1)` Overwrites Solidity Zero Slot

**Lines:** 84-96

**Description:**
The `hash(SignedContextV1 memory)` function uses the Solidity scratch space (memory locations 0x00 and 0x20) for intermediate hash computations. This is explicitly permitted by the Solidity memory model for functions marked `"memory-safe"` -- the scratch space at 0x00-0x3f is designated for short-term use.

The calling `hash(SignedContextV1[] memory)` function (line 108) correctly accounts for this by saving and restoring `mload(0)` (the `mem0` variable at lines 119, 125, 129) around the sub-call to `hash(SignedContextV1 memory)`.

This is correct behavior. The scratch space usage is safe within the Solidity memory model. No finding.

---

### A02-3 | INFO | ERC-1271 Signer Can Return Time-Varying Results

**Lines:** 202-208

**Description:**
The `build` function uses OpenZeppelin's `SignatureChecker.isValidSignatureNow`, which supports ERC-1271 smart contract signers. For smart contract signers, verification is done via `staticcall` to the signer contract's `isValidSignature` method. This means:

1. A smart contract signer can return `true` during `build` but `false` later (or vice versa), making verification non-deterministic across time.
2. The `staticcall` to the signer contract gives it the ability to observe the current block state, which could be used for conditional signature validity.

This is explicitly documented in the NatDoc for `SignedContextV1` (IInterpreterCallerV2.sol lines 49-53) and is an inherent property of ERC-1271. It is not a bug, but callers should be aware that signed context validity is only guaranteed at the moment `build` is called.

---

### A02-4 | LOW | Reference Implementation Mismatch for Zero Signed Contexts

**Lines:** 166-221 (LibContext.sol) vs lines 34-64 (test LibContextSlow.sol)

**Description:**
The `build` function (line 176) conditionally adds the signers column and signed context columns only when `signedContexts.length > 0`:

```solidity
uint256 contextLength = 1 + baseContext.length
    + (signedContexts.length > 0 ? signedContexts.length + 1 : 0);
```

The reference implementation in `LibContextSlow.buildStructureSlow` (test file, line 39) always adds `1 + signedContexts.length` columns:

```solidity
bytes32[][] memory context = new bytes32[][](1 + baseContext.length + 1 + signedContexts.length);
```

When `signedContexts.length == 0`, the optimized version produces a context of length `1 + baseContext.length`, while the reference produces `1 + baseContext.length + 1` (with an extra empty signers column at the end).

The test `testBuildStructureReferenceImplementation` (LibContext.t.sol line 20) only fuzzes the `base` parameter while hardcoding `signedContexts` to exactly 1 entry, so it never tests the `signedContexts.length == 0` case against the reference implementation. A separate test `testBuild0` (line 51) tests the zero case against a manually constructed expectation but does not compare against the slow reference.

The optimized version is arguably more correct (no point including an empty signers column), but the divergence between the implementation and its reference could mask bugs. The reference implementation should match the optimized version's behavior, or the test should explicitly acknowledge the divergence.

---

### A02-5 | INFO | `unchecked` Block in `build` Is Safe

**Lines:** 171-221

**Description:**
The entire body of `build` is wrapped in `unchecked`. The arithmetic operations within are:

- `1 + baseContext.length + ...` (line 176): These are lengths of memory arrays which are bounded by available memory. Overflow is not practically possible.
- `offset++` (lines 183, 188, 214): `offset` is bounded by `contextLength` which is bounded by array lengths.
- `i++` in loops (lines 182, 191): Similarly bounded by array lengths.

All index accesses into `context[]`, `signers[]`, `signedContexts[]`, and `baseContext[]` are done through Solidity's normal array access which includes bounds checking even inside `unchecked` (bounds checks are NOT arithmetic overflow checks). The `unchecked` block only disables overflow/underflow checks on arithmetic, not array bounds checks.

This is correct and safe.

---

### A02-6 | INFO | `base()` Assembly Is Memory-Safe

**Lines:** 63-71

**Description:**
The `base()` function manually allocates a `bytes32[]` array in assembly:

1. Reads the free memory pointer (line 65)
2. Stores the array length (2) at the base pointer (line 66)
3. Stores `caller()` and `address()` at the next two slots (lines 67-68)
4. Updates the free memory pointer to `baseArray + 0x60` (line 69)

This is correct. The total memory used is 0x60 bytes: 0x20 for length + 0x20 for `caller()` + 0x20 for `address()`. The free memory pointer is properly advanced. The `caller()` value is left-padded to 32 bytes by the EVM (address is 20 bytes, upper 12 bytes are zero), which matches the `bytes32` type of the array elements.

No issue found.

---

### A02-7 | INFO | Signature Hashing Uses `encodePacked`-Equivalent Over Single Array

**Lines:** 193-206

**Description:**
The comment at lines 196-200 acknowledges that the hashing approach is equivalent to `encodePacked` over a single array (without the length prefix). The code hashes the raw bytes of the `context` array:

```solidity
LibHashNoAlloc.hashWords(signedContexts[i].context)
```

Which internally does `keccak256(add(words, 0x20), mul(mload(words), 0x20))` -- hashing the packed words without the length prefix.

The comment correctly notes this would be a collision risk if multiple dynamic-length values were concatenated before hashing. Since only a single array is hashed (just its elements, contiguously), there is no ambiguity -- different arrays of different lengths produce different byte sequences for hashing (a 2-element array hashes 64 bytes; a 3-element array hashes 96 bytes). The length is implicitly encoded by the total byte count passed to keccak256.

The hash is then wrapped with `toEthSignedMessageHash` (EIP-191 prefix), which provides domain separation from raw transaction hashes. This is standard and correct.

No issue found.

---

### A02-8 | INFO | `hash(SignedContextV1)` Hashes Signer as Full 32-Byte Word

**Lines:** 84-85

**Description:**
The signer field (an `address`, 20 bytes) is hashed as a full 32-byte word:

```solidity
mstore(0, keccak256(add(signedContext, signerOffset), 0x20))
```

Because `signerOffset` is 0 (the first field of the struct), this reads the full 32-byte slot. In Solidity's memory layout, `address` values occupy the lower 20 bytes of a 32-byte slot, with the upper 12 bytes being zero. The reference implementation (`LibContextSlow.hashSlow`) creates a `uint256` from `uint160(signer)` and hashes that, which produces the same result (zero-extended in the upper bytes).

These approaches are consistent. No issue.

---

## Summary

No CRITICAL, HIGH, or MEDIUM severity findings were identified in `LibContext.sol`. The library correctly:

- Builds memory-safe assembly for the base context array
- Verifies signatures using OpenZeppelin's audited `SignatureChecker`
- Uses EIP-191 message hashing for signature verification
- Properly manages scratch space in hash functions
- Uses `unchecked` safely (only for arithmetic, array bounds checks remain active)

The one LOW finding (A02-4) notes a divergence between the optimized implementation and its test reference implementation when zero signed contexts are provided, which is a test coverage gap rather than a vulnerability.

The design explicitly and correctly delegates replay protection, nonce tracking, expiry enforcement, and signer authorization to the expression layer. This is well-documented but is a critical integration consideration for any contract using `LibContext.build`.
