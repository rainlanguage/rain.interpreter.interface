# Triage — Audit 2026-03-04-01

## Pass 0: Process Review

| ID | Severity | Title | Status |
|----|----------|-------|--------|
| A00-1 | LOW | README.md still says "Uses nixos" instead of "Uses Nix" | FIXED |

## Pass 1: Security Review

| ID | Severity | Title | Status |
|----|----------|-------|--------|
| P1-A04-1 | LOW | `EvaluableV4` fields carry no natspec guidance on address validation | FIXED |
| P1-A04-2 | INFO | Interface comment still references `IInterpreterStoreV2` | DISMISSED — Already fixed in prior audit (P1-A06-1). Current code on line 38 reads `IInterpreterStoreV3`. |
| P1-A05-1 | MEDIUM | `extern` return type `StackItem[] calldata` underdocumented | DISMISSED — `calldata` return from external call is standard Solidity ABI; compiler handles decoding correctly. Proposed fix warns about memory aliasing that cannot occur. |
| P1-A05-2 | MEDIUM | No guidance on when `externIntegrity` must be called relative to `extern` | FIXED |
| P1-A06-1 | LOW | `get` with fully qualified namespace allows any caller to read any namespace | DISMISSED — All EVM storage is publicly readable. Existing natspec already acknowledges this. Not a finding. |
| P1-A07-1 | MEDIUM | `eval4` return type documentation gap re: writes validation | DISMISSED — The interpreter is `view` and never writes to the store. The caller forwards writes to `store.set()` — caller already trusts the interpreter by choice. |
| P1-A07-2 | LOW | `stateOverlay` format unconstrained with no simulation-only warning | FIXED |
| P1-A07-3 | LOW | No guidance on handling zero-address `store` in `EvalV4` | DISMISSED — `eval4` is `view`; interpreter never writes to the store. Caller decides whether to forward writes. Zero-address store is the caller's concern. |
| P1-A08-1 | LOW | `parsePragma1` return type `PragmaV1 calldata` may surprise implementors | DISMISSED — Implementations can return `memory` against a `calldata` interface; ABI encoding is identical. No compiler error. |
| P1-A09-1 | MEDIUM | `parse2` output bytecode unconstrained; no validation guidance | DISMISSED — Caller chose the parser; same trust model as interpreter. Interpreter security model already covers resilience to arbitrary bytecode. |
| P1-A10-1 | HIGH | Removal of `compatibility` parameter eliminates version gating | DISMISSED — Version gating is via function selectors (`subParseWord2`, `subParseLiteral2`). Layout changes produce new selectors. The `compatibility` parameter was redundant. |
| P1-A10-2 | MEDIUM | `subParseWord2` returns unconstrained bytecode; no validation guidance | DISMISSED — Caller chose the sub-parser; same trust model. |
| P1-A10-3 | MEDIUM | No guidance on sub-parser address trust in context of `PragmaV1` | DISMISSED — Sub-parser addresses are user-supplied at build time. User chose which sub-parsers to trust. Same trust model. |
| P1-A12-1 | HIGH | No Domain Separator or Chain ID in signed message hash | DISMISSED — Deliberate design. `SignedContextV1` natspec explicitly delegates domain separation to expression logic. |
| P1-A12-2 | MEDIUM | address(0) signer accepted without explicit guard | DISMISSED — `address(0)` behaves identically to any other codeless address: EOA path rejects it. Nothing special about zero address here. |
| P1-A12-3 | LOW | Scratch space clobbering in `hash(SignedContextV1)` missing NatSpec warning | DISMISSED — Standard scratch space usage. `memory-safe` annotation already communicates this. Not a finding. |
| P1-A13-2 | MEDIUM | `qualifyNamespace` `sender` parameter not enforced to be `msg.sender` | DISMISSED — Function is `internal`; `IInterpreterV4` natspec already mandates callers use `msg.sender`. Parameterizing allows testing and composition. |
| P1-A11-1 | LOW | Unenforced `checkNoOOBPointers` prerequisite across reading functions | DISMISSED — Duplicate of prior audit P1-A01-2 (DOCUMENTED). Natspec already documents the prerequisite. |
| P1-A15-1 | LOW | Assembly in `hash` reads struct fields by raw offset with no inline documentation | FIXED |
| P1-A16-7 | LOW | `checkParseMetaStructure` loops before length guard — unnecessary gas on adversarial input | DISMISSED — Caller can set a gas limit on the external call. Function is internal pure and build-time only; adversarial input wastes gas but cannot corrupt state. |

## Pass 2: Test Coverage Review

| ID | Severity | Title | Status |
|----|----------|-------|--------|
| P2-A01-1 | LOW | `sourceStackAllocation` lacks concrete value-pinning test | FIXED |
| P2-A01-2 | LOW | `sourceInputsOutputsLength` lacks concrete value-pinning test | FIXED |
| P2-A01-3 | LOW | `bytecodeToSources` byte-shuffle not verified for multiple opcodes | FIXED |
| P2-A02-1 | LOW | `hash(SignedContextV1)` not tested with empty fields | FIXED |
| P2-A02-2 | LOW | `build` column ordering not directly verified | DISMISSED — Differential testing against reference implementation already verifies column ordering element-by-element. |
| P2-A03-1 | LOW | `buildParseMetaV2` with zero words not concretely tested | FIXED |
| P2-A04-1 | LOW | `InvalidParseMeta` error parameters not checked in tests | FIXED |
| P2-A04-2 | LOW | `lookupWord` multi-depth fallthrough not isolated | DISMISSED — Round-trip fuzz tests and large-set tests already exercise multi-depth fallthrough. Isolating requires crafting raw meta bytes for marginal benefit. |
| P2-A06-1 | LOW | `qualifyNamespace` no concrete pinned-value test | FIXED |
| P2-A06-2 | LOW | `qualifyNamespace` collision-safety not fuzz-tested | DISMISSED — Collision resistance is a keccak256 property, not something the code can influence or a fuzz test can meaningfully verify. |

## Pass 3: Documentation Review

| ID | Severity | Title | Status |
|----|----------|-------|--------|
| P3-A02-1 | LOW | `NotAnExternContract` missing `@param` | FIXED |
| P3-A04-1 | LOW | `EvaluableV4` `@param expression` does not match field name `bytecode` | FIXED |
| P3-A07-1 | LOW | `IInterpreterV4.sol` uses `pragma solidity ^0.8.25` violating interface convention | DISMISSED — Convention updated in CLAUDE.md. Interfaces now use `^0.8.25`. |
| P3-A07-2 | LOW | `IInterpreterV4` interface missing `@notice` tag | FIXED |
| P3-A11-1 | LOW | `checkNoOOBPointers` missing `@param bytecode` tag | FIXED |
| P3-A12-1 | LOW | `hash(SignedContextV1)` uses `@param hashed` for return value | FIXED |

## Pass 4: Code Quality Review

| ID | Severity | Title | Status |
|----|----------|-------|--------|
| P4-A05-1 | LOW | Unused type `EncodedExternDispatchV2` | DISMISSED — Type exists for downstream consumers who encode extern dispatches. Removing would be a breaking change. |
| P4-A12-1 | LOW | Four unused `CONTEXT_BASE_*` constants | DISMISSED — Constants exist for downstream consumers (interpreter implementations). Removing would be a breaking change. |
| P4-A12-2 | LOW | `@param hashed` should be `@return hashed` | DISMISSED — Duplicate of P3-A12-1. |

## Pass 5: Correctness / Intent Verification

| ID | Severity | Title | Status |
|----|----------|-------|--------|
| P5-A12-1 | LOW | `@param hashed` should be `@return hashed` | DISMISSED — Duplicate of P3-A12-1. |
| P5-A12-2 | LOW | Signers column position mis-described in `build` natspec | FIXED |
| P5-A16-1 | LOW | Unexplained `+ META_ITEM_SIZE` alignment trick in `buildParseMetaV2` | DOCUMENTED |
