# Audit Report: Interface Security Review (Agent A06)

**Date:** 2026-03-01
**Scope:** Non-deprecated interface files in `src/interface/`
**Pass:** 1 (Security)

---

## Evidence of Thorough Reading

### 1. `src/interface/IInterpreterV4.sol` (102 lines)

- **Imports:** `FullyQualifiedNamespace`, `StateNamespace`, `SourceIndexV2`, `DEFAULT_STATE_NAMESPACE`, `OPCODE_CONSTANT`, `OPCODE_CONTEXT`, `OPCODE_EXTERN`, `OPCODE_UNKNOWN`, `OPCODE_STACK` from deprecated v2/IInterpreterV3.sol; `IInterpreterStoreV3` (lines 5-37)
- **Type `OperandV2`:** `bytes32` user-defined value type (line 39)
- **Type `StackItem`:** `bytes32` user-defined value type (line 41)
- **Struct `EvalV4`:** fields `store` (IInterpreterStoreV3), `namespace` (FullyQualifiedNamespace), `bytecode` (bytes), `sourceIndex` (SourceIndexV2), `context` (bytes32[][]), `inputs` (StackItem[]), `stateOverlay` (bytes32[]) (lines 43-51)
- **Interface `IInterpreterV4`:** single function `eval4(EvalV4 calldata) external view returns (StackItem[] calldata, bytes32[] calldata)` (lines 89-102)

### 2. `src/interface/IInterpreterStoreV3.sol` (66 lines)

- **Imports:** `StateNamespace`, `FullyQualifiedNamespace`, `NO_STORE` from deprecated v2/IInterpreterStoreV2.sol (line 7)
- **Interface `IInterpreterStoreV3`:** (lines 31-66)
  - **Event `Set`:** `(FullyQualifiedNamespace namespace, bytes32 key, bytes32 value)` (line 36)
  - **Function `set`:** `(StateNamespace namespace, bytes32[] calldata kvs) external` (line 48)
  - **Function `get`:** `(FullyQualifiedNamespace namespace, bytes32 key) external view returns (bytes32)` (line 65)

### 3. `src/interface/IInterpreterCallerV4.sol` (48 lines)

- **Imports:** `IParserV2`, `IInterpreterStoreV3`, `IInterpreterV4`, `SignedContextV1`, `SIGNED_CONTEXT_SIGNER_OFFSET`, `SIGNED_CONTEXT_CONTEXT_OFFSET`, `SIGNED_CONTEXT_SIGNATURE_OFFSET` (lines 7-18)
- **Struct `EvaluableV4`:** fields `interpreter` (IInterpreterV4), `store` (IInterpreterStoreV3), `bytecode` (bytes) (lines 25-29)
- **Interface `IInterpreterCallerV4`:** (lines 39-48)
  - **Event `ContextV2`:** `(address sender, bytes32[][] context)` (line 47)

### 4. `src/interface/IInterpreterExternV4.sol` (47 lines)

- **Imports:** `StackItem` from IInterpreterV4.sol (line 5)
- **Type `EncodedExternDispatchV2`:** `bytes32` user-defined value type (line 7)
- **Type `ExternDispatchV2`:** `bytes32` user-defined value type (line 9)
- **Interface `IInterpreterExternV4`:** (lines 21-47)
  - **Function `externIntegrity`:** `(ExternDispatchV2 dispatch, uint256 expectedInputs, uint256 expectedOutputs) external view returns (uint256 actualInputs, uint256 actualOutputs)` (lines 33-36)
  - **Function `extern`:** `(ExternDispatchV2 dispatch, StackItem[] calldata inputs) external view returns (StackItem[] calldata outputs)` (lines 43-46)

### 5. `src/interface/IParserV2.sol` (11 lines)

- **Imports:** `AuthoringMetaV2` from deprecated v1/IParserV1.sol (line 7)
- **Interface `IParserV2`:** (lines 9-11)
  - **Function `parse2`:** `(bytes calldata data) external view returns (bytes calldata bytecode)` (line 10)

### 6. `src/interface/ISubParserV4.sol` (72 lines)

- **Imports:** `AuthoringMetaV2` from deprecated v2/ISubParserV3.sol, `OperandV2` from IInterpreterV4.sol (lines 7-9)
- **Interface `ISubParserV4`:** (lines 18-72)
  - **Function `subParseLiteral2`:** `(bytes calldata data) external view returns (bool success, bytes32 value)` (line 40)
  - **Function `subParseWord2`:** `(bytes calldata data) external view returns (bool success, bytes memory bytecode, bytes32[] memory constants)` (line 68-71)

### 7. `src/interface/IParserPragmaV1.sol` (11 lines)

- **Struct `PragmaV1`:** field `usingWordsFrom` (address[]) (lines 5-7)
- **Interface `IParserPragmaV1`:** (lines 9-11)
  - **Function `parsePragma1`:** `(bytes calldata data) external view returns (PragmaV1 calldata)` (line 10)

---

## Findings

### A06-1 | LOW | Stale documentation reference to `IInterpreterStoreV2` in `IInterpreterCallerV4`

**File:** `src/interface/IInterpreterCallerV4.sol`, line 38

**Description:** The NatSpec comment for `IInterpreterCallerV4` states:

```
/// - OPTIONALLY set state on the associated `IInterpreterStoreV2`.
```

The current store interface is `IInterpreterStoreV3`, which the file itself imports at line 8. This stale reference to V2 could mislead implementors into integrating with the wrong store version, potentially causing silent compatibility issues or namespace qualification mismatches between the interpreter and store. While this is a documentation issue, in the context of a security-critical interface where correct version pairing between interpreter, store, and caller is essential for namespace isolation guarantees, an incorrect version reference carries risk.

---

### A06-2 | INFO | `EncodedExternDispatchV2` type is defined but unused in any interface function

**File:** `src/interface/IInterpreterExternV4.sol`, line 7

**Description:** The type `EncodedExternDispatchV2` is defined as `bytes32` but is never used in any function signature within the current interfaces. There is no library in this repository that provides encode/decode functionality between `EncodedExternDispatchV2` and `ExternDispatchV2` (unlike the deprecated versions where `EncodedExternDispatch` and `ExternDispatch` had a similar relationship with an associated library). The type is exported from the file but has zero references anywhere in the codebase.

This is an informational finding: unused types add cognitive overhead and could lead implementors to believe they need to handle encoding/decoding between the two dispatch types without any provided specification for how to do so. If the type is intentionally left for future use, consider documenting its purpose. If it is vestigial from the V1/V2 pattern, it could be removed to reduce interface surface area.

---

### A06-3 | LOW | `SourceIndexV2` uses `uint256` while V4 type system uses `bytes32` for similar-purpose types

**File:** `src/interface/IInterpreterV4.sol`, line 47 (usage); defined in `src/interface/deprecated/v1/IInterpreterV2.sol`, line 35

**Description:** The `EvalV4` struct uses `SourceIndexV2` (defined as `type SourceIndexV2 is uint256`) for the `sourceIndex` field. However, the V4 type system has migrated similar types to `bytes32` (e.g., `StackItem is bytes32`, `OperandV2 is bytes32`, `ExternDispatchV2 is bytes32`). The `SourceIndexV2` type remains as `uint256` because it is imported from the deprecated v1 `IInterpreterV2.sol`.

This type inconsistency means that `EvalV4` mixes `bytes32`-based types with a `uint256`-based type. A source index is a small value (typically fitting in `uint16` as the original `SourceIndex` type showed) but is stored in a full `uint256`. While this does not introduce a direct vulnerability at the interface level, it creates an inconsistency that could cause confusion during implementation and may result in implementations failing to validate that the upper bits are zero, which could lead to unexpected behavior depending on how the value is decoded.

---

### A06-4 | INFO | `stateOverlay` format in `EvalV4` is unspecified

**File:** `src/interface/IInterpreterV4.sol`, lines 50, 61-62

**Description:** The `stateOverlay` field in `EvalV4` is typed as `bytes32[]` with only a brief comment that it will "override corresponding gets from the store unless/until they are set to something else in the evaluated logic" (lines 96-98). Unlike `kvs` in `IInterpreterStoreV3.set()` which is documented as potentially pairwise key/value, the `stateOverlay` format is not specified at the interface level.

The store's `set` function documentation explicitly warns that implementations must guard against corruption (odd number of items, etc.). The `stateOverlay` has no equivalent guidance. If implementations assume a pairwise key/value format (consistent with the store's `kvs` parameter), a malformed overlay with an odd number of elements could cause out-of-bounds reads or silent data corruption depending on the implementation. The interface should specify the expected format or explicitly state that the format is implementation-defined.

---

### A06-5 | MEDIUM | `EvalV4.store` and `EvalV4.namespace` are caller-controlled with no interface-level guidance on validation

**File:** `src/interface/IInterpreterV4.sol`, lines 43-51; `src/interface/IInterpreterStoreV3.sol`, lines 43-48

**Description:** The `EvalV4` struct includes both a `store` (an `IInterpreterStoreV3` address) and a `namespace` (a `FullyQualifiedNamespace`). Both values are provided by the caller. The `namespace` field is typed as `FullyQualifiedNamespace` rather than `StateNamespace`, which means the caller provides an already-qualified namespace directly to the interpreter.

This design has a subtle security implication: the naming `FullyQualifiedNamespace` implies it has already been qualified (i.e., hashed with `msg.sender` via `LibNamespace.qualifyNamespace`), but the interface accepts it as a raw value from the caller. An interpreter implementation that trusts this value as-is would allow a caller to specify another caller's namespace, breaking the isolation guarantee.

The security documentation in `IInterpreterV4` (lines 71-82) places the burden on the caller to guard against corrupt return values, and the store documentation (lines 25-30) places the burden on the store to enforce caller isolation. However, there is a gap: the interface does not specify whether the interpreter should re-qualify the namespace or trust the caller-provided one. If an interpreter trusts the `FullyQualifiedNamespace` directly (since it is typed as "fully qualified"), it would bypass namespace isolation.

The `IInterpreterStoreV3.set()` function correctly accepts a `StateNamespace` (unqualified) and documents that the store MUST fully qualify it. But the reads path through `eval4` uses `FullyQualifiedNamespace`, creating an asymmetry where writes are protected by the store's qualification but reads during eval may not be if the interpreter passes the caller-provided namespace directly to `store.get()`.

---

### A06-6 | INFO | `IInterpreterExternV4.externIntegrity` uses `uint256` for input/output counts while stack uses `StackItem`

**File:** `src/interface/IInterpreterExternV4.sol`, lines 33-36

**Description:** The `externIntegrity` function accepts and returns `uint256` for `expectedInputs`, `expectedOutputs`, `actualInputs`, and `actualOutputs`. These are counts and `uint256` is appropriate for them. However, there is no interface-level constraint or documentation establishing a reasonable upper bound for these values. An implementation that allocates memory based on these counts without bounding them could be vulnerable to memory-based denial of service. Since all functions are `view`, this cannot cause state corruption, but it could cause excessive gas consumption or out-of-gas reverts in callers that do not guard against large return values.

---

### A06-7 | INFO | `ISubParserV4.subParseWord2` returns `memory` while other V4 functions use `calldata`

**File:** `src/interface/ISubParserV4.sol`, lines 68-71

**Description:** The `subParseWord2` function returns `(bool success, bytes memory bytecode, bytes32[] memory constants)` using `memory` return types, while `subParseLiteral2` in the same interface returns stack-based values, and most other V4 interface functions return `calldata` references. This is technically correct -- the sub parser may need to construct new bytecode and constants that do not exist in calldata -- but is worth noting as an intentional design choice. The `memory` return type means implementations must allocate and copy data, making this more expensive than `calldata` returns. Callers should be aware that the returned `bytecode` and `constants` from sub parsers are newly allocated memory that cannot be validated by calldata pointer bounds checking.

---

### A06-8 | LOW | `PragmaV1.usingWordsFrom` has no length or duplication constraints

**File:** `src/interface/IParserPragmaV1.sol`, lines 5-7

**Description:** The `PragmaV1` struct contains an `address[] usingWordsFrom` field with no interface-level constraints on:

1. Maximum array length -- a malicious input could specify an extremely large number of sub-parser addresses, causing implementations to iterate over all of them during parsing. Since `parsePragma1` is a `view` function, this cannot cause state changes but could be used to force excessive gas consumption.
2. Duplicate addresses -- the interface does not specify whether duplicates should be rejected or deduplicated. Duplicate sub-parser addresses could cause the same sub-parser to be queried multiple times for every unknown word/literal, compounding gas waste.
3. Zero addresses -- `address(0)` in the array could cause implementations to make external calls to the zero address, which would succeed but return empty data, potentially causing subtle parsing failures.

These are implementation-level concerns but the interface could provide guidance to reduce the risk of divergent implementations.

---

### A06-9 | LOW | No interface guidance on `EvalV4.bytecode` validation or maximum size

**File:** `src/interface/IInterpreterV4.sol`, lines 43-51

**Description:** The `EvalV4` struct accepts arbitrary `bytes bytecode` in calldata. The interface documentation does not specify:

1. Any maximum bytecode size that implementations should enforce.
2. Whether an empty bytecode (`bytes(0)`) is valid or should revert.
3. Whether the interpreter must validate the bytecode structure before execution.

The security model (lines 71-82) states the interpreter "MUST be resilient to malicious expressions" and "MAY return garbage or exhibit undefined behaviour or error during an eval, provided that no state changes are persisted." This provides some implicit guidance, but the absence of explicit bytecode validation requirements means implementations may diverge on how they handle malformed bytecode. Some may revert, some may return empty stacks, and some may execute partially -- all valid under the current spec but potentially surprising to callers who expect consistent behavior across interpreter implementations.

The `LibBytecode` library in this repository does provide validation functions, but the interface does not reference or require their use.

---

## Summary

| ID | Severity | Title |
|----|----------|-------|
| A06-1 | LOW | Stale documentation reference to `IInterpreterStoreV2` in `IInterpreterCallerV4` |
| A06-2 | INFO | `EncodedExternDispatchV2` type is defined but unused in any interface function |
| A06-3 | LOW | `SourceIndexV2` uses `uint256` while V4 type system uses `bytes32` |
| A06-4 | INFO | `stateOverlay` format in `EvalV4` is unspecified |
| A06-5 | MEDIUM | `EvalV4.store` and `EvalV4.namespace` are caller-controlled with no interface-level guidance on validation |
| A06-6 | INFO | `IInterpreterExternV4.externIntegrity` has no upper bound guidance for input/output counts |
| A06-7 | INFO | `ISubParserV4.subParseWord2` returns `memory` while other V4 functions use `calldata` |
| A06-8 | LOW | `PragmaV1.usingWordsFrom` has no length or duplication constraints |
| A06-9 | LOW | No interface guidance on `EvalV4.bytecode` validation or maximum size |

**Total findings: 9** (0 CRITICAL, 0 HIGH, 1 MEDIUM, 4 LOW, 4 INFO)
