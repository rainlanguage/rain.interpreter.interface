// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import "forge-std/Test.sol";
import "src/lib/caller/LibContext.sol";
import "./LibContextSlow.sol";

contract LibContextTest is Test {
    function testBase() public view {
        bytes32[] memory baseContext = LibContext.base();

        assertEq(baseContext.length, 2);
        assertEq(baseContext[0], bytes32(bytes20(msg.sender)));
        assertEq(baseContext[1], bytes32(bytes20(address(this))));
        assertTrue(msg.sender != address(this));
    }

    /// forge-config: default.fuzz.runs = 100
    function testBuildStructureReferenceImplementation(bytes32[][] memory base) public view {
        // @todo support signed context testing, currently fails due to invalid
        // signatures blocking the build process.
        SignedContextV1[] memory signedContexts = new SignedContextV1[](0);

        bytes32[][] memory expected = LibContextSlow.buildStructureSlow(base, signedContexts);
        bytes32[][] memory actual = LibContext.build(base, signedContexts);
        assertEq(expected.length, actual.length);

        for (uint256 i = 0; i < expected.length; i++) {
            assertEq(expected[i], actual[i]);
        }
    }

    function testBuild0() public view {
        // @todo test this better.
        bytes32[][] memory expected = new bytes32[][](1);
        expected[0] = LibContext.base();
        bytes32[][] memory built = LibContext.build(new bytes32[][](0), new SignedContextV1[](0));
        assertEq(expected.length, built.length);

        for (uint256 i = 0; i < expected.length; i++) {
            assertEq(expected[i], built[i]);
        }
    }

    function testBuildGas0() public view {
        LibContext.build(new bytes32[][](0), new SignedContextV1[](0));
    }
}
