// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibParseMeta} from "src/lib/parse/LibParseMeta.sol";
import {LibGenParseMeta} from "src/lib/codegen/LibGenParseMeta.sol";
import {LibAuthoringMeta, AuthoringMetaV2} from "test/lib/meta/LibAuthoringMeta.sol";
import {LibBloom} from "test/lib/bloom/LibBloom.sol";

contract LibParseMetaLookupWordTest is Test {
    /// Build meta from known words, look them all up, verify indices.
    function testLookupWordKnown() external pure {
        AuthoringMetaV2[] memory metas = new AuthoringMetaV2[](3);
        metas[0] = AuthoringMetaV2({word: bytes32("add"), description: ""});
        metas[1] = AuthoringMetaV2({word: bytes32("sub"), description: ""});
        metas[2] = AuthoringMetaV2({word: bytes32("mul"), description: ""});

        bytes memory meta = LibGenParseMeta.buildParseMetaV2(metas, 8);

        for (uint256 i = 0; i < metas.length; i++) {
            (bool exists, uint256 index) = LibParseMeta.lookupWord(meta, metas[i].word);
            assertTrue(exists, "word should exist");
            assertEq(index, i, "word index mismatch");
        }
    }

    /// Looking up a word not in meta should return false with index 0.
    function testLookupWordNotFound() external pure {
        AuthoringMetaV2[] memory metas = new AuthoringMetaV2[](1);
        metas[0] = AuthoringMetaV2({word: bytes32("add"), description: ""});

        bytes memory meta = LibGenParseMeta.buildParseMetaV2(metas, 8);

        (bool exists, uint256 index) = LibParseMeta.lookupWord(meta, bytes32("notaword"));
        assertFalse(exists);
        assertEq(index, 0);
    }

    /// Single-depth meta with a single word.
    function testLookupWordSingleDepth() external pure {
        AuthoringMetaV2[] memory metas = new AuthoringMetaV2[](1);
        metas[0] = AuthoringMetaV2({word: bytes32("only"), description: ""});

        bytes memory meta = LibGenParseMeta.buildParseMetaV2(metas, 1);

        (bool exists, uint256 index) = LibParseMeta.lookupWord(meta, bytes32("only"));
        assertTrue(exists);
        assertEq(index, 0);

        // Not-found on single-depth meta.
        (bool notExists,) = LibParseMeta.lookupWord(meta, bytes32("other"));
        assertFalse(notExists);
    }

    /// Multiple not-found lookups should all return false.
    function testLookupWordMultipleNotFound(bytes32 a, bytes32 b, bytes32 c) external pure {
        AuthoringMetaV2[] memory metas = new AuthoringMetaV2[](1);
        metas[0] = AuthoringMetaV2({word: bytes32("known"), description: ""});

        // Ensure fuzzed words differ from the known word.
        vm.assume(a != bytes32("known"));
        vm.assume(b != bytes32("known"));
        vm.assume(c != bytes32("known"));

        bytes memory meta = LibGenParseMeta.buildParseMetaV2(metas, 3);

        (bool existsA,) = LibParseMeta.lookupWord(meta, a);
        assertFalse(existsA);
        (bool existsB,) = LibParseMeta.lookupWord(meta, b);
        assertFalse(existsB);
        (bool existsC,) = LibParseMeta.lookupWord(meta, c);
        assertFalse(existsC);
    }

    /// Fuzz: every word in the authoring meta should be found at its correct
    /// index, and a random word not in the meta should not be found.
    function testLookupWordRoundtripFuzz(AuthoringMetaV2[] memory authoringMeta, bytes32 notFound) external pure {
        vm.assume(authoringMeta.length > 0);
        vm.assume(authoringMeta.length <= 64);
        vm.assume(!LibBloom.bloomFindsDupes(LibAuthoringMeta.copyWordsFromAuthoringMeta(authoringMeta)));
        for (uint256 i = 0; i < authoringMeta.length; i++) {
            vm.assume(authoringMeta[i].word != notFound);
        }

        uint8 depth = uint8(authoringMeta.length / type(uint8).max + 3);
        bytes memory meta = LibGenParseMeta.buildParseMetaV2(authoringMeta, depth);

        // Every word should be found at its index.
        for (uint256 i = 0; i < authoringMeta.length; i++) {
            (bool exists, uint256 index) = LibParseMeta.lookupWord(meta, authoringMeta[i].word);
            assertTrue(exists, "word should exist");
            assertEq(index, i, "index mismatch");
        }

        // A word not in meta should not be found.
        (bool notExists,) = LibParseMeta.lookupWord(meta, notFound);
        assertFalse(notExists, "unknown word should not exist");
    }

    /// Larger word set forcing multi-depth bloom — verify all words still
    /// resolve correctly.
    function testLookupWordLargeSet() external pure {
        uint256 count = 50;
        AuthoringMetaV2[] memory metas = new AuthoringMetaV2[](count);
        for (uint256 i = 0; i < count; i++) {
            metas[i] = AuthoringMetaV2({word: bytes32(i + 1), description: ""});
        }

        bytes memory meta = LibGenParseMeta.buildParseMetaV2(metas, 5);

        for (uint256 i = 0; i < count; i++) {
            (bool exists, uint256 index) = LibParseMeta.lookupWord(meta, bytes32(i + 1));
            assertTrue(exists, "word should exist");
            assertEq(index, i, "index mismatch");
        }

        // Zero was not added.
        (bool notExists,) = LibParseMeta.lookupWord(meta, bytes32(uint256(0)));
        assertFalse(notExists);
    }
}
