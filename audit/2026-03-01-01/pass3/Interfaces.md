# Pass 3 — Documentation Audit (Agent A02)

## Scope

All current (non-deprecated) interface and error files in `src/interface/` and `src/error/`.

---

## File-by-File Evidence of Review

### 1. `src/interface/IInterpreterV4.sol`

| Item | Kind | Line(s) |
|------|------|---------|
| `OperandV2` | user-defined value type | 39 |
| `StackItem` | user-defined value type | 41 |
| `EvalV4` | struct | 43-51 |
| `IInterpreterV4` | interface | 89-102 |
| `eval4` | function | 101 |

### 2. `src/interface/IInterpreterStoreV3.sol`

| Item | Kind | Line(s) |
|------|------|---------|
| `IInterpreterStoreV3` | interface | 31-66 |
| `Set` | event | 36 |
| `set` | function | 48 |
| `get` | function | 65 |

### 3. `src/interface/IInterpreterCallerV4.sol`

| Item | Kind | Line(s) |
|------|------|---------|
| `EvaluableV4` | struct | 25-29 |
| `IInterpreterCallerV4` | interface | 39-48 |
| `ContextV2` | event | 47 |

### 4. `src/interface/IInterpreterExternV4.sol`

| Item | Kind | Line(s) |
|------|------|---------|
| `EncodedExternDispatchV2` | user-defined value type | 7 |
| `ExternDispatchV2` | user-defined value type | 9 |
| `IInterpreterExternV4` | interface | 21-47 |
| `externIntegrity` | function | 33-36 |
| `extern` | function | 43-46 |

### 5. `src/interface/IParserV2.sol`

| Item | Kind | Line(s) |
|------|------|---------|
| `IParserV2` | interface | 9-11 |
| `parse2` | function | 10 |

### 6. `src/interface/ISubParserV4.sol`

| Item | Kind | Line(s) |
|------|------|---------|
| `ISubParserV4` | interface | 18-72 |
| `subParseLiteral2` | function | 40 |
| `subParseWord2` | function | 68-71 |

### 7. `src/interface/IParserPragmaV1.sol`

| Item | Kind | Line(s) |
|------|------|---------|
| `PragmaV1` | struct | 5-7 |
| `parsePragma1` | function | 10 |
| `IParserPragmaV1` | interface | 9-11 |

### 8. `src/error/ErrBytecode.sol`

| Item | Kind | Line(s) |
|------|------|---------|
| `SourceIndexOutOfBounds` | error | 8 |
| `UnexpectedSources` | error | 12 |
| `UnexpectedTrailingOffsetBytes` | error | 16 |
| `TruncatedSource` | error | 21 |
| `TruncatedHeader` | error | 26 |
| `TruncatedHeaderOffsets` | error | 30 |
| `StackSizingsNotMonotonic` | error | 36 |

### 9. `src/error/ErrExtern.sol`

| Item | Kind | Line(s) |
|------|------|---------|
| `NotAnExternContract` | error | 6 |
| `BadInputs` | error | 12 |

### 10. `src/error/ErrIntegrity.sol`

| Item | Kind | Line(s) |
|------|------|---------|
| `BadOpInputsLength` | error | 9 |
| `BadOpOutputsLength` | error | 15 |

---

## Findings

### A02-1 | LOW | `OperandV2` type has no natspec documentation

**File:** `src/interface/IInterpreterV4.sol`, line 39

The user-defined value type `OperandV2` is declared as:

```solidity
type OperandV2 is bytes32;
```

There is no natspec comment explaining what an operand represents in this context, how it differs from the prior `Operand` type (which was `uint256`-based and is still re-exported from the deprecated v1 path), or how the `bytes32` representation should be interpreted.

---

### A02-2 | LOW | `StackItem` type has no natspec documentation

**File:** `src/interface/IInterpreterV4.sol`, line 41

The user-defined value type `StackItem` is declared as:

```solidity
type StackItem is bytes32;
```

There is no natspec comment. `StackItem` is a fundamental type used across the interpreter, extern, and eval interfaces. Its semantics (e.g. that it holds packed Rain decimal floats, or arbitrary 32-byte values) should be documented at the definition site.

---

### A02-3 | LOW | `EvalV4` struct has no natspec documentation

**File:** `src/interface/IInterpreterV4.sol`, lines 43-51

The `EvalV4` struct is declared without any natspec `@title`, `@notice`, or `@dev` comment, and none of its seven fields have `@param` documentation:

```solidity
struct EvalV4 {
    IInterpreterStoreV3 store;
    FullyQualifiedNamespace namespace;
    bytes bytecode;
    SourceIndexV2 sourceIndex;
    bytes32[][] context;
    StackItem[] inputs;
    bytes32[] stateOverlay;
}
```

The struct is the sole parameter to the central `eval4` function. Each field deserves a `@param` tag explaining its role, constraints, and expected format. In particular:
- `stateOverlay` is new in V4 and its encoding/semantics are undocumented at the struct level.
- `inputs` vs `context` distinction is not explained.
- The relationship between `bytecode` and `sourceIndex` is not described.

---

### A02-4 | LOW | `eval4` function lacks `@param` and `@return` natspec tags

**File:** `src/interface/IInterpreterV4.sol`, lines 90-101

The `eval4` function has a prose comment (lines 90-100) but no formal `@param` or `@return` tags:

```solidity
/// Rainlang magic happens here.
///
/// Pass Rainlang bytecode in calldata, and get back the stack and storage
/// writes.
///
/// Key differences in `eval4`:
/// - Supports state overlays ...
/// - Numbers are treated as packed Rain decimal floats ...
function eval4(EvalV4 calldata eval) external view returns (StackItem[] calldata stack, bytes32[] calldata writes);
```

Missing:
- `@param eval` — description of the eval parameter.
- `@return stack` — what the returned stack represents (e.g. output values from the evaluated source).
- `@return writes` — what the writes represent and how the caller should handle them (e.g. pass to `IInterpreterStoreV3.set`).

---

### A02-5 | LOW | `IParserV2` interface and `parse2` function have no natspec documentation

**File:** `src/interface/IParserV2.sol`, lines 9-11

The entire interface is bare:

```solidity
interface IParserV2 {
    function parse2(bytes calldata data) external view returns (bytes calldata bytecode);
}
```

Missing:
- `@title` / `@notice` on `IParserV2` describing its purpose.
- `@param data` on `parse2` — what the input data represents (Rainlang source? encoded data?).
- `@return bytecode` — what format the bytecode is in, relationship to `EvalV4.bytecode`.
- Implementer responsibilities (e.g. revert on invalid input, what constitutes valid Rainlang).

---

### A02-6 | LOW | `IParserPragmaV1` interface and `parsePragma1` function have no natspec documentation

**File:** `src/interface/IParserPragmaV1.sol`, lines 9-11

```solidity
interface IParserPragmaV1 {
    function parsePragma1(bytes calldata data) external view returns (PragmaV1 calldata);
}
```

Missing:
- `@title` / `@notice` on `IParserPragmaV1`.
- `@param data` on `parsePragma1` — what the input bytes represent.
- `@return` — when it might revert vs return an empty pragma.
- Implementer responsibilities.

---

### A02-7 | LOW | `PragmaV1` struct has no natspec documentation

**File:** `src/interface/IParserPragmaV1.sol`, lines 5-7

```solidity
struct PragmaV1 {
    address[] usingWordsFrom;
}
```

Missing:
- Natspec explaining the purpose of this struct.
- `@param usingWordsFrom` — what addresses this refers to (sub-parser contracts? extern contracts?) and how they are used by the parser.

---

### A02-8 | INFO | `EncodedExternDispatchV2` type has no natspec documentation

**File:** `src/interface/IInterpreterExternV4.sol`, line 7

```solidity
type EncodedExternDispatchV2 is bytes32;
```

No natspec explains what "encoded" means in this context, how it differs from `ExternDispatchV2`, or what encoding scheme is used. The type is not used directly in the interface functions (which use `ExternDispatchV2`), but it is exported for downstream use.

---

### A02-9 | INFO | `ExternDispatchV2` type has no natspec documentation

**File:** `src/interface/IInterpreterExternV4.sol`, line 9

```solidity
type ExternDispatchV2 is bytes32;
```

No natspec explains the structure or semantics of this dispatch value. The function-level docs say it is "analogous to the opcode/operand in the interpreter" but the type definition itself is undocumented.

---

### A02-10 | INFO | `NotAnExternContract` error has no `@param` tag for its parameter

**File:** `src/error/ErrExtern.sol`, line 6

```solidity
/// Thrown when the extern interface is not supported.
error NotAnExternContract(address extern);
```

The error has a descriptive comment but no `@param extern` tag documenting its parameter. By contrast, `BadInputs` on line 12 in the same file does document its parameters.

---

### A02-11 | INFO | `IInterpreterCallerV4` natspec references `IInterpreterStoreV2` instead of `IInterpreterStoreV3`

**File:** `src/interface/IInterpreterCallerV4.sol`, line 38

The interface-level natspec says:

```solidity
/// - OPTIONALLY set state on the associated `IInterpreterStoreV2`.
```

This should reference `IInterpreterStoreV3`, which is the store version actually imported and used in `EvaluableV4` on line 27 of the same file. The V2 reference is a stale leftover from the V3 caller interface.

---

### A02-12 | INFO | `EvaluableV4` struct natspec uses bare `@param` tags without `@notice` or `@dev` context

**File:** `src/interface/IInterpreterCallerV4.sol`, lines 22-29

The struct has `@param` tags (lines 22-24) but no surrounding `@notice` or `@dev` to describe the struct's overall purpose. The V3 predecessor (`EvaluableV3` in the deprecated file) had a prose description ("Struct over the return of `IParserV2.parse2` which MAY be more convenient to work with than raw addresses.") but this was dropped in V4. While the `@param` tags are present, a one-line purpose statement would improve clarity.

---

## Summary

| Severity | Count |
|----------|-------|
| LOW | 7 |
| INFO | 5 |
| **Total** | **12** |

The most significant documentation gaps are concentrated in `IInterpreterV4.sol` (types `OperandV2`, `StackItem`, struct `EvalV4`, and function `eval4` lacking formal param/return tags) and `IParserV2.sol` / `IParserPragmaV1.sol` (entirely undocumented interfaces). The error files and `IInterpreterStoreV3`, `IInterpreterExternV4`, and `ISubParserV4` are generally well-documented, with only minor gaps noted at INFO level.
