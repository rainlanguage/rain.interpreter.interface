# Pass 2 — Test Coverage Report: LibParseMeta, LibGenParseMeta, LibNamespace

Agent: A03
Date: 2026-03-01

## Source File Inventory

### `src/lib/parse/LibParseMeta.sol`

Library: `LibParseMeta`

| Function | Line | Visibility |
|---|---|---|
| `wordBitmapped(uint256 seed, bytes32 word)` | 45 | internal pure |
| `lookupWord(bytes memory meta, bytes32 word)` | 67 | internal pure |

### `src/lib/codegen/LibGenParseMeta.sol`

Library: `LibGenParseMeta`

| Function | Line | Visibility |
|---|---|---|
| `findBestExpander(AuthoringMetaV2[] memory metas)` | 49 | internal pure |
| `buildParseMetaV2(AuthoringMetaV2[] memory authoringMeta, uint8 maxDepth)` | 126 | internal pure |
| `parseMetaConstantString(Vm vm, bytes memory authoringMetaBytes, uint8 buildDepth)` | 241 | internal pure |

Error: `DuplicateFingerprint()` (line 21, reverted at line 208)

### `src/lib/ns/LibNamespace.sol`

Library: `LibNamespace`

| Function | Line | Visibility |
|---|---|---|
| `qualifyNamespace(StateNamespace stateNamespace, address sender)` | 24 | internal pure |

## Test File Inventory

### `test/src/lib/parse/LibParseMeta.wordBitmapped.t.sol`

Contract: `LitParseMetaTest`

| Test Function | Line |
|---|---|
| `referenceWordBitmapped(uint256 seed, bytes32 word)` (helper) | 10 |
| `testWordBitmapped(uint256 seed, bytes32 word)` | 19 |

### `test/src/lib/codegen/LibGenParseMeta.findExpander.t.sol`

Contract: `LibGenParseMetaFindExpanderTest`

| Test Function | Line |
|---|---|
| `testFindExpanderSmall(AuthoringMetaV2[] memory authoringMeta)` | 24 |

### `test/src/lib/codegen/LibGenParseMeta.buildMeta.t.sol`

Contract: `LibGenParseMetaBuildMetaTest`

| Test Function | Line |
|---|---|
| `expanderDepth(uint256 n)` (helper) | 14 |
| `testBuildMeta(AuthoringMetaV2[] memory authoringMeta)` | 25 |
| `testRoundMetaExpanderShallow(AuthoringMetaV2[] memory authoringMeta, uint8 j, bytes32 notFound)` | 31 |
| `testRoundMetaExpanderDeeper(AuthoringMetaV2[] memory authoringMeta, uint8 j, bytes32 notFound)` | 52 |

### `test/src/lib/ns/LibNamespace.t.sol`

Contract: `LibNamespaceTest`

| Test Function | Line |
|---|---|
| `testQualifyNamespaceReferenceImplementation(StateNamespace stateNamespace, address sender)` | 11 |
| `testQualifyNamespaceGas0(StateNamespace stateNamespace, address sender)` | 18 |
| `testQualifyNamespaceGasSlow0(StateNamespace stateNamespace, address sender)` | 22 |

### Test Helpers

- `test/src/lib/ns/LibNamespaceSlow.sol` — Slow reference implementation of `qualifyNamespace` using `abi.encode`.
- `test/lib/meta/LibAuthoringMeta.sol` — Helper to extract word arrays from `AuthoringMetaV2[]`.
- `test/lib/bloom/LibBloom.sol` — Bloom filter duplicate detection used by test preconditions.

## Coverage Gap Findings

### A03-1

**Severity:** MEDIUM

**Title:** `DuplicateFingerprint` revert path in `buildParseMetaV2` is never tested

**Description:** The `DuplicateFingerprint` error (defined at `src/lib/codegen/LibGenParseMeta.sol:21`, reverted at line 208) is never triggered by any test. A grep across the entire `test/` directory for `DuplicateFingerprint` returns zero results. This revert occurs when two different words produce the same 3-byte fingerprint at the same bloom filter slot across all expansion depths. Without a test exercising this path, there is no verification that (a) the error is correctly triggered when it should be, and (b) the detection logic around the fingerprint comparison at lines 206-208 is correct. Constructing a test that crafts two words with colliding fingerprints at a specific seed would verify this path.

---

### A03-2

**Severity:** MEDIUM

**Title:** `parseMetaConstantString` function has no test coverage

**Description:** The function `LibGenParseMeta.parseMetaConstantString` at `src/lib/codegen/LibGenParseMeta.sol:241` has zero test coverage. A grep for `parseMetaConstantString` across the test directory returns no results. This function performs `abi.decode` of arbitrary bytes into `AuthoringMetaV2[]`, then calls `buildParseMetaV2` and `LibCodeGen` functions to produce a formatted constant string. The `abi.decode` step in particular could fail on malformed input in ways that differ from passing a pre-decoded array. While this function is primarily used during code generation (not at runtime), verifying it produces correct output for at least one known input would confirm the integration between `buildParseMetaV2` and the code generation utilities works as intended.

---

### A03-3

**Severity:** LOW

**Title:** `lookupWord` has no dedicated test file and lacks direct edge-case coverage

**Description:** `LibParseMeta.lookupWord` at `src/lib/parse/LibParseMeta.sol:67` is only exercised indirectly through the round-trip tests in `LibGenParseMeta.buildMeta.t.sol` (lines 43, 47, 65, 69). There is no dedicated test file for `lookupWord` (such as `LibParseMeta.lookupWord.t.sol`). This means:

1. The function is never tested with hand-crafted meta bytes that would exercise specific assembly paths (e.g., multi-depth traversal with known collision patterns).
2. There is no test with an empty or minimal meta (e.g., a 1-byte meta representing depth=0), which would exercise the early-exit path at line 120 where `cursor >= end` immediately.
3. There is no test with meta containing exactly one depth level, verifying the single-pass lookup path in isolation.
4. The function is never tested with corrupted or malformed meta bytes, which could expose unsafe memory reads in the assembly at lines 75-82 and 93-106.

The existing fuzz tests provide good probabilistic coverage of the happy path, but deterministic edge-case tests would strengthen confidence in the assembly-heavy implementation.

---

### A03-4

**Severity:** LOW

**Title:** `findBestExpander` is not tested with empty input or large collision-heavy input

**Description:** `LibGenParseMeta.findBestExpander` at `src/lib/codegen/LibGenParseMeta.sol:49` is tested by `testFindExpanderSmall` (line 24 in `LibGenParseMeta.findExpander.t.sol`), but only for arrays with up to 32 elements and no bloom-detected duplicates. The following cases lack coverage:

1. **Empty input array:** Calling `findBestExpander` with a zero-length `AuthoringMetaV2[]` array. In this case, `bestCt` remains 0, and `remainingLength = 0 - 0 = 0`, which should work correctly, but this is never verified.
2. **Large input (>32 elements) where perfect expansion is impossible:** The test only covers inputs up to 32 words (where perfect expansion into 256 bloom slots is highly probable). There is no test for inputs between 33 and 255 elements, which would require the `remaining` array to be non-empty and would exercise the second loop (lines 87-96) more thoroughly, including the collision branch at line 92 where items are placed into `remaining`.

---

### A03-5

**Severity:** INFO

**Title:** `buildParseMetaV2` lacks a test for depth overflow beyond `maxDepth`

**Description:** In `buildParseMetaV2` at `src/lib/codegen/LibGenParseMeta.sol:126`, the `depth` variable (line 137) increments inside a while loop until all remaining authoring meta is expanded. If the number of required expansion depths exceeds `maxDepth`, the `seeds[depth]` assignment at line 146 would cause an out-of-bounds array access. The existing fuzz tests use the `expanderDepth` helper to compute a generous `maxDepth`, so this boundary is unlikely to be hit in practice. However, there is no explicit test confirming that an insufficiently small `maxDepth` causes a clean revert (from the array bounds check), rather than corrupting memory. This is informational since the Solidity runtime would revert on the array bounds check, but a test documenting this behavior would be useful.
