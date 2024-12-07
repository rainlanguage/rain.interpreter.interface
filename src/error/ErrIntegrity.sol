// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// The bytecode and integrity function disagree on number of inputs.
/// @param opIndex The index of the operation in question.
/// @param calculatedInputs The number of inputs calculated by the integrity function.
/// @param bytecodeInputs The number of inputs in the bytecode.
error BadOpInputsLength(uint256 opIndex, uint256 calculatedInputs, uint256 bytecodeInputs);

/// The bytecode and integrity function disagree on number of outputs.
/// @param opIndex The index of the operation in question.
/// @param calculatedOutputs The number of outputs calculated by the integrity function.
/// @param bytecodeOutputs The number of outputs in the bytecode.
error BadOpOutputsLength(uint256 opIndex, uint256 calculatedOutputs, uint256 bytecodeOutputs);
