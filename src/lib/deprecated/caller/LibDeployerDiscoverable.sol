// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {IExpressionDeployerV4} from "../../../interface/deprecated/IExpressionDeployerV4.sol";
import {IInterpreterStoreV2} from "../../../interface/IInterpreterStoreV2.sol";
import {IInterpreterV2} from "../../../interface/deprecated/IInterpreterV2.sol";

library LibDeployerDiscoverable {
    /// Hack so that some deployer will emit an event with the sender as the
    /// caller of `touchDeployer`. This MAY be needed by indexers such as
    /// subgraph that can only index events from the first moment they are aware
    /// of some contract. The deployer MUST be registered in ERC1820 registry
    /// before it is touched, THEN the caller meta MUST be emitted after the
    /// deployer is touched. This allows indexers such as subgraph to index the
    /// deployer, then see the caller, then see the caller's meta emitted in the
    /// same transaction.
    /// This is NOT required if ANY other expression is deployed in the same
    /// transaction as the caller meta, there only needs to be one expression on
    /// ANY deployer known to ERC1820.
    function touchDeployerV4(address deployer) internal {
        (IInterpreterV2 interpreter, IInterpreterStoreV2 store, address expression, bytes memory io) =
            IExpressionDeployerV4(deployer).deployExpression2("", new uint256[](0));
        (interpreter, store, expression, io);
    }
}
