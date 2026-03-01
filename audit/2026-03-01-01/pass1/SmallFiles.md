# Audit Pass 1 (Security) -- Small Files Review

**Agent:** A05
**Date:** 2026-03-01
**Scope:**
- `src/lib/caller/LibEvaluable.sol`
- `src/lib/ns/LibNamespace.sol`
- `src/error/ErrBytecode.sol`
- `src/error/ErrExtern.sol`
- `src/error/ErrIntegrity.sol`

---

## Evidence of Thorough Reading

### 1. `src/lib/caller/LibEvaluable.sol`

- **Library name:** `LibEvaluable` (line 16)
- **Functions:**
  - `hash(EvaluableV4 memory evaluable) internal pure returns (bytes32)` -- line 23
- **Imports:** `IInterpreterStoreV3` (line 8), `EvaluableV4` (line 10)
- **Assembly block:** lines 26-34, marked `"memory-safe"`, uses scratch space (0x00-0x3f)
- **Hashing strategy:** Two-phase hash -- first hashes the two address fields (`interpreter`, `store`) as a 64-byte region, then hashes bytecode content, then combines the two hashes.

### 2. `src/lib/ns/LibNamespace.sol`

- **Library name:** `LibNamespace` (line 11)
- **Functions:**
  - `qualifyNamespace(StateNamespace stateNamespace, address sender) internal pure returns (FullyQualifiedNamespace qualifiedNamespace)` -- line 24
- **Imports:** `StateNamespace`, `FullyQualifiedNamespace` from `IInterpreterV4.sol` (line 5)
- **Types used:** `StateNamespace` is `uint256`, `FullyQualifiedNamespace` is `uint256`
- **Assembly block:** lines 29-33, marked `"memory-safe"`, uses scratch space (0x00-0x3f)

### 3. `src/error/ErrBytecode.sol`

- **Errors defined:**
  - `SourceIndexOutOfBounds(uint256 sourceIndex, bytes bytecode)` -- line 8
  - `UnexpectedSources(bytes bytecode)` -- line 12
  - `UnexpectedTrailingOffsetBytes(bytes bytecode)` -- line 16
  - `TruncatedSource(bytes bytecode)` -- line 21
  - `TruncatedHeader(bytes bytecode)` -- line 26
  - `TruncatedHeaderOffsets(bytes bytecode)` -- line 30
  - `StackSizingsNotMonotonic(bytes bytecode, uint256 relativeOffset)` -- line 36
- **All errors are custom errors** (no `require` strings).
- All seven errors are used in `src/lib/bytecode/LibBytecode.sol`.

### 4. `src/error/ErrExtern.sol`

- **Errors defined:**
  - `NotAnExternContract(address extern)` -- line 6
  - `BadInputs(uint256 expected, uint256 actual)` -- line 12
- **Usage:** Neither error is imported or used anywhere within this repository. They are interface-level definitions for implementations.

### 5. `src/error/ErrIntegrity.sol`

- **Errors defined:**
  - `BadOpInputsLength(uint256 opIndex, uint256 calculatedInputs, uint256 bytecodeInputs)` -- line 9
  - `BadOpOutputsLength(uint256 opIndex, uint256 calculatedOutputs, uint256 bytecodeOutputs)` -- line 15
- **Usage:** Neither error is imported or used anywhere within this repository. They are interface-level definitions for implementations.

---

## Findings

### A05-1 | INFO | LibEvaluable hash reads raw memory bytes for address fields rather than masking

**File:** `src/lib/caller/LibEvaluable.sol`, line 28

**Description:**

The `hash` function hashes the first 64 bytes of the `EvaluableV4` struct in memory via `keccak256(evaluable, 0x40)`. The struct fields at offset 0x00 and 0x20 are `IInterpreterV4` and `IInterpreterStoreV3` (both `address`-typed interface references), stored as 32-byte words with the address right-aligned and 12 bytes of zero-padding on the left.

The reference implementation in `LibEvaluableSlow.hashSlow` (test file) explicitly cleans the addresses via `uint256(uint160(address(...)))` before hashing:

```solidity
keccak256(abi.encodePacked(
    uint256(uint160(address(evaluable.interpreter))),
    uint256(uint160(address(evaluable.store)))
))
```

The optimized assembly version hashes the raw memory including the high 12 bytes of each slot. In standard Solidity execution, these bytes are always zero because the compiler cleans address values when writing to memory. However, if a struct were constructed via assembly with dirty upper bits, the optimized and reference implementations would diverge. The existing fuzz test (`testEvaluableV4ReferenceImplementation`) uses Solidity-constructed structs, so it does not exercise this case.

**Impact:** Negligible in practice. Solidity guarantees clean address representations in memory for normally constructed values. This only affects structs constructed via assembly with intentionally dirty padding, which would be misuse of the type system. The two implementations are equivalent for all well-formed inputs.

---

### A05-2 | INFO | ErrExtern.sol and ErrIntegrity.sol errors are defined but unused in this repository

**File:** `src/error/ErrExtern.sol` (lines 6, 12), `src/error/ErrIntegrity.sol` (lines 9, 15)

**Description:**

The errors `NotAnExternContract`, `BadInputs`, `BadOpInputsLength`, and `BadOpOutputsLength` are defined but never imported or referenced anywhere in this codebase. A search for `import.*ErrExtern` and `import.*ErrIntegrity` across the entire `src/` directory returns zero results.

This is expected for an interface library -- these errors define a standard error ABI that implementing contracts (interpreters, extern contracts) are expected to use. However, the lack of usage within this repository means there is no compile-time verification that the error signatures remain consistent with any implementation expectations.

**Impact:** No security impact. These are purely interface-level definitions. Downstream implementations that import and use these errors will get compile-time checking.

---

### A05-3 | INFO | LibNamespace.qualifyNamespace does not enforce that `sender` is `msg.sender`

**File:** `src/lib/ns/LibNamespace.sol`, line 24

**Description:**

The `qualifyNamespace` function is `internal pure` and accepts any `address sender` parameter. It does not and cannot enforce that the caller passes `msg.sender`. The NatSpec on line 14 states it "essentially just hashes the `msg.sender` into the state namespace as-is," but the function itself has no such restriction.

This is by design -- the function is a pure utility, and enforcing `msg.sender` would require it to be `view` and would limit composability. The responsibility for passing the correct sender rests entirely with the calling contract. The documentation on line 8-10 explicitly marks this as "OPTIONAL" functionality.

**Impact:** No direct vulnerability. A calling contract that passes an incorrect `sender` could break namespace isolation, but this would be a bug in the calling contract, not in this library. The documentation is clear about the caller's responsibility.

---

### A05-4 | INFO | No domain separation between LibEvaluable.hash and LibNamespace.qualifyNamespace

**File:** `src/lib/caller/LibEvaluable.sol` line 33, `src/lib/ns/LibNamespace.sol` line 32

**Description:**

Both `LibEvaluable.hash` (final step) and `LibNamespace.qualifyNamespace` produce a `bytes32` by hashing exactly 64 bytes from scratch space via `keccak256(0, 0x40)`. Neither incorporates a domain separator (e.g., a type tag or unique prefix). If the same pair of 32-byte values were placed at 0x00 and 0x20 in both contexts, the results would collide.

In practice, this is not exploitable:
- `LibEvaluable.hash` stores two intermediate keccak256 hashes at 0x00 and 0x20 before the final hash.
- `LibNamespace.qualifyNamespace` stores a `StateNamespace` (uint256) and an `address` (cleaned to 20 bytes, 12 zero-padded).
- The output types are distinct (`bytes32` vs `FullyQualifiedNamespace`) and are never compared in the same context.
- The intermediate keccak256 hashes in `LibEvaluable.hash` are uniformly distributed, making an accidental match with a (stateNamespace, sender) pair astronomically unlikely.

**Impact:** Theoretical only. The different input structures and disjoint usage contexts make cross-domain collision practically impossible.

---

## Summary

No CRITICAL, HIGH, MEDIUM, or LOW severity findings were identified. The five files under review are minimal, well-structured, and follow security best practices:

- All error definitions use custom errors (no string-based reverts).
- Assembly blocks are correctly marked `"memory-safe"` and only use scratch space for writes.
- The hashing logic in `LibEvaluable.hash` correctly uses a two-phase Merkle-like approach that is sensitive to all three struct fields (interpreter, store, bytecode), as validated by comprehensive fuzz tests.
- Namespace qualification in `LibNamespace.qualifyNamespace` correctly hashes the sender with the state namespace to produce disjoint qualified namespaces per caller.
- The `keccak256`-based approach to namespace isolation is sound -- collisions require a keccak256 preimage attack which is computationally infeasible.

Four INFO-level observations were noted for completeness, none of which represent actionable security concerns.
