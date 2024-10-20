// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibHandleOperand, Operand} from "src/lib/parse/LibHandleOperand.sol";
import {UnexpectedOperand} from "src/error/ErrParse.sol";

contract LibHandleOperandHandleOperandDisallowedTest is Test {
    function testHandleOperandDisallowedNoValues() external pure {
        assertEq(Operand.unwrap(LibHandleOperand.handleOperandDisallowedAlwaysOne(new uint256[](0))), 1);
    }

    function testHandleOperandDisallowedAnyValues(uint256[] memory values) external {
        vm.assume(values.length > 0);
        vm.expectRevert(abi.encodeWithSelector(UnexpectedOperand.selector));
        LibHandleOperand.handleOperandDisallowedAlwaysOne(values);
    }
}
