// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity =0.8.25;

import {BytecodeTest} from "test/abstract/BytecodeTest.sol";
import {LibBytecode, SourceIndexOutOfBounds} from "src/lib/bytecode/LibBytecode.sol";
import {LibBytecodeSlow} from "test/src/lib/bytecode/LibBytecodeSlow.sol";

contract LibBytecodeSourceStackAllocationTest is BytecodeTest {
    function sourceStackAllocationExternal(bytes memory bytecode, uint256 sourceIndex)
        external
        pure
        returns (uint256 allocation)
    {
        return LibBytecode.sourceStackAllocation(bytecode, sourceIndex);
    }

    /// Getting the source stack allocation for an index beyond the sources
    /// should fail.
    function testSourceStackAllocationIndexOutOfBounds(
        bytes memory bytecode,
        uint256 sourceCount,
        uint256 sourceIndex,
        bytes32 seed
    ) external {
        conformBytecode(bytecode, sourceCount, seed);
        sourceCount = LibBytecode.sourceCount(bytecode);
        sourceIndex = bound(sourceIndex, sourceCount, type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(SourceIndexOutOfBounds.selector, sourceIndex, bytecode));
        this.sourceStackAllocationExternal(bytecode, sourceIndex);
    }

    /// Test against a reference implementation.
    function testSourceStackAllocationAgainstSlow(
        bytes memory bytecode,
        uint256 sourceCount,
        uint256 sourceIndex,
        bytes32 seed
    ) external pure {
        conformBytecode(bytecode, sourceCount, seed);
        sourceCount = LibBytecode.sourceCount(bytecode);
        vm.assume(sourceCount > 0);
        sourceIndex = bound(sourceIndex, 0, sourceCount - 1);
        assertEq(
            LibBytecode.sourceStackAllocation(bytecode, sourceIndex),
            LibBytecodeSlow.sourceStackAllocationSlow(bytecode, sourceIndex)
        );
    }
}
