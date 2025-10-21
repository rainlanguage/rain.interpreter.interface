// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// Export dispair interfaces for convenience downstream.
// Exported for convenience.
//forge-lint: disable-next-line(unused-import)
import {IInterpreterStoreV2} from "../../interface/IInterpreterStoreV2.sol";
// Exported for convenience.
//forge-lint: disable-next-line(unused-import)
import {IInterpreterV2} from "../../interface/deprecated/IInterpreterV2.sol";
import {EvaluableV2} from "../../interface/deprecated/IInterpreterCallerV2.sol";

import {EvaluableV3} from "../../interface/IInterpreterCallerV3.sol";

/// @title LibEvaluable
/// @notice Common logic to provide consistent implementations of common tasks
/// that could be arbitrarily/ambiguously implemented, but work much better if
/// consistently implemented.
library LibEvaluable {
    /// Hashes an `EvaluableV2`, ostensibly so that only the hash need be stored,
    /// thus only storing a single `uint256` instead of 3x `uint160`.
    /// @param evaluable The evaluable to hash.
    /// @return evaluableHash Standard hash of the evaluable.
    function hash(EvaluableV2 memory evaluable) internal pure returns (bytes32 evaluableHash) {
        // `Evaluable` does NOT contain any dynamic types so it is safe to encode
        // packed for hashing, and is preferable due to the smaller/simpler
        // in-memory structure. It also makes it easier to replicate the logic
        // offchain as a simple concatenation of bytes.
        assembly ("memory-safe") {
            evaluableHash := keccak256(evaluable, 0x60)
        }
    }

    /// Hashes an `EvaluableV3`, ostensibly so that only the hash need be stored,
    /// thus only storing a single `bytes32` instead of 2x `address` and an
    /// arbitrary length `bytes`.
    /// https://github.com/rainlanguage/rain.lib.hash?tab=readme-ov-file#the-pattern
    /// @param evaluable The evaluable to hash.
    /// @return evaluableHash Standard hash of the evaluable.
    function hash(EvaluableV3 memory evaluable) internal pure returns (bytes32) {
        bytes memory bytecode = evaluable.bytecode;
        bytes32 evaluableHash;
        assembly ("memory-safe") {
            // Hash first fields of evaluable.
            mstore(0, keccak256(evaluable, 0x40))
            // Hash bytecode.
            mstore(0x20, keccak256(add(bytecode, 0x20), mload(bytecode)))

            // Hash the two hashes.
            evaluableHash := keccak256(0, 0x40)
        }
        return evaluableHash;
    }
}
