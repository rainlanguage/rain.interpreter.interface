// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity =0.8.25;

import {Test, stdError} from "forge-std/Test.sol";
import {LibMemCpy} from "rain.solmem/lib/LibMemCpy.sol";
import {LibUint256Array} from "rain.solmem/lib/LibUint256Array.sol";
import {LibPointer, Pointer} from "rain.solmem/lib/LibPointer.sol";

import {IParserV1View} from "../../src/interface/deprecated/IParserV1View.sol";
import {IParserV2} from "../../src/interface/IParserV2.sol";

import {LibContext} from "../../src/lib/caller/LibContext.sol";
import {UnexpectedOperand} from "../../src/error/ErrParse.sol";
import {BadOpInputsLength, BadOpOutputsLength} from "../../src/error/ErrIntegrity.sol";
import {Operand, IInterpreterV3, SourceIndexV2, IInterpreterStoreV2} from "../../src/interface/IInterpreterV3.sol";
import {FullyQualifiedNamespace, StateNamespace} from "../../src/interface/IInterpreterStoreV2.sol";
import {SignedContextV1} from "../../src/interface/deprecated/IInterpreterCallerV2.sol";
import {LibEncodedDispatch} from "../../src/lib/deprecated/caller/LibEncodedDispatch.sol";
import {LibNamespace} from "../../src/lib/ns/LibNamespace.sol";

uint256 constant PRE = uint256(keccak256(abi.encodePacked("pre")));
uint256 constant POST = uint256(keccak256(abi.encodePacked("post")));

abstract contract OpTestV3 is Test {
    using LibUint256Array for uint256[];
    using LibPointer for Pointer;

    struct ReferenceCheckPointers {
        Pointer pre;
        Pointer post;
        Pointer stackTop;
        Pointer expectedStackTopAfter;
        // Initially this won't be populated. It will be populated by the
        // real function call.
        Pointer actualStackTopAfter;
    }

    //solhint-disable-next-line private-vars-leading-underscore
    IParserV2 internal immutable iDeployer;
    //solhint-disable-next-line private-vars-leading-underscore
    IInterpreterV3 internal immutable iInterpreter;
    //solhint-disable-next-line private-vars-leading-underscore
    IInterpreterStoreV2 internal immutable iStore;
    //solhint-disable-next-line private-vars-leading-underscore
    IParserV1View internal immutable iParser;

    function assumeEtchable(address account) internal view {
        assumeEtchable(account, address(0));
    }

    function assumeEtchable(address account, address expression) internal view {
        assumeNotPrecompile(account);
        vm.assume(account != address(iDeployer));
        vm.assume(account != address(iInterpreter));
        vm.assume(account != address(iStore));
        vm.assume(account != address(iParser));
        vm.assume(account != address(this));
        vm.assume(account != address(vm));
        vm.assume(account != address(expression));
        // The console.
        vm.assume(account != address(0x000000000000000000636F6e736F6c652e6c6f67));
    }

    function opReferenceCheckPointers(uint256[] memory inputs, uint256 calcOutputs)
        internal
        pure
        returns (ReferenceCheckPointers memory pointers)
    {
        {
            uint256 inputsLength = inputs.length;
            Pointer prePointer;
            Pointer postPointer;
            Pointer stackTop;
            Pointer expectedStackTopAfter;
            assembly ("memory-safe") {
                let headroom := 0x20
                if gt(calcOutputs, inputsLength) {
                    headroom := add(headroom, mul(sub(calcOutputs, inputsLength), 0x20))
                }
                postPointer := mload(0x40)
                stackTop := add(postPointer, headroom)
                // Copy the inputs to the stack.
                let readCursor := add(inputs, 0x20)
                let writeCursor := stackTop
                prePointer := add(stackTop, mul(inputsLength, 0x20))
                for {} lt(writeCursor, prePointer) {
                    writeCursor := add(writeCursor, 0x20)
                    readCursor := add(readCursor, 0x20)
                } { mstore(writeCursor, mload(readCursor)) }

                expectedStackTopAfter := sub(add(stackTop, mul(inputsLength, 0x20)), mul(calcOutputs, 0x20))
                mstore(0x40, add(prePointer, 0x20))
            }
            pointers.pre = prePointer;
            pointers.pre.unsafeWriteWord(PRE);
            pointers.post = postPointer;
            pointers.post.unsafeWriteWord(POST);
            pointers.stackTop = stackTop;
            pointers.expectedStackTopAfter = expectedStackTopAfter;
            LibMemCpy.unsafeCopyWordsTo(inputs.dataPointer(), pointers.stackTop, inputs.length);
        }
    }

    function parseAndEval(bytes memory rainString, uint256[][] memory context)
        internal
        view
        returns (uint256[] memory, uint256[] memory)
    {
        bytes memory bytecode = iDeployer.parse2(rainString);

        (uint256[] memory stack, uint256[] memory kvs) = iInterpreter.eval3(
            iStore,
            LibNamespace.qualifyNamespace(StateNamespace.wrap(0), address(this)),
            bytecode,
            SourceIndexV2.wrap(0),
            context,
            new uint256[](0)
        );
        return (stack, kvs);
    }

    /// 90%+ of the time we don't need to pass a context. This overloads a
    /// simplified interface to parse and eval.
    function parseAndEval(bytes memory rainString) internal view returns (uint256[] memory, uint256[] memory) {
        return parseAndEval(rainString, LibContext.build(new uint256[][](0), new SignedContextV1[](0)));
    }

    function checkHappy(bytes memory rainString, uint256 expectedValue, string memory errString) internal view {
        uint256[] memory expectedStack = new uint256[](1);
        expectedStack[0] = expectedValue;
        checkHappy(rainString, expectedStack, errString);
    }

    function checkHappy(bytes memory rainString, uint256[] memory expectedStack, string memory errString)
        internal
        view
    {
        checkHappy(rainString, LibContext.build(new uint256[][](0), new SignedContextV1[](0)), expectedStack, errString);
    }

    function checkHappy(
        bytes memory rainString,
        uint256[][] memory context,
        uint256[] memory expectedStack,
        string memory errString
    ) internal view {
        (uint256[] memory stack, uint256[] memory kvs) = parseAndEval(rainString, context);

        assertEq(stack.length, expectedStack.length, errString);
        for (uint256 i = 0; i < expectedStack.length; i++) {
            assertEq(stack[i], expectedStack[i], errString);
        }
        assertEq(kvs.length, 0);
    }

    function checkHappyKVs(bytes memory rainString, uint256[] memory expectedKVs, string memory errString)
        internal
        view
    {
        (uint256[] memory stack, uint256[] memory kvs) = parseAndEval(rainString);

        assertEq(stack.length, 0);
        assertEq(kvs.length, expectedKVs.length, errString);
        for (uint256 i = 0; i < expectedKVs.length; i++) {
            assertEq(kvs[i], expectedKVs[i], errString);
        }
    }

    function checkUnhappyOverflow(bytes memory rainString) internal {
        checkUnhappy(rainString, stdError.arithmeticError);
    }

    function checkUnhappy(bytes memory rainString, bytes memory err) internal {
        bytes memory bytecode = iDeployer.parse2(rainString);
        vm.expectRevert(err);
        (uint256[] memory stack, uint256[] memory kvs) = iInterpreter.eval3(
            iStore,
            FullyQualifiedNamespace.wrap(0),
            bytecode,
            SourceIndexV2.wrap(0),
            LibContext.build(new uint256[][](0), new SignedContextV1[](0)),
            new uint256[](0)
        );
        (stack, kvs);
    }

    function checkUnhappyParse2(bytes memory rainString, bytes memory err) internal {
        vm.expectRevert(err);
        bytes memory bytecode = iDeployer.parse2(rainString);
        (bytecode);
    }

    function checkUnhappyParse(bytes memory rainString, bytes memory err) internal {
        vm.expectRevert(err);
        (bytes memory bytecode, uint256[] memory constants) = iParser.parse(rainString);
        (bytecode);
        (constants);
    }

    function checkBadInputs(bytes memory rainString, uint256 opIndex, uint256 calcInputs, uint256 bytecodeInputs)
        internal
    {
        checkUnhappyParse2(
            rainString, abi.encodeWithSelector(BadOpInputsLength.selector, opIndex, calcInputs, bytecodeInputs)
        );
    }

    function checkBadOutputs(bytes memory rainString, uint256 opIndex, uint256 calcOutputs, uint256 bytecodeOutputs)
        internal
    {
        checkUnhappyParse2(
            rainString, abi.encodeWithSelector(BadOpOutputsLength.selector, opIndex, calcOutputs, bytecodeOutputs)
        );
    }

    function checkDisallowedOperand(bytes memory rainString) internal {
        vm.expectRevert(abi.encodeWithSelector(UnexpectedOperand.selector));
        (bytes memory bytecode, uint256[] memory constants) = iParser.parse(rainString);
        (bytecode);
        (constants);
    }
}
