// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity ^0.8.25;

/// Thrown when parsing a source string and an operand opening `<` paren is found
/// somewhere that we don't expect it or can't handle it.
error UnexpectedOperand();

/// Thrown when parsing an operand and some required component of the operand is
/// not found in the source string.
error ExpectedOperand();

/// Thrown when there are more operand values in the operand than the handler
/// is expecting.
error UnexpectedOperandValue();
