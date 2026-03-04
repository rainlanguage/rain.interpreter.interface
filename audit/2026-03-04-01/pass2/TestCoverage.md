<!-- SPDX-License-Identifier: LicenseRef-DCL-1.0 -->
<!-- SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd -->

# Pass 2: Test Coverage Review

**Agents:** A01 (LibBytecode), A02 (LibContext + LibEvaluable), A03 (LibGenParseMeta), A04 (LibParseMeta), A05 (LibEvaluable), A06 (LibNamespace)

---

## Source Function Index

**LibBytecode.sol:**
- `sourceCount` (line 44)
- `checkNoOOBPointers` (line 72)
- `sourceRelativeOffset` (line 190)
- `sourcePointer` (line 211)
- `sourceOpsCount` (line 229)
- `sourceStackAllocation` (line 248)
- `sourceInputsOutputsLength` (line 274)
- `bytecodeToSources` (line 297)

**LibContext.sol:**
- `base` (line 60)
- `hash(SignedContextV1)` (line 76)
- `hash(SignedContextV1[])` (line 105)
- `build` (line 168) — error: `InvalidSignature(i)` at line 212

**LibGenParseMeta.sol:**
- `findBestExpander` (line 56)
- `buildParseMetaV2` (line 138) — errors: `AuthoringMetaTooLarge` (147), `MaxDepthExceeded` (161), `DuplicateFingerprint` (228)
- `parseMetaConstantString` (line 263)

**LibParseMeta.sol:**
- `checkParseMetaStructure` (line 45) — error: `InvalidParseMeta` (65)
- `wordBitmapped` (line 86)
- `lookupWord` (line 123)

**LibEvaluable.sol:**
- `hash(EvaluableV4)` (line 23)

**LibNamespace.sol:**
- `qualifyNamespace` (line 24)

---

## Findings

### P2-A01-1 — `sourceStackAllocation` lacks a concrete value-pinning test (LOW)

**File:** `test/src/lib/bytecode/LibBytecode.sourceStackAllocation.t.sol`

`testSourceStackAllocationAgainstSlow` only does differential fuzzing. `testSourceOpsCount` (line 16) has a concrete hand-crafted bytecode asserting the exact ops count; no equivalent exists for `sourceStackAllocation`. If both the optimised implementation and the reference share the same byte-extraction bug, no test catches it.

**Fix:** Add a unit test with a known bytecode (e.g. `hex"01000002010001ABCDEF12"` where byte 1 of the header = `0x02`) asserting `sourceStackAllocation(..., 0) == 2`.

---

### P2-A01-2 — `sourceInputsOutputsLength` lacks a concrete value-pinning test (LOW)

**File:** `test/src/lib/bytecode/LibBytecode.sourceInputsOutputs.t.sol`

Same gap: only differential fuzzing. No hand-crafted bytecode asserts specific `(inputs, outputs)` literal values.

**Fix:** Add a unit test with a known bytecode asserting `sourceInputsOutputsLength(..., 0) == (inputs, outputs)` for a concrete header.

---

### P2-A01-3 — `bytecodeToSources` byte-shuffle not verified for multiple opcodes (LOW)

**File:** `test/src/lib/bytecode/LibBytecode.bytecodeToSources.t.sol`

`testBytecodeToSourcesOneSourceOneOp` verifies the shuffle for exactly 1 opcode. The fuzz test `testBytecodeToSourcesFuzz` only checks source count and lengths. No test verifies the byte-shuffle content for 2+ opcodes, leaving the per-opcode assembly loop partially untested.

**Fix:** Add a test with a 2-opcode source that asserts the exact shuffled bytes of both opcodes.

---

### P2-A01-4 — `checkNoOOBPointers` max-boundary `inputs==outputs==allocation==0xFF` not pinned as passing (INFO)

The conforming fuzz test covers this statistically. No explicit concrete test exercises the case where all three header fields equal `0xFF` simultaneously (the passing boundary).

---

### P2-A02-1 — `hash(SignedContextV1)` not tested with empty `context` array or empty `signature` (LOW)

**File:** `test/src/lib/caller/LibContext.hash.t.sol`

The fuzz test covers arbitrary values. However, the assembly scratch-space logic in `hash(SignedContextV1)` at line 85 computes `keccak256(add(context_, 0x20), mul(mload(context_), 0x20))` — with a zero-length context this is `keccak256(ptr, 0)`, a meaningful edge case. No named test pinpoints this.

**Fix:** Add `testHashSingleSignedContextEmptyFields()` constructing `SignedContextV1(address(0), new bytes32[](0), "")` and asserting the exact hash against `keccak256(abi.encodePacked(...))`.

---

### P2-A02-2 — `build` column ordering not directly verified (LOW)

**File:** `test/src/lib/caller/LibContext.t.sol`

Tests compare structure length and delegate to reference. No test directly reads `context[0]`, `context[1]`, the signers column, or the signed-context data columns by index and checks their contents for a multi-signed, multi-base scenario.

**Fix:** Add a test with 1 base column + 2 signed contexts that asserts each column index holds the expected array by identity.

---

### P2-A02-3 — `hash(SignedContextV1[])` returning `HASH_NIL` for empty array not pinned (INFO)

The fuzz test may hit this but there is no named test asserting `hash(new SignedContextV1[](0)) == HASH_NIL`.

---

### P2-A03-1 — `buildParseMetaV2` with zero words not concretely tested (LOW)

**File:** `test/src/lib/codegen/LibGenParseMeta.buildMeta.t.sol`

There is no explicit `buildParseMetaV2(new AuthoringMetaV2[](0), maxDepth)` test. The fuzz test `testBuildMeta` can produce empty arrays but does not assert on the resulting meta structure independently.

**Fix:** Add `testBuildMetaZeroWords()` asserting the result is structurally valid and `lookupWord` returns `(false, 0)` for any word.

---

### P2-A03-2 — `DuplicateFingerprint` from hash-collision of distinct words not tested (INFO)

Only identical words trigger the tested path. The code comment documents the ~1/2^46 probability. Informational only.

---

### P2-A03-3 — `parseMetaConstantString` does not test `AuthoringMetaTooLarge` propagation (INFO)

`parseMetaConstantString` decodes and passes through to `buildParseMetaV2`; the error would propagate. Not separately tested.

---

### P2-A04-1 — `InvalidParseMeta` error parameters not checked (LOW)

**File:** `test/src/lib/parse/LibParseMeta.lookupWord.t.sol`

`testCheckParseMetaStructureTruncated` and `testCheckParseMetaStructureExtraBytes` use `vm.expectRevert()` without a selector or data match. A regression that emits `InvalidParseMeta(wrong_expected, wrong_actual)` would pass the test.

**Fix:** Replace bare `vm.expectRevert()` with `vm.expectRevert(abi.encodeWithSelector(InvalidParseMeta.selector, expected, actual))` for both tests.

---

### P2-A04-2 — `lookupWord` multi-depth fallthrough (cumulativeCt accumulation) not isolated (LOW)

**File:** `test/src/lib/parse/LibParseMeta.lookupWord.t.sol`

The codegen test `testRoundMetaExpanderDeeper` exercises this indirectly (requires `length > 50`). No test in `LibParseMeta.lookupWord.t.sol` constructs a minimal 2-layer meta by hand and directly verifies that a word in layer 2 is found with the correct index, isolating the `cumulativeCt` path.

**Fix:** Add a test that hand-constructs (or builds with `buildParseMetaV2`) a 2-layer meta with words in both layers and asserts correct lookup for a word known to reside in layer 2.

---

### P2-A04-3 — `wordBitmapped` single-bit bitmap invariant not asserted (INFO)

The bitmap is always `1 << byte(0, hash)`, so it always has exactly one bit. This is not asserted as a fuzz-test property.

---

### P2-A05-1 — `hash(EvaluableV4)` with empty bytecode not pinned as a concrete value (INFO)

`testEvaluableV4KnownHash` pins a non-empty-bytecode hash. The empty-bytecode case is covered by the fuzz test. Adding a known-answer test for the empty case would provide a symmetric anchor.

---

### P2-A06-1 — `qualifyNamespace` no concrete pinned-value test (LOW)

**File:** `test/src/lib/ns/LibNamespace.t.sol`

Only differential comparison against the reference slow implementation and gas tests. No test asserts a specific known hash for a concrete `(stateNamespace, sender)` pair.

**Fix:** Add `testQualifyNamespaceKnownValue()` with a fixed namespace and sender and assert the exact resulting `FullyQualifiedNamespace`.

---

### P2-A06-2 — `qualifyNamespace` collision-safety (isolation guarantee) not fuzz-tested (LOW)

**File:** `test/src/lib/ns/LibNamespace.t.sol`

The security property that different senders cannot share a namespace is the entire purpose of this library, but no fuzz test asserts `qualifyNamespace(ns, a) != qualifyNamespace(ns, b)` when `a != b`, nor `qualifyNamespace(nsA, s) != qualifyNamespace(nsB, s)` when `nsA != nsB`.

**Fix:** Add fuzz tests asserting both sender-isolation and namespace-isolation properties.

---

## Summary Table

| ID | File | Severity | Title |
|----|------|----------|-------|
| P2-A01-1 | LibBytecode | LOW | `sourceStackAllocation` lacks concrete value-pinning test |
| P2-A01-2 | LibBytecode | LOW | `sourceInputsOutputsLength` lacks concrete value-pinning test |
| P2-A01-3 | LibBytecode | LOW | `bytecodeToSources` byte-shuffle not verified for multiple opcodes |
| P2-A01-4 | LibBytecode | INFO | `checkNoOOBPointers` max-boundary not pinned |
| P2-A02-1 | LibContext | LOW | `hash(SignedContextV1)` not tested with empty fields |
| P2-A02-2 | LibContext | LOW | `build` column ordering not directly verified |
| P2-A02-3 | LibContext | INFO | `hash(SignedContextV1[])` empty array not pinned |
| P2-A03-1 | LibGenParseMeta | LOW | `buildParseMetaV2` with zero words not tested |
| P2-A03-2 | LibGenParseMeta | INFO | `DuplicateFingerprint` collision path not tested |
| P2-A03-3 | LibGenParseMeta | INFO | `parseMetaConstantString` error propagation not tested |
| P2-A04-1 | LibParseMeta | LOW | `InvalidParseMeta` error parameters not checked |
| P2-A04-2 | LibParseMeta | LOW | `lookupWord` multi-depth not isolated |
| P2-A04-3 | LibParseMeta | INFO | `wordBitmapped` single-bit invariant not asserted |
| P2-A05-1 | LibEvaluable | INFO | `hash(EvaluableV4)` empty bytecode not pinned |
| P2-A06-1 | LibNamespace | LOW | `qualifyNamespace` no concrete pinned-value test |
| P2-A06-2 | LibNamespace | LOW | `qualifyNamespace` collision-safety not fuzz-tested |
