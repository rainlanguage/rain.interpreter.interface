// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {
    IInterpreterStoreV2,
    FullyQualifiedNamespace,
    StateNamespace,
    SourceIndexV2,
    DEFAULT_STATE_NAMESPACE,
    Operand
} from "./deprecated/IInterpreterV2.sol";

interface IInterpreterV3 {
    function functionPointers() external view returns (bytes calldata);

    function eval3(
        IInterpreterStoreV2 store,
        FullyQualifiedNamespace namespace,
        bytes calldata bytecode,
        SourceIndexV2 sourceIndex,
        uint256[][] calldata context,
        uint256[] calldata inputs
    ) external view returns (uint256[] calldata stack, uint256[] calldata writes);
}
