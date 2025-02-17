// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {
    FullyQualifiedNamespace,
    StateNamespace,
    SourceIndexV2,
    DEFAULT_STATE_NAMESPACE,
    OPCODE_CONSTANT,
    OPCODE_CONTEXT,
    OPCODE_EXTERN,
    OPCODE_UNKNOWN,
    OPCODE_STACK
} from "../IInterpreterV3.sol";
import {IInterpreterStoreV3} from "./IInterpreterStoreV3.sol";

type OperandV2 is bytes32;

type StackItem is bytes32;

struct EvalV4 {
    IInterpreterStoreV3 store;
    FullyQualifiedNamespace namespace;
    bytes bytecode;
    SourceIndexV2 sourceIndex;
    bytes32[][] context;
    StackItem[] inputs;
    bytes32[] stateOverlay;
}

/// @title IInterpreterV4
/// Interface into a standard interpreter that supports:
///
/// - evaluating Rainlang logic provided as rain bytecode in calldata
/// - receiving arbitrary `bytes32[][]` supporting context to be made available
///   to the evaluated logic via. context aware opcodes
/// - receiving arbitrary `bytes32[]` inputs to be made available to the
///   evaluated logic as prepoluated stack items
/// - receiving arbitrary `bytes32[]` stateOverlay to be applied to the
///   state before evaluation to facilitate "what if" analysis
/// - handling subsequent state changes in bulk in response to evaluated logic
/// - namespacing state changes according to the caller's preferences to avoid
///   unwanted key collisions
///
/// The interface is designed to be stable across many versions and
/// implementations of an interpreter, balancing minimalism with features
/// required for a general purpose onchain interpreted compute environment.
///
/// The security model of an interpreter is that it MUST be resilient to
/// malicious expressions even if they dispatch arbitrary internal function
/// pointers during an eval. The interpreter MAY return garbage or exhibit
/// undefined behaviour or error during an eval, _provided that no state changes
/// are persisted_ e.g. in storage, such that only the caller that specifies the
/// malicious expression can be negatively impacted by the result. In turn, the
/// caller must guard itself against arbitrarily corrupt/malicious reverts and
/// return values from any interpreter that it requests an expression from. And
/// so on and so forth up to the externally owned account (EOA) who signs the
/// transaction and agrees to a specific combination of contracts, expressions
/// and interpreters, who can presumably make an informed decision about which
/// to trust.
///
/// The state of an interpreter is expected to be stored in a store that is
/// passed in as a parameter to the eval function. `eval4` will return the
/// writes that are to be applied to the store after the evaluation is complete.
/// The caller is responsible for applying these writes to the store, and is
/// expected to pass them as-is.
interface IInterpreterV4 {
    /// Rainlang magic happens here.
    ///
    /// Pass Rainlang bytecode in calldata, and get back the stack and storage
    /// writes.
    ///
    /// Key differences in `eval4`:
    /// - Supports state overlays to facilitate "what if" analysis. Each item
    ///   of state in the overlay will override corresponding gets from the store
    ///   unless/until they are set to something else in the evaluated logic.
    /// - Numbers are treated as packed Rain decimal floats, NOT fixed point
    ///   decimals.
    function eval4(EvalV4 calldata eval)
        external
        view
        returns (StackItem[] calldata stack, bytes32[] calldata writes);
}
