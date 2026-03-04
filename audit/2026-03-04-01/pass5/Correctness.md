<!-- SPDX-License-Identifier: LicenseRef-DCL-1.0 -->
<!-- SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd -->

# Pass 5: Correctness / Intent Verification

**Agents:** A01-A16 (all source and test files)

---

## Findings

### P5-A12-1 — `@param hashed` on return value in `LibContext.hash` (LOW)

**File:** `src/lib/caller/LibContext.sol`, line 75

```solidity
/// @param signedContext The signed context to hash.
/// @param hashed The hashed signed context.          // WRONG: hashed is a named return, not a param
function hash(SignedContextV1 memory signedContext) internal pure returns (bytes32 hashed) {
```

The correct tag is `@return hashed The hashed signed context.`

---

### P5-A12-2 — `@param signedContexts` in `LibContext.build` mis-describes signers column position (LOW)

**File:** `src/lib/caller/LibContext.sol`, line 156

```
/// - The first column is a list of the signers in order of what they signed
```

"The first column" implies column 0, but signers are inserted AFTER the base and unsigned columns. The `@return` correctly describes the layout. This sub-bullet could mislead expression authors calculating column offsets.

---

### P5-A16-1 — Unexplained `+ META_ITEM_SIZE` in `buildParseMetaV2` `dataOffset` calculation (LOW)

**File:** `src/lib/codegen/LibGenParseMeta.sol`, line 188

```solidity
uint256 dataOffset = META_PREFIX_SIZE + META_ITEM_SIZE + depth * META_EXPANSION_SIZE;
```

The `+ META_ITEM_SIZE` (+ 4) is an undocumented pointer-alignment trick: `dataStart` is set `0x20 - META_ITEM_SIZE = 28` bytes before the actual first item, so that `mload(dataStart + pos*4)` loads a 32-byte word whose low 4 bytes contain the item. This is consistent with the matching formula in `lookupWord`, but has no comment explaining it.

---

### P5-A13-1 — `@return evaluableHash` mismatch (INFO)

**File:** `src/lib/caller/LibEvaluable.sol`, lines 22–23

`@return evaluableHash` is used but the function signature says `returns (bytes32)` (unnamed). The named variable `evaluableHash` exists internally only.

---

### P5-A16-2 — Test comments in `testLookupWordMissingBitCheck` describe a non-existent bug (INFO)

**File:** `test/src/lib/parse/LibParseMeta.lookupWord.t.sol`, lines 88–109

The comment states the bit-set check is missing, but `LibParseMeta.lookupWord` line 161 has the check. The test assertions are correct and pass, but the comment is false.

---

### P5-A11-1 — `bytecodeToSources` NatSpec does not document byte-1 (inputs) loss during shuffle (INFO)

**File:** `src/lib/bytecode/LibBytecode.sol`, lines 307–309

The shuffle overwrites byte 1 (the `inputs` field) with the opcode index, discarding the original value. Neither the NatSpec nor inline comments mention this.

---

### P5-A11-2 — `checkNoOOBPointers` else-branch comment implies pre-checked condition (INFO)

**File:** `src/lib/bytecode/LibBytecode.sol`, lines 169–175

The comment says "which we already implicitly checked by reaching this code path" but the `if (bytecode.length > 1)` that follows IS the check.

---

### P5-A11-3 — Typo "legacly" in inline comment (INFO)

**File:** `src/lib/bytecode/LibBytecode.sol`, line 308

---

### P5-A16-3 — `findBestExpander` NatSpec omits order-dependence of `remaining` (INFO)

**File:** `src/lib/codegen/LibGenParseMeta.sol`, lines 53–55

`remaining` is order-dependent: the first word to claim a bit position keeps it. Reordering `metas` produces a different `remaining`. Not documented.

---

## Algorithm Correctness Summary

All algorithms verified correct:
- **LibBytecode**: All functions match reference implementations
- **LibContext**: `base()`, both `hash()` overloads, and `build()` all match references
- **LibEvaluable**: `hash()` matches reference; `keccak256(evaluable, 0x40)` correctly covers two address fields
- **LibGenParseMeta**: `findBestExpander` and `buildParseMetaV2` are correct; `dataOffset` trick is internally consistent
- **LibNamespace**: `qualifyNamespace` matches `abi.encode`-based reference
- **LibParseMeta**: Bloom filter guard, fingerprint remapping, multi-layer fallback, and structure validation all correct

---

## Summary Table

| ID | File | Severity | Title |
|----|------|----------|-------|
| P5-A12-1 | LibContext.sol | LOW | `@param hashed` should be `@return hashed` |
| P5-A12-2 | LibContext.sol | LOW | Signers column position mis-described |
| P5-A16-1 | LibGenParseMeta.sol | LOW | Unexplained `+ META_ITEM_SIZE` alignment trick |
| P5-A13-1 | LibEvaluable.sol | INFO | `@return evaluableHash` name mismatch |
| P5-A16-2 | LibParseMeta test | INFO | Test comment describes non-existent bug |
| P5-A11-1 | LibBytecode.sol | INFO | Byte-1 loss undocumented in shuffle |
| P5-A11-2 | LibBytecode.sol | INFO | Comment implies pre-checked condition |
| P5-A11-3 | LibBytecode.sol | INFO | Typo "legacly" |
| P5-A16-3 | LibGenParseMeta.sol | INFO | Order-dependence undocumented |
