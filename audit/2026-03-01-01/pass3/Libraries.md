# Pass 3 -- Documentation Audit: Library Files

**Agent:** A01
**Date:** 2026-03-01
**Scope:** Documentation completeness and accuracy for all library files

---

## Files Reviewed

### 1. LibBytecode.sol

**Path:** `src/lib/bytecode/LibBytecode.sol`
**Library name:** `LibBytecode` (line 29)
**Library-level natspec:** Yes (lines 18-28). Title and notice present.

| Function | Line | Natspec | @param | @return | Accuracy |
|---|---|---|---|---|---|
| `sourceCount` | 44 | Yes (lines 34-43) | `bytecode` documented | `count` documented | Accurate |
| `checkNoOOBPointers` | 70 | Yes (lines 55-68) | None documented (only `bytecode`) | No return | See A01-1 |
| `sourceRelativeOffset` | 188 | Yes (lines 178-187) | `bytecode`, `sourceIndex` documented | `offset` documented | Accurate |
| `sourcePointer` | 209 | Yes (lines 200-208) | `bytecode`, `sourceIndex` documented | `pointer` documented | Accurate |
| `sourceOpsCount` | 227 | Yes (lines 219-226) | `bytecode`, `sourceIndex` documented | `opsCount` documented | Accurate |
| `sourceStackAllocation` | 246 | Yes (lines 236-245) | `bytecode`, `sourceIndex` documented | `allocation` documented | Accurate |
| `sourceInputsOutputsLength` | 272 | Yes (lines 259-271) | `bytecode`, `sourceIndex` documented | `inputs`, `outputs` documented | Accurate |
| `bytecodeToSources` | 291 | Yes (lines 287-290) | None | None | See A01-2 |

**Constants/Types:** None defined in this file (errors are imported from `ErrBytecode.sol`).

---

### 2. LibContext.sol

**Path:** `src/lib/caller/LibContext.sol`
**Library name:** `LibContext` (line 45)
**Library-level natspec:** Yes (lines 36-44). Title and notice present.

| Function | Line | Natspec | @param | @return | Accuracy |
|---|---|---|---|---|---|
| `base` | 63 | Yes (lines 48-62) | None (takes no params) | `baseArray` documented | Accurate |
| `hash(SignedContextV1)` | 79 | Yes (lines 73-78) | `signedContext` documented | `hashed` documented -- see A01-3 | See A01-3 |
| `hash(SignedContextV1[])` | 108 | Yes (lines 99-107) | `signedContexts` documented | `hashed` documented | Accurate |
| `build` | 166 | Yes (lines 140-165) | `baseContext`, `signedContexts` documented | Missing | See A01-4 |

**Constants:** `CONTEXT_BASE_COLUMN` (line 25), `CONTEXT_BASE_ROWS` (line 28), `CONTEXT_BASE_ROW_SENDER` (line 31), `CONTEXT_BASE_ROW_CALLING_CONTRACT` (line 34) -- all documented with `@dev`.

**Errors:** `InvalidSignature` (line 20) -- documented.

---

### 3. LibEvaluable.sol

**Path:** `src/lib/caller/LibEvaluable.sol`
**Library name:** `LibEvaluable` (line 16)
**Library-level natspec:** Yes (lines 12-15). Title and notice present.

| Function | Line | Natspec | @param | @return | Accuracy |
|---|---|---|---|---|---|
| `hash` | 23 | Yes (lines 17-22) | `evaluable` documented | `evaluableHash` documented (as unnamed return via description) | Accurate |

No findings for this file.

---

### 4. LibGenParseMeta.sol

**Path:** `src/lib/codegen/LibGenParseMeta.sol`
**Library name:** `LibGenParseMeta` (line 36)
**Library-level natspec:** Yes (lines 23-35). Title and notice present.

| Function | Line | Natspec | @param | @return | Accuracy |
|---|---|---|---|---|---|
| `findBestExpander` | 49 | Yes (lines 37-48) | `metas` documented | `bestSeed`, `bestExpansion`, `remaining` documented | Accurate |
| `buildParseMetaV2` | 126 | Yes (lines 100-125) | `authoringMeta`, `maxDepth` documented | `parseMeta` documented | Accurate |
| `parseMetaConstantString` | 241 | Yes (lines 232-240) | `vm`, `authoringMetaBytes`, `buildDepth` documented | Return documented (unnamed) | See A01-5 |

**Constants:** `META_ITEM_MASK` (line 18) -- not documented with `@dev`. See A01-6.
**Errors:** `DuplicateFingerprint` (line 21) -- documented with `@dev`.

---

### 5. LibNamespace.sol

**Path:** `src/lib/ns/LibNamespace.sol`
**Library name:** `LibNamespace` (line 11)
**Library-level natspec:** Yes (lines 7-10). Title and notice present.

| Function | Line | Natspec | @param | @return | Accuracy |
|---|---|---|---|---|---|
| `qualifyNamespace` | 24 | Yes (lines 12-23) | `stateNamespace`, `sender` documented | `qualifiedNamespace` documented | Accurate |

No findings for this file.

---

### 6. LibParseMeta.sol

**Path:** `src/lib/parse/LibParseMeta.sol`
**Library name:** `LibParseMeta` (line 32)
**Library-level natspec:** Yes (lines 28-31). Title and notice present.

| Function | Line | Natspec | @param | @return | Accuracy |
|---|---|---|---|---|---|
| `wordBitmapped` | 45 | Yes (lines 33-44) | `seed`, `word` documented | `bitmap`, `hashed` documented | See A01-7 |
| `lookupWord` | 67 | Yes (lines 60-66) | `meta`, `word` documented | Partially documented | See A01-8 |

**Constants:** `META_ITEM_SIZE` (line 8), `META_PREFIX_SIZE` (line 11), `FINGERPRINT_MASK` (line 23), `META_EXPANSION_SIZE` (line 26) -- all documented with `@dev`.

---

## Findings

### A01-1 | INFO | `checkNoOOBPointers` missing `@param` for `bytecode`

**File:** `src/lib/bytecode/LibBytecode.sol`, lines 55-70

The function `checkNoOOBPointers(bytes memory bytecode)` has thorough natspec describing what it does and what it checks, but it does not include an explicit `@param bytecode` tag. Every other function in `LibBytecode` that accepts `bytecode` explicitly documents it with `@param bytecode The bytecode to inspect.`

---

### A01-2 | LOW | `bytecodeToSources` missing `@param` and `@return` documentation

**File:** `src/lib/bytecode/LibBytecode.sol`, lines 287-316

The function `bytecodeToSources(bytes memory bytecode)` has a brief comment (lines 287-290) but is missing both `@param bytecode` and `@return` tags. Its comment mentions "backwards compatibility" and that it is "not recommended for production code" but does not document:
- What the `bytecode` parameter is or what format it must be in.
- What the return value `bytes[] memory` represents (the old-style individual source arrays).
- The structural transformation it performs (stripping 4-byte headers and shifting opcode indices).

This is the only function in `LibBytecode` without `@param`/`@return` tags, creating an inconsistency with the rest of the library.

---

### A01-3 | INFO | `hash(SignedContextV1)` natspec `@param` tag formatting for return value

**File:** `src/lib/caller/LibContext.sol`, lines 77-78

The natspec for `hash(SignedContextV1 memory signedContext)` uses `@param hashed` instead of `@return hashed` for the return value on line 78:

```solidity
/// @param signedContext The signed context to hash.
/// @param hashed The hashed signed context.
```

The second line should be `@return hashed The hashed signed context.` to match the Solidity natspec convention and to be consistent with `hash(SignedContextV1[] memory)` at line 107 which correctly uses `@return hashed`.

---

### A01-4 | LOW | `build` missing `@return` documentation

**File:** `src/lib/caller/LibContext.sol`, lines 140-169

The function `build(bytes32[][] memory baseContext, SignedContextV1[] memory signedContexts)` has thorough documentation for both parameters but does not include a `@return` tag for the returned `bytes32[][] memory`. The return value is the fully assembled context matrix, whose structure (base column first, then caller-provided columns, then signers column and signed context columns) is important for callers to understand. While the structure is partially described in the `@param` documentation, a dedicated `@return` tag would make it explicit.

---

### A01-5 | INFO | `parseMetaConstantString` uses `Vm` parameter without noting it is Foundry-only

**File:** `src/lib/codegen/LibGenParseMeta.sol`, lines 232-244

The `Vm` parameter is documented as `@param vm The Vm instance to use for generating the constant string` but the natspec does not make clear that `Vm` is Foundry's cheatcode interface and this function is only usable in a test/codegen context. The library-level natspec does not note this either. While the import of `forge-std/Vm.sol` on line 14 is a hint, an explicit note would improve clarity for consumers, especially given the library-level comment says the library is for "building parse meta from authoring meta" without mentioning the Foundry dependency.

---

### A01-6 | INFO | `META_ITEM_MASK` constant missing `@dev` documentation

**File:** `src/lib/codegen/LibGenParseMeta.sol`, line 18

The constant `META_ITEM_MASK` is defined as `(1 << META_ITEM_SIZE) - 1` but has no `@dev` natspec explaining its purpose. All other constants in the related `LibParseMeta.sol` (`META_ITEM_SIZE`, `META_PREFIX_SIZE`, `FINGERPRINT_MASK`, `META_EXPANSION_SIZE`) have `@dev` documentation. This constant is used as a mask in `buildParseMetaV2` at line 221 to mask out existing data when writing items, and would benefit from a brief explanation of its role.

---

### A01-7 | INFO | `wordBitmapped` return documentation names mismatch

**File:** `src/lib/parse/LibParseMeta.sol`, lines 33-44

The `@return` tag documents the second return value as `hashed` with the description "A uint256 with the low 3 bytes set" (line 43-44). However, the actual return value `hashed` is the full `keccak256` hash (line 49); it is the *caller* that must apply `FINGERPRINT_MASK` to extract only the low 3 bytes. The description "with the low 3 bytes set" could be misleading -- it implies the returned value already has only the low 3 bytes, when in fact it is a full 32-byte hash. The function's own inline comment (lines 50-56) correctly describes the situation, but the `@return` natspec is slightly inaccurate.

---

### A01-8 | LOW | `lookupWord` return values not documented with `@return` names

**File:** `src/lib/parse/LibParseMeta.sol`, lines 60-67

The function `lookupWord` returns `(bool, uint256)` and the natspec provides two `@return` tags (lines 65-66):

```solidity
/// @return True if the word exists in the parse meta.
/// @return The index of the word in the parse meta.
```

The return values are unnamed in the function signature on line 67. While the descriptions are adequate, naming the return values (e.g., `exists` and `index`) would improve code readability and tooling support. Additionally, the natspec on line 60 mentions "return the index and io fn pointer" but the function does not return any "io fn pointer" -- it returns a boolean and an index. This text appears to be a stale remnant from a prior version of the function, making the natspec description inaccurate relative to the actual implementation.

---

## Summary

| ID | Severity | File | Title |
|---|---|---|---|
| A01-1 | INFO | LibBytecode.sol | `checkNoOOBPointers` missing `@param` for `bytecode` |
| A01-2 | LOW | LibBytecode.sol | `bytecodeToSources` missing `@param` and `@return` documentation |
| A01-3 | INFO | LibContext.sol | `hash(SignedContextV1)` uses `@param` instead of `@return` for return value |
| A01-4 | LOW | LibContext.sol | `build` missing `@return` documentation |
| A01-5 | INFO | LibGenParseMeta.sol | `parseMetaConstantString` does not note Foundry-only dependency |
| A01-6 | INFO | LibGenParseMeta.sol | `META_ITEM_MASK` constant missing `@dev` documentation |
| A01-7 | INFO | LibParseMeta.sol | `wordBitmapped` return documentation inaccurately describes `hashed` |
| A01-8 | LOW | LibParseMeta.sol | `lookupWord` natspec mentions stale "io fn pointer" and returns are unnamed |

**Total findings:** 8 (3 LOW, 5 INFO)
