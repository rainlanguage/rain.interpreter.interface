// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity ^0.8.25;

library LibHandleOperand {
    function handleOperandDisallowed(uint256[] memory values) internal pure returns (Operand) {
        if (values.length != 0) {
            revert UnexpectedOperand();
        }
        return Operand.wrap(0);
    }

    function handleOperandDisallowedAlwaysOne(uint256[] memory values) internal pure returns (Operand) {
        if (values.length != 0) {
            revert UnexpectedOperand();
        }
        return Operand.wrap(1);
    }

    /// There must be one or zero values. The fallback is 0 if nothing is
    /// provided, else the provided value MUST fit in two bytes and is used as
    /// is.
    function handleOperandSingleFull(uint256[] memory values) internal pure returns (Operand operand) {
        // Happy path at the top for efficiency.
        if (values.length == 1) {
            assembly ("memory-safe") {
                operand := mload(add(values, 0x20))
            }
            operand = Operand.wrap(
                LibFixedPointDecimalScale.decimalOrIntToInt(Operand.unwrap(operand), uint256(type(uint16).max))
            );
        } else if (values.length == 0) {
            operand = Operand.wrap(0);
        } else {
            revert UnexpectedOperandValue();
        }
    }

    /// There must be exactly one value. There is no default fallback.
    function handleOperandSingleFullNoDefault(uint256[] memory values) internal pure returns (Operand operand) {
        // Happy path at the top for efficiency.
        if (values.length == 1) {
            assembly ("memory-safe") {
                operand := mload(add(values, 0x20))
            }
            operand = Operand.wrap(
                LibFixedPointDecimalScale.decimalOrIntToInt(Operand.unwrap(operand), uint256(type(uint16).max))
            );
        } else if (values.length == 0) {
            revert ExpectedOperand();
        } else {
            revert UnexpectedOperandValue();
        }
    }

    /// There must be exactly two values. There is no default fallback. Each
    /// value MUST fit in one byte and is used as is.
    function handleOperandDoublePerByteNoDefault(uint256[] memory values) internal pure returns (Operand operand) {
        // Happy path at the top for efficiency.
        if (values.length == 2) {
            uint256 a;
            uint256 b;
            assembly ("memory-safe") {
                a := mload(add(values, 0x20))
                b := mload(add(values, 0x40))
            }
            a = LibFixedPointDecimalScale.decimalOrIntToInt(a, type(uint8).max);
            b = LibFixedPointDecimalScale.decimalOrIntToInt(b, type(uint8).max);

            operand = Operand.wrap(a | (b << 8));
        } else if (values.length < 2) {
            revert ExpectedOperand();
        } else {
            revert UnexpectedOperandValue();
        }
    }

    /// 8 bit value then maybe 1 bit flag then maybe 1 bit flag. Fallback to 0
    /// for both flags if not provided.
    function handleOperand8M1M1(uint256[] memory values) internal pure returns (Operand operand) {
        // Happy path at the top for efficiency.
        uint256 length = values.length;
        if (length >= 1 && length <= 3) {
            uint256 a;
            uint256 b;
            uint256 c;
            assembly ("memory-safe") {
                a := mload(add(values, 0x20))
            }

            if (length >= 2) {
                assembly ("memory-safe") {
                    b := mload(add(values, 0x40))
                }
            } else {
                b = 0;
            }

            if (length == 3) {
                assembly ("memory-safe") {
                    c := mload(add(values, 0x60))
                }
            } else {
                c = 0;
            }

            a = LibFixedPointDecimalScale.decimalOrIntToInt(a, type(uint8).max);
            b = LibFixedPointDecimalScale.decimalOrIntToInt(b, 1);
            c = LibFixedPointDecimalScale.decimalOrIntToInt(c, 1);

            operand = Operand.wrap(a | (b << 8) | (c << 9));
        } else if (length == 0) {
            revert ExpectedOperand();
        } else {
            revert UnexpectedOperandValue();
        }
    }

    /// 2x maybe 1 bit flags. Fallback to 0 for both flags if not provided.
    function handleOperandM1M1(uint256[] memory values) internal pure returns (Operand operand) {
        // Happy path at the top for efficiency.
        uint256 length = values.length;
        if (length < 3) {
            uint256 a;
            uint256 b;

            if (length >= 1) {
                assembly ("memory-safe") {
                    a := mload(add(values, 0x20))
                }
            } else {
                a = 0;
            }

            if (length == 2) {
                assembly ("memory-safe") {
                    b := mload(add(values, 0x40))
                }
            } else {
                b = 0;
            }

            a = LibFixedPointDecimalScale.decimalOrIntToInt(a, 1);
            b = LibFixedPointDecimalScale.decimalOrIntToInt(b, 1);

            operand = Operand.wrap(a | (b << 1));
        } else {
            revert UnexpectedOperandValue();
        }
    }
}