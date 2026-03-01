# Triage — Audit 2026-03-01-01

## Pass 0: Process Review

| ID | Severity | Title | Status |
|----|----------|-------|--------|
| A00-1 | LOW | CLAUDE.md says "Requires NixOS" but only Nix package manager is required | FIXED — Changed to "Requires the Nix package manager". |
| A00-2 | LOW | CLAUDE.md does not mention revert style conventions | FIXED — Added custom error convention note. |
| A00-3 | INFO | README.md says "Install `nix develop`" which is misleading | FIXED — Changed to "Install Nix". |
| A00-4 | INFO | CLAUDE.md doesn't state policy on modifying deprecated interfaces | FIXED — Added policy: deprecated interfaces should not be modified unless undeprecating. |
| A00-5 | INFO | No instruction on Solidity version policy for new vs. existing files | FIXED — Added pragma version policy for interfaces vs libraries. |

## Pass 1: Security Review

| ID | Severity | Title | Status |
|----|----------|-------|--------|
| P1-A01-2 | LOW | `bytecodeToSources` does not call `checkNoOOBPointers` internally | DOCUMENTED — Added natspec documenting that callers MUST checkNoOOBPointers before calling, plus @param/@return tags. |
| P1-A01-6 | LOW | `checkNoOOBPointers` does not enforce monotonically increasing offsets explicitly | DOCUMENTED — Added natspec noting contiguity implicitly enforces monotonicity. |
| P1-A02-4 | LOW | Reference implementation mismatch for zero signed contexts | FIXED — Fixed `buildStructureSlow` to conditionally omit signers column when zero signed contexts. Added zero-signed tests with empty and non-empty base. |
| P1-A03-1 | LOW | No input validation on `meta` bytes in `lookupWord` | DOCUMENTED — Added natspec documenting meta must be well-formed from buildParseMetaV2. Also fixes stale "io fn pointer" text (P3-A01-8). |
| P1-A03-2 | LOW | No bounds check on computed `pos` before data read in `lookupWord` | DISMISSED — Duplicate of P1-A03-1; same underlying issue, already covered by natspec documenting well-formedness precondition. |
| P1-A04-1 | LOW | Seed search loop skips seed value 255 | FIXED — Changed `<` to `<=` in loop condition. Added reference impl `LibGenParseMetaSlow.findBestExpanderSlow` and fuzz test verifying agreement across all 256 seeds. |
| P1-A04-2 | LOW | Opcode index silently truncated for word lists exceeding 255 entries | FIXED — Added `AuthoringMetaTooLarge` custom error and length check. Tests: boundary at 256 (succeeds), 257 (reverts), fuzz for 257-512 range. |
| P1-A06-1 | LOW | Stale documentation reference to `IInterpreterStoreV2` | FIXED — Changed `IInterpreterStoreV2` to `IInterpreterStoreV3` in natspec. |
| P1-A06-3 | LOW | `SourceIndexV2` uses `uint256` while V4 type system uses `bytes32` | DISMISSED — `SourceIndexV2` is defined in deprecated code; not actionable. |
| P1-A06-5 | MEDIUM | `EvalV4.namespace` is caller-controlled FullyQualifiedNamespace with no validation guidance | FIXED — Added natspec to `EvalV4` struct documenting that the interpreter MUST qualify the namespace itself via `LibNamespace.qualifyNamespace`. |
| P1-A06-8 | LOW | `PragmaV1.usingWordsFrom` has no length or duplication constraints | DOCUMENTED — Added natspec to PragmaV1 struct documenting field semantics and validation guidance. |
| P1-A06-9 | LOW | No interface guidance on `EvalV4.bytecode` validation or maximum size | DOCUMENTED — Added natspec recommending implementations validate bytecode via `LibBytecode.checkNoOOBPointers`. |

## Pass 2: Test Coverage Review

| ID | Severity | Title | Status |
|----|----------|-------|--------|
| P2-A01-1 | HIGH | `bytecodeToSources` has zero test coverage | FIXED — Added test file `test/src/lib/bytecode/LibBytecode.bytecodeToSources.t.sol` with 5 concrete tests + 1 fuzz test. All pass. |
| P2-A02-1 | LOW | No test triggers the `InvalidSignature` revert path in `build()` | FIXED — Added 4 tests: zero signature, second-index revert, wrong context data, empty signature bytes. All use external wrapper for vm.expectRevert. |
| P2-A02-2 | LOW | No test for `build()` with non-empty base context and zero signed contexts | FIXED — Addressed by P1-A02-4 fix. Added `testBuildStructureZeroSignedNonEmptyBase` fuzz test. |
| P2-A02-3 | LOW | Reference implementation `buildStructureSlow` disagrees with `build()` for zero signed contexts | FIXED — Addressed by P1-A02-4 fix. |
| P2-A03-1 | MEDIUM | `DuplicateFingerprint` revert path in `buildParseMetaV2` is never tested | FIXED — Added `testBuildMetaDuplicateFingerprint` test with external wrapper to trigger and verify the revert. |
| P2-A03-2 | MEDIUM | `parseMetaConstantString` function has no test coverage | FIXED — Added `testParseMetaConstantString` test exercising the abi.decode path and LibCodeGen integration. |
| P2-A03-3 | LOW | `lookupWord` has no dedicated test file and lacks edge-case coverage | FIXED — Created `LibParseMeta.lookupWord.t.sol` with 6 tests: known words, not-found, single-depth, fuzz not-found, fuzz roundtrip, and large (50-word) multi-depth set. |
| P2-A03-4 | LOW | `findBestExpander` is not tested with empty input or large collision-heavy input | FIXED — Added tests for empty, single word, large (64 elements), invariant fuzz, and reference comparison fuzz. |

## Pass 3: Documentation Review

| ID | Severity | Title | Status |
|----|----------|-------|--------|
| P3-A01-2 | LOW | `bytecodeToSources` missing `@param` and `@return` documentation | FIXED — Addressed by P1-A01-2 fix. Added @param and @return tags. |
| P3-A01-4 | LOW | `build` missing `@return` documentation | FIXED — Added @return tag describing the context matrix structure. |
| P3-A01-8 | LOW | `lookupWord` natspec mentions stale "io fn pointer" | FIXED — Addressed by P1-A03-1 fix. Replaced stale text with accurate description. |
| P3-A02-1 | LOW | `OperandV2` type has no natspec documentation | FIXED — Added @dev natspec. |
| P3-A02-2 | LOW | `StackItem` type has no natspec documentation | FIXED — Added @dev natspec. |
| P3-A02-3 | LOW | `EvalV4` struct has no natspec documentation | FIXED — Addressed by P1-A06-5 fix. Added full natspec with `@dev` and `@param` tags for all 7 fields. |
| P3-A02-4 | LOW | `eval4` function lacks `@param` and `@return` natspec tags | FIXED — Added @param eval, @return stack, @return writes tags. |
| P3-A02-5 | LOW | `IParserV2` interface and `parse2` function have no natspec | FIXED — Added @title, @notice, @param, @return natspec. |
| P3-A02-6 | LOW | `IParserPragmaV1` interface and `parsePragma1` have no natspec | FIXED — Added @title, @notice, @param, @return natspec. |
| P3-A02-7 | LOW | `PragmaV1` struct has no natspec documentation | FIXED — Addressed by P1-A06-8 fix. |

## Pass 4: Code Quality Review

| ID | Severity | Title | Status |
|----|----------|-------|--------|
| P4-A01 | ~~CRITICAL~~ | ~~Operator precedence bug in `lookupWord`~~ | DISMISSED — Verified incorrect: Solidity `&` (level 7) binds tighter than `==` (level 11). Expression is parsed as intended. |
| P4-A02 | LOW | Unused import and `using` for `LibUint256Array` in `LibContext.sol` | FIXED — Removed unused import and using directive. |
| P4-A03 | LOW | Stale `IInterpreterStoreV2` reference in `IInterpreterCallerV4` NatSpec | FIXED — Duplicate of P1-A06-1, addressed by same fix. |
| P4-A04 | LOW | Discarded return values via no-op `(hashed);` in `LibGenParseMeta.sol` | FIXED — Changed to idiomatic `(uint256 shifted,)` destructuring pattern. |
