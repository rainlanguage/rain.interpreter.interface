// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.18;

import {IInterpreterStoreV1} from "./IInterpreterStoreV1.sol";
import {IInterpreterV1} from "./IInterpreterV1.sol";

string constant IERC1820_NAME_IEXPRESSION_DEPLOYER_V2 = "IExpressionDeployerV2";

/// @title IExpressionDeployerV2
/// @notice Companion to `IInterpreterV1` responsible for onchain static code
/// analysis and deploying expressions. Each `IExpressionDeployerV2` is tightly
/// coupled at the bytecode level to some interpreter that it knows how to
/// analyse and deploy expressions for. The expression deployer can perform an
/// integrity check "dry run" of candidate source code for the intepreter. The
/// critical analysis/transformation includes:
///
/// - Enforcement of no out of bounds memory reads/writes
/// - Calculation of memory required to eval the stack with a single allocation
/// - Replacing index based opcodes with absolute interpreter function pointers
/// - Enforcement that all opcodes and operands used exist and are valid
///
/// This analysis is highly sensitive to the specific implementation and position
/// of all opcodes and function pointers as compiled into the interpreter. This
/// is what makes the coupling between an interpreter and expression deployer
/// so tight. Ideally all responsibilities would be handled by a single contract
/// but this introduces code size issues quickly by roughly doubling the compiled
/// logic of each opcode (half for the integrity check and half for evaluation).
///
/// Interpreters MUST assume that expression deployers are malicious and fail
/// gracefully if the integrity check is corrupt/bypassed and/or function
/// pointers are incorrect, etc. i.e. the interpreter MUST always return a stack
/// from `eval` in a read only way or error. I.e. it is the expression deployer's
/// responsibility to do everything it can to prevent undefined behaviour in the
/// interpreter, and the interpreter's responsibility to handle the expression
/// deployer completely failing to do so.
interface IExpressionDeployerV2 {
    /// This is the literal InterpreterOpMeta bytes to be used offchain to make
    /// sense of the opcodes in this interpreter deployment, as a human. For
    /// formats like json that make heavy use of boilerplate, repetition and
    /// whitespace, some kind of compression is recommended.
    /// @param sender The `msg.sender` providing the op meta.
    /// @param meta The raw binary data of the construction meta. Maybe
    /// compressed data etc. and is intended for offchain consumption.
    event DISpair(address sender, address deployer, address interpreter, address store, bytes meta);

    /// Expressions are expected to be deployed onchain as immutable contract
    /// code with a first class address like any other contract or account.
    /// Technically this is optional in the sense that all the tools required to
    /// eval some expression and define all its opcodes are available as
    /// libraries.
    ///
    /// In practise there are enough advantages to deploying the sources directly
    /// onchain as contract data and loading them from the interpreter at eval:
    ///
    /// - Loading and storing binary data is gas efficient as immutable contract
    ///   data
    /// - Expressions need to be immutable between their deploy time integrity
    ///   check and runtime evaluation
    /// - Passing the address of an expression through calldata to an interpreter
    ///   is cheaper than passing an entire expression through calldata
    /// - Conceptually a very simple approach, even if implementations like
    ///   SSTORE2 are subtle under the hood
    ///
    /// The expression deployer MUST perform an integrity check of the source
    /// code before it puts the expression onchain at a known address. The
    /// integrity check MUST at a minimum (it is free to do additional static
    /// analysis) calculate the memory required to be allocated for the stack in
    /// total, and that no out of bounds memory reads/writes occur within this
    /// stack. A simple example of an invalid source would be one that pushes one
    /// value to the stack then attempts to pops two values, clearly we cannot
    /// remove more values than we added. The `IExpressionDeployerV2` MUST revert
    /// in the case of any integrity failure, all integrity checks MUST pass in
    /// order for the deployment to complete.
    ///
    /// Once the integrity check is complete the `IExpressionDeployerV2` MUST do
    /// any additional processing required by its paired interpreter.
    /// For example, the `IExpressionDeployerV2` MAY NEED to replace the indexed
    /// opcodes in the `ExpressionConfig` sources with real function pointers
    /// from the corresponding interpreter.
    ///
    /// @param bytecode Bytecode verbatim. Exactly how the bytecode is structured
    /// is up to the deployer and interpreter. The deployer MUST NOT modify the
    /// bytecode in any way. The interpreter MUST NOT assume anything about the
    /// bytecode other than that it is valid according to the interpreter's
    /// integrity checks. It is assumed that the bytecode will be produced from
    /// a human friendly string via. `IParserV1.parse` but this is not required
    /// if the caller has some other means to prooduce valid bytecode.
    /// @param constants Constants verbatim. Constants are provided alongside
    /// sources rather than inline as it allows us to avoid variable length
    /// opcodes and can be more memory efficient if the same constant is
    /// referenced several times from the sources.
    /// @param minOutputs The first N sources on the state config are entrypoints
    /// to the expression where N is the length of the `minOutputs` array. Each
    /// item in the `minOutputs` array specifies the number of outputs that MUST
    /// be present on the final stack for an evaluation of each entrypoint. The
    /// minimum output for some entrypoint MAY be zero if the expectation is that
    /// the expression only applies checks and error logic. Non-entrypoint
    /// sources MUST NOT have a minimum outputs length specified.
    /// @return interpreter The interpreter the deployer believes it is qualified
    /// to perform integrity checks on behalf of.
    /// @return store The interpreter store the deployer believes is compatible
    /// with the interpreter.
    /// @return expression The address of the deployed onchain expression. MUST
    /// be valid according to all integrity checks the deployer is aware of.
    function deployExpression(bytes calldata bytecode, uint256[] calldata constants, uint256[] calldata minOutputs)
        external
        returns (IInterpreterV1 interpreter, IInterpreterStoreV1 store, address expression);
}
