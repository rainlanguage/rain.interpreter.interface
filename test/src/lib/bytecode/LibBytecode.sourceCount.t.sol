// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibBytecode} from "src/lib/bytecode/LibBytecode.sol";
import {LibBytecodeSlow} from "test/src/lib/bytecode/LibBytecodeSlow.sol";

contract LibBytecodeSourceCountTest is Test {
    /// Test that a zero length bytecode returns zero sources.
    function testSourceCount0() external pure {
        assertEq(LibBytecode.sourceCount(""), 0);
    }

    /// Test that a non-zero length bytecode returns the first byte as the
    /// source count.
    function testSourceCount1(bytes memory bytecode) external pure {
        vm.assume(bytecode.length > 0);
        assertEq(LibBytecode.sourceCount(bytecode), uint256(uint8(bytecode[0])));
    }

    /// Test against a reference implementation.
    function testSourceCountReference(bytes memory bytecode) external pure {
        assertEq(LibBytecode.sourceCount(bytecode), LibBytecodeSlow.sourceCountSlow(bytecode));
    }
}
