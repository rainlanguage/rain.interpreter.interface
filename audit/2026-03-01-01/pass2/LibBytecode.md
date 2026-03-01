# Audit Pass 2 -- Test Coverage for LibBytecode.sol

**Agent:** A01
**Date:** 2026-03-01
**Source file:** `src/lib/bytecode/LibBytecode.sol`

---

## Source Inventory

**Library:** `LibBytecode` (line 29)

| # | Function | Line |
|---|----------|------|
| 1 | `sourceCount(bytes memory)` | 44 |
| 2 | `checkNoOOBPointers(bytes memory)` | 70 |
| 3 | `sourceRelativeOffset(bytes memory, uint256)` | 188 |
| 4 | `sourcePointer(bytes memory, uint256)` | 209 |
| 5 | `sourceOpsCount(bytes memory, uint256)` | 227 |
| 6 | `sourceStackAllocation(bytes memory, uint256)` | 246 |
| 7 | `sourceInputsOutputsLength(bytes memory, uint256)` | 272 |
| 8 | `bytecodeToSources(bytes memory)` | 291 |

---

## Test Inventory

### `LibBytecodeSourceCountTest` (LibBytecode.sourceCount.t.sol)

| # | Test Function | Line |
|---|---------------|------|
| 1 | `testSourceCount0()` | 11 |
| 2 | `testSourceCount1(bytes)` | 17 |
| 3 | `testSourceCountReference(bytes)` | 23 |

### `LibBytecodeSourceOpsCountTest` (LibBytecode.sourceOpsCount.t.sol)

| # | Test Function | Line |
|---|---------------|------|
| 1 | `testSourceOpsCount()` | 14 |
| 2 | `testSourceOpsCountIndexOutOfBounds(bytes,uint256,uint256,bytes32)` | 26 |
| 3 | `testSourceOpsCountAgainstSlow(bytes,uint256,uint256,bytes32)` | 40 |

### `LibBytecodeSourceStackAllocationTest` (LibBytecode.sourceStackAllocation.t.sol)

| # | Test Function | Line |
|---|---------------|------|
| 1 | `testSourceStackAllocationIndexOutOfBounds(bytes,uint256,uint256,bytes32)` | 20 |
| 2 | `testSourceStackAllocationAgainstSlow(bytes,uint256,uint256,bytes32)` | 34 |

### `LibBytecodeSourceRelativeOffsetTest` (LibBytecode.sourceRelativeOffset.t.sol)

| # | Test Function | Line |
|---|---------------|------|
| 1 | `testSourceRelativeOffsetHappy()` | 11 |
| 2 | `testSourceRelativeOffsetIndexError()` | 36 |
| 3 | `testSourceRelativeOffsetReference(bytes,uint256,uint256,bytes32)` | 65 |

### `LibBytecodeSourceInputsOutputsTest` (LibBytecode.sourceInputsOutputs.t.sol)

| # | Test Function | Line |
|---|---------------|------|
| 1 | `testSourceInputsOutputsIndexOutOfBounds(bytes,uint256,uint256,bytes32)` | 20 |
| 2 | `testSourceInputsOutputsAgainstSlow(bytes,uint256,uint256,bytes32)` | 34 |

### `LibBytecodeCheckNoOOBPointersTest` (LibBytecode.checkNoOOBPointers.t.sol)

| # | Test Function | Line |
|---|---------------|------|
| 1 | `testCheckNoOOBPointersConforming(bytes,uint256,bytes32)` | 18 |
| 2 | `testCheckNoOOBPointers0()` | 31 |
| 3 | `testCheckNoOOBPointers1()` | 36 |
| 4 | `testCheckNoOOBPointers1Fail(bytes)` | 41 |
| 5 | `testCheckNoOOBPointersOffsetsTruncated(bytes,uint8,uint256)` | 51 |
| 6 | `testCheckNoOOBPointersHeaderTruncated(bytes,uint8,bytes32,uint256)` | 73 |
| 7 | `testCheckNoOOBPointersSourceTruncated(bytes,uint8,bytes32,uint8)` | 111 |
| 8 | `testCheckNoOOBPointersTrailingOffsetBytes(bytes,bytes,uint8,bytes32)` | 138 |
| 9 | `testCheckNoOOBPointersCorruptSourcesCount(bytes,uint8,bytes32,uint8)` | 193 |
| 10 | `testCheckNoOOBPointersCorruptOffsetPointer(bytes,uint8,bytes32,uint8)` | 214 |
| 11 | `testCheckNoOOBPointersCorruptOpsCount(bytes,uint8,bytes32,uint8)` | 237 |
| 12 | `testCheckNoOOBPointersEndGarbage(bytes,bytes)` | 266 |
| 13 | `testCheckNoOOBPointersInputsNotMonotonic(bytes,uint8,bytes32,uint256,uint256)` | 278 |
| 14 | `testCheckNoOOBPointersOutputsNotMonotonic(bytes,uint8,bytes32,uint256,uint256)` | 333 |

### `LibBytecodeSourcePointerTest` (LibBytecode.sourcePointer.t.sol)

| # | Test Function | Line |
|---|---------------|------|
| 1 | `testSourcePointerEmpty0(uint256)` | 17 |
| 2 | `testSourcePointerEmpty1(uint256)` | 25 |
| 3 | `testSourcePointerIndexOutOfBounds(bytes,uint256,uint256,bytes32)` | 32 |
| 4 | `testSourcePointerAgainstSlow(bytes,uint256,uint256,bytes32)` | 46 |

### Support files

- `LibBytecodeSlow.sol`: Slow reference implementations for `sourceCount`, `sourceRelativeOffset`, `sourcePointer`, `sourceOpsCount`, `sourceStackAllocation`, `sourceInputsOutputsLength`. No reference implementation for `bytecodeToSources`.
- `BytecodeTest.sol`: Abstract test base providing `conformBytecode` (fuzz helper) and `randomSourceIndex`/`randomSourcePosition`.

---

## Findings

### A01-1 | HIGH | `bytecodeToSources` has zero test coverage

The function `bytecodeToSources` (line 291-316) has no test file, no test function, and is never called anywhere in the test suite. A grep across the entire test directory for `bytecodeToSources` returns zero matches. There is also no slow reference implementation in `LibBytecodeSlow.sol`.

This function contains non-trivial inline assembly (lines 303-311) that performs opcode index byte-shuffling in a loop (`mstore8` to move the opcode index into the input position and zero the original). Bugs in this assembly loop -- such as off-by-one in the cursor increment, incorrect byte offset in `mstore8`, or failure to handle zero-length sources -- would go entirely undetected.

**Untested paths include:**
- Zero sources (empty array return)
- Single source with zero opcodes (zero-length inner `bytes`)
- Single source with one or more opcodes (byte-shuffling correctness)
- Multiple sources (correct iteration and offset calculation)
- Large opcode counts near the 255-op maximum per source

### A01-2 | LOW | No explicit test for `sourceCount` with a single-byte input of value 0

The test `testSourceCount0` only tests the empty bytes case (`""`). While `testSourceCount1` is a fuzz test that covers `bytecode.length > 0`, there is no explicit unit test asserting `sourceCount(hex"00") == 0`. This is a documented equivalence in the function's NatSpec ("0x and 0x00 are equivalent, both having 0 sources"). The `checkNoOOBPointers` tests do exercise `hex"00"` indirectly (`testCheckNoOOBPointers1`), so the gap is minor, but the `sourceCount` test contract itself does not explicitly verify this documented invariant.

### A01-3 | INFO | `conformBytecode` may mask edge cases at extreme source counts

The `conformBytecode` helper in `BytecodeTest.sol` (line 8) caps `maxSourceCount` at 255 and requires each source to consume at least 6 bytes (2 offset + 4 header). This means fuzz testing never produces bytecode with a source count byte of 255 unless the input `bytes` is at least 1531 bytes long (1 + 255*2 + 255*4). Typical fuzz inputs may be much shorter, meaning high source counts (e.g., 128-255 sources) may be underexercised. This is an inherent limitation of the fuzz approach rather than a definitive gap, but it is worth noting that boundary behavior near `sourceCount == 255` is unlikely to be heavily tested in practice.

### A01-4 | INFO | `sourceStackAllocation` has no explicit happy-path unit test

Unlike `sourceOpsCount` and `sourceRelativeOffset`, which both have dedicated `testSourceOpsCount()` and `testSourceRelativeOffsetHappy()` unit tests with hand-crafted bytecode examples, `sourceStackAllocation` relies entirely on fuzz tests against the slow reference implementation. While the fuzz approach is arguably more thorough, the lack of any hand-crafted example test means a correlated bug in both the production and reference implementation would go undetected. The same observation applies to `sourceInputsOutputsLength`.
