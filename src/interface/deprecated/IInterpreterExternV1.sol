// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.18;

type EncodedExternDispatch is uint256;

type ExternDispatch is uint256;

/// @title IInterpreterExternV1
/// Handle a single dispatch from some calling contract with an array of
/// inputs and array of outputs. Ostensibly useful to build "word packs" for
/// `IInterpreterV1` so that less frequently used words can be provided in
/// a less efficient format, but without bloating the base interpreter in
/// terms of code size. Effectively allows unlimited words to exist as externs
/// alongside interpreters.
interface IInterpreterExternV1 {
    /// Handles a single dispatch.
    /// @param dispatch Encoded information about the extern to dispatch.
    /// Analogous to the opcode/operand in the interpreter.
    /// @param inputs The array of inputs for the dispatched logic.
    /// @return outputs The result of the dispatched logic.
    function extern(ExternDispatch dispatch, uint256[] memory inputs)
        external
        view
        returns (uint256[] memory outputs);
}
