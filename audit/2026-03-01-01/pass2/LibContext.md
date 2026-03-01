# Pass 2 -- Test Coverage: LibContext.sol and LibEvaluable.sol

Agent: A02
Date: 2026-03-01

## Source Inventory

### LibContext (src/lib/caller/LibContext.sol)

| Line | Item |
|------|------|
| 20 | `error InvalidSignature(uint256 i)` |
| 25-34 | Constants: `CONTEXT_BASE_COLUMN`, `CONTEXT_BASE_ROWS`, `CONTEXT_BASE_ROW_SENDER`, `CONTEXT_BASE_ROW_CALLING_CONTRACT` |
| 45 | `library LibContext` |
| 63 | `function base() internal view returns (bytes32[] memory)` -- assembly: allocates array with `msg.sender` and `address(this)` |
| 79 | `function hash(SignedContextV1 memory) internal pure returns (bytes32)` -- assembly: hashes signer, context, signature fields |
| 108 | `function hash(SignedContextV1[] memory) internal pure returns (bytes32)` -- loops over array, chains subhashes starting from HASH_NIL |
| 166 | `function build(bytes32[][] memory, SignedContextV1[] memory) internal view returns (bytes32[][] memory)` -- merges base, caller context, signed contexts; verifies signatures; reverts `InvalidSignature(i)` on bad sig |

### LibEvaluable (src/lib/caller/LibEvaluable.sol)

| Line | Item |
|------|------|
| 16 | `library LibEvaluable` |
| 23 | `function hash(EvaluableV4 memory) internal pure returns (bytes32)` -- assembly: hashes interpreter+store together, then hashes with bytecode hash |

## Test Inventory

### LibContextTest (test/src/lib/caller/LibContext.t.sol)

| Line | Test | Exercises |
|------|------|-----------|
| 10 | `testBase()` | `base()` -- checks length=2, sender, address(this) |
| 20 | `testBuildStructureReferenceImplementation(bytes32[][])` | `build()` with 1 valid signed context vs slow reference; fuzz 100 runs |
| 51 | `testBuild0()` | `build()` with empty base and empty signed contexts |
| 63 | `testBuildGas0()` | `build()` gas benchmark, empty inputs |

### LibContextHashTest (test/src/lib/caller/LibContext.hash.t.sol)

| Line | Test | Exercises |
|------|------|-----------|
| 10 | `testFuzzHash0()` | `hash(SignedContextV1[])` with 3 zero-filled entries |
| 19 | `testHash(uint256)` | raw keccak256 (not LibContext) |
| 26 | `testHashGas0()` | raw keccak256 gas bench |
| 34 | `testSignedContextHashReferenceImplementation(SignedContextV1)` | `hash(SignedContextV1)` vs slow reference; fuzz 100 runs |
| 38 | `testSignedContextArrayHashReferenceImplementation0()` | `hash(SignedContextV1[])` with length-1 array of zero values |
| 44 | `testSignedContextHashGas0()` | `hash(SignedContextV1)` gas bench |
| 52 | `testSignedContextHashEncodeGas0()` | abi.encode+keccak comparison gas bench |
| 60 | `testSignedContextArrayHashReferenceImplementation(SignedContextV1[])` | `hash(SignedContextV1[])` vs slow reference; fuzz 100 runs |

### LibContextSlow (test/src/lib/caller/LibContextSlow.sol)

Reference implementation used by tests. Not a test contract itself.

- `hashSlow(SignedContextV1 memory)` -- line 15
- `hashSlow(SignedContextV1[] memory)` -- line 24
- `buildStructureSlow(bytes32[][], SignedContextV1[])` -- line 34

### LibEvaluableTest (test/src/lib/caller/LibEvaluable.t.sol)

| Line | Test | Exercises |
|------|------|-----------|
| 17 | `testEvaluableV4KnownHash()` | `hash()` with known inputs, asserts known output |
| 23 | `testEvaluableV4HashDifferent(EvaluableV4, EvaluableV4)` | different inputs produce different hashes; fuzz |
| 30 | `testEvaluableV4HashSame(EvaluableV4)` | identical inputs produce identical hashes; fuzz |
| 35 | `testEvaluableV4HashSensitivity(EvaluableV4, EvaluableV4)` | changing each field individually changes hash; fuzz |
| 75 | `testEvaluableV4HashGas0()` | gas bench |
| 79 | `testEvaluableV4BytecodeLengthSensitivity()` | hex"01" vs hex"0100" produce different hashes (padding safety) |
| 88 | `testEvaluableV4HashGasSlow0()` | slow reference gas bench |
| 92 | `testEvaluableV4ReferenceImplementation(EvaluableV4)` | `hash()` vs slow reference; fuzz |

### LibEvaluableSlow (test/src/lib/caller/LibEvaluableSlow.sol)

Reference implementation. Not a test contract itself.

- `hashSlow(EvaluableV2 memory)` -- line 9
- `hashSlow(EvaluableV4 memory)` -- line 19

---

## Findings

### A02-1 | LOW | No test triggers the `InvalidSignature` revert path in `build()`

**Description:** `LibContext.build()` (line 202-210) reverts with `InvalidSignature(i)` when a signed context has an invalid signature. No test in the test suite ever calls `build()` with an invalid signature to verify this revert path is reached. `testBuildStructureReferenceImplementation` uses a hardcoded valid signature, `testBuild0` uses empty signed contexts, and `testBuildGas0` also uses empty signed contexts. The `InvalidSignature` error is not imported or referenced in any test file.

This means:
- There is no confirmation that the revert triggers with the correct index `i`.
- There is no test for a partially-valid list (e.g., first signature valid, second invalid) to confirm the correct index is reported.
- There is no test that verifies the error selector or ABI encoding.

### A02-2 | LOW | No test for `build()` with non-empty base context and zero signed contexts

**Description:** `build()` (line 176) has a conditional branch: `signedContexts.length > 0 ? signedContexts.length + 1 : 0`. The zero-signed-contexts path is tested only with an empty base context (`testBuild0` at line 51). There is no test that calls `build()` with a non-empty `baseContext` and an empty `signedContexts` array. This means the context length calculation `1 + baseContext.length + 0` and the base-context-merging loop operating without any signed context appended are not tested together. Note that the reference `buildStructureSlow` always adds `+1` for the signers column regardless of whether `signedContexts` is empty, so it structurally disagrees with `build()` on empty signed contexts, which means `testBuildStructureReferenceImplementation` cannot actually be used to validate this case (the fuzz test always supplies exactly 1 signed context).

### A02-3 | LOW | Reference implementation `buildStructureSlow` structurally disagrees with `build()` for zero signed contexts

**Description:** `buildStructureSlow` (LibContextSlow.sol line 39) always allocates `1 + baseContext.length + 1 + signedContexts.length` columns, unconditionally adding a signers column even when `signedContexts.length == 0`. The production `build()` function (LibContext.sol line 176) conditionally omits the signers column when there are no signed contexts: `1 + baseContext.length + (signedContexts.length > 0 ? signedContexts.length + 1 : 0)`. This means the reference implementation cannot serve as a valid oracle for the zero-signed-contexts case. The fuzz test `testBuildStructureReferenceImplementation` works around this by always providing exactly 1 signed context, but this leaves the structural difference unvalidated and means the reference implementation does not actually cover the full behavior space of `build()`.

### A02-4 | INFO | No test for `build()` with multiple signed contexts

**Description:** `testBuildStructureReferenceImplementation` always provides exactly 1 signed context (line 34: `new SignedContextV1[](1)`). While the single-element case exercises the loop body, there is no explicit test for multiple signed contexts to verify that the signers array is populated correctly for all entries and that the context columns are appended in the right order. The fuzz varies the `base` array but not the number of signed contexts.

### A02-5 | INFO | `hash(SignedContextV1[])` not tested with an empty array

**Description:** `hash(SignedContextV1[] memory)` (line 108) starts with `HASH_NIL` and returns it immediately if the array is empty (since the while-loop body never executes). No test calls this function with an empty array to confirm that `HASH_NIL` is returned. The existing tests use arrays of length 1 (`testSignedContextArrayHashReferenceImplementation0`) and length 3 (`testFuzzHash0`), plus a fuzz that could randomly produce length 0 but does not assert the specific `HASH_NIL` return value. A dedicated test for the empty case would strengthen coverage of this boundary.
