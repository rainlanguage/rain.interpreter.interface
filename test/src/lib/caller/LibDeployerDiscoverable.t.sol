// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {IExpressionDeployerV4} from "src/interface/deprecated/IExpressionDeployerV4.sol";
import {LibDeployerDiscoverable} from "src/lib/deprecated/caller/LibDeployerDiscoverable.sol";
import {IInterpreterV2} from "src/interface/deprecated/IInterpreterV2.sol";
import {IInterpreterStoreV2} from "src/interface/IInterpreterStoreV2.sol";

contract TestDeployerV4 is IExpressionDeployerV4 {
    function deployExpression2(bytes memory, uint256[] memory)
        external
        returns (IInterpreterV2, IInterpreterStoreV2, address, bytes memory)
    {}
}

contract LibDeployerDiscoverableTest is Test {
    /// MUST be possible to touch a deployer with 0 data to support discovery.
    function testTouchDeployerV4Mock() external {
        TestDeployerV4 deployer = new TestDeployerV4();
        vm.expectCall(
            address(deployer),
            abi.encodeWithSelector(IExpressionDeployerV4.deployExpression2.selector, "", new uint256[](0)),
            1
        );
        LibDeployerDiscoverable.touchDeployerV4(address(deployer));
    }
}
