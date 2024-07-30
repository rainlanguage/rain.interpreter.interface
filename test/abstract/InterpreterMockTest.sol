// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {Test, Vm} from "forge-std/Test.sol";
import {REVERTING_MOCK_BYTECODE} from "./TestConstants.sol";
import {IInterpreterStoreV2} from "src/interface/IInterpreterStoreV2.sol";
import {IInterpreterV2} from "src/interface/IInterpreterV2.sol";
import {IExpressionDeployerV3} from "src/interface/IExpressionDeployerV3.sol";

abstract contract InterpreterMockTest is Test {
    IInterpreterV2 internal immutable iInterpreter;
    IInterpreterStoreV2 internal immutable iStore;
    IExpressionDeployerV3 internal immutable iDeployer;

    constructor() {
        iInterpreter = IInterpreterV2(address(uint160(uint256(keccak256("interpreter.rain.test")))));
        vm.etch(address(iInterpreter), REVERTING_MOCK_BYTECODE);

        iStore = IInterpreterStoreV2(address(uint160(uint256(keccak256("store.rain.test")))));
        vm.etch(address(iStore), REVERTING_MOCK_BYTECODE);

        iDeployer = IExpressionDeployerV3(address(uint160(uint256(keccak256("deployer.rain.test")))));
        vm.etch(address(iDeployer), REVERTING_MOCK_BYTECODE);
    }

    function interpreterEval2MockCall(uint256[] memory stack, uint256[] memory writes) external {
        vm.mockCall(
            address(iInterpreter), abi.encodeWithSelector(IInterpreterV2.eval2.selector), abi.encode(stack, writes)
        );
    }

    function expressionDeployerDeployExpression2MockCall(address expression, bytes calldata io) external {
        vm.mockCall(
            address(iDeployer),
            abi.encodeWithSelector(IExpressionDeployerV3.deployExpression2.selector),
            abi.encode(iInterpreter, iStore, expression, io)
        );
    }
}
