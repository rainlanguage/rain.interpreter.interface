// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibEncodedDispatch} from "src/lib/deprecated/caller/LibEncodedDispatch.sol";
import {SourceIndexV2} from "src/interface/IInterpreterV3.sol";

contract LibEncodedDispatchTest is Test {
    function testRoundTrip(address expression, SourceIndexV2 sourceIndex, uint16 maxOutputs) public pure {
        sourceIndex = SourceIndexV2.wrap(bound(SourceIndexV2.unwrap(sourceIndex), 0, type(uint16).max));
        (address expressionDecoded, SourceIndexV2 sourceIndexDecoded, uint256 maxOutputsDecoded) =
            LibEncodedDispatch.decode2(LibEncodedDispatch.encode2(expression, sourceIndex, maxOutputs));
        assertEq(expression, expressionDecoded);
        assertEq(SourceIndexV2.unwrap(sourceIndex), SourceIndexV2.unwrap(sourceIndexDecoded));
        assertEq(maxOutputs, maxOutputsDecoded);
    }
}
