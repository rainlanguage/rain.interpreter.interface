// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {IInterpreterExternV3} from "src/interface/IInterpreterExternV3.sol";
import {BaseRainterpreterExternV3} from "src/abstract/BaseRainterpreterExternV3.sol";

/// @dev We need a contract that is deployable in order to test the abstract
/// base contract.
contract ChildRainterpreterExternV3 is BaseRainterpreterExternV3 {
    function buildIntegrityFunctionPointers() external pure returns (bytes memory) {
        return new bytes(0);
    }

    function buildOpcodeFunctionPointers() external pure returns (bytes memory) {
        return new bytes(0);
    }
}

/// @title BaseRainterpreterExternV3Test
/// Test suite for BaseRainterpreterExternV3.
contract BaseRainterpreterExternV3IERC165Test is Test {
    /// Test that ERC165 and IInterpreterExternV3 are supported interfaces as
    /// per ERC165.
    function testRainterpreterExternV3IERC165(bytes4 badInterfaceId) external {
        vm.assume(badInterfaceId != type(IERC165).interfaceId);
        vm.assume(badInterfaceId != type(IInterpreterExternV3).interfaceId);

        ChildRainterpreterExternV3 extern = new ChildRainterpreterExternV3();
        assertTrue(extern.supportsInterface(type(IERC165).interfaceId));
        assertTrue(extern.supportsInterface(type(IInterpreterExternV3).interfaceId));
        assertFalse(extern.supportsInterface(badInterfaceId));
    }
}
