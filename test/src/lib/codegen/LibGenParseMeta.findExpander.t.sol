//// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";

import {LibBloom} from "test/lib/bloom/LibBloom.sol";
import {LibCtPop} from "rain.math.binary/lib/LibCtPop.sol";
import {LibAuthoringMeta, AuthoringMetaV2} from "test/lib/meta/LibAuthoringMeta.sol";
import {LibGenParseMeta} from "src/lib/codegen/LibGenParseMeta.sol";

/// @title LibGenParseMetaFindExpanderTest
/// Test that we can find reasonable expansions in a reasonable number of
/// iterations for a reasonable number of words.
contract LibGenParseMetaFindExpanderTest is Test {
    /// Test that we can find an expansion for a small number of words in a
    /// single iteration.
    /// Birthday paradox says we should expect to find a collision in 256 slots
    /// and 32 words 86.76% of the time.
    /// https://www.wolframalpha.com/input?i=birthday+problem+calculator&assumption=%7B%22F%22%2C+%22BirthdayProblem%22%2C+%22pbds%22%7D+-%3E%22256%22&assumption=%7B%22F%22%2C+%22BirthdayProblem%22%2C+%22n%22%7D+-%3E%2232%22&assumption=%22FSelect%22+-%3E+%7B%7B%22BirthdayProblem%22%7D%7D
    /// The probability of finding a collision in EVERY iteration is 0.8676^256
    /// which is 1.621075e-16. I.e. we shoud expect the fuzz test to basically
    /// never fail for ~1000 runs.
    function testFindExpanderSmall(AuthoringMetaV2[] memory authoringMeta) external pure {
        vm.assume(authoringMeta.length <= 0x20);
        vm.assume(!LibBloom.bloomFindsDupes(LibAuthoringMeta.copyWordsFromAuthoringMeta(authoringMeta)));

        (uint8 seed, uint256 expansion, AuthoringMetaV2[] memory remaining) =
            LibGenParseMeta.findBestExpander(authoringMeta);
        (seed);
        assertEq(LibCtPop.ctpop(expansion), authoringMeta.length);
        assertEq(remaining.length, 0);
    }
}
