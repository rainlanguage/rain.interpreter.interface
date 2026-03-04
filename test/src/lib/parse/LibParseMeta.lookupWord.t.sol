// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibParseMeta} from "src/lib/parse/LibParseMeta.sol";
import {LibGenParseMeta} from "src/lib/codegen/LibGenParseMeta.sol";
import {LibAuthoringMeta, AuthoringMetaV2} from "test/lib/meta/LibAuthoringMeta.sol";
import {LibBloom} from "test/lib/bloom/LibBloom.sol";
import {
    META_ITEM_SIZE,
    FINGERPRINT_MASK,
    META_EXPANSION_SIZE,
    META_PREFIX_SIZE,
    InvalidParseMeta
} from "src/lib/parse/LibParseMeta.sol";

contract LibParseMetaLookupWordTest is Test {
    function checkParseMetaStructureExternal(bytes memory meta) external pure {
        LibParseMeta.checkParseMetaStructure(meta);
    }

    /// buildParseMetaV2 output must always pass structural validation.
    function testCheckParseMetaStructureBuildOutput() external pure {
        AuthoringMetaV2[] memory metas = new AuthoringMetaV2[](3);
        metas[0] = AuthoringMetaV2({word: bytes32("add"), description: ""});
        metas[1] = AuthoringMetaV2({word: bytes32("sub"), description: ""});
        metas[2] = AuthoringMetaV2({word: bytes32("mul"), description: ""});
        bytes memory meta = LibGenParseMeta.buildParseMetaV2(metas, 8);
        LibParseMeta.checkParseMetaStructure(meta);
    }

    /// Fuzz: any well-formed buildParseMetaV2 output passes validation.
    function testCheckParseMetaStructureFuzz(AuthoringMetaV2[] memory authoringMeta) external pure {
        vm.assume(authoringMeta.length > 0);
        vm.assume(authoringMeta.length <= 64);
        vm.assume(!LibBloom.bloomFindsDupes(LibAuthoringMeta.copyWordsFromAuthoringMeta(authoringMeta)));
        uint8 depth = uint8(authoringMeta.length / type(uint8).max + 3);
        bytes memory meta = LibGenParseMeta.buildParseMetaV2(authoringMeta, depth);
        LibParseMeta.checkParseMetaStructure(meta);
    }

    /// Truncated meta should fail validation.
    function testCheckParseMetaStructureTruncated() external {
        AuthoringMetaV2[] memory metas = new AuthoringMetaV2[](1);
        metas[0] = AuthoringMetaV2({word: bytes32("add"), description: ""});
        bytes memory meta = LibGenParseMeta.buildParseMetaV2(metas, 8);

        // Truncate by 1 byte.
        bytes memory truncated = new bytes(meta.length - 1);
        for (uint256 i = 0; i < truncated.length; i++) {
            truncated[i] = meta[i];
        }
        vm.expectRevert(abi.encodeWithSelector(InvalidParseMeta.selector, meta.length, truncated.length));
        this.checkParseMetaStructureExternal(truncated);
    }

    /// Extra trailing bytes should fail validation.
    function testCheckParseMetaStructureExtraBytes() external {
        AuthoringMetaV2[] memory metas = new AuthoringMetaV2[](1);
        metas[0] = AuthoringMetaV2({word: bytes32("add"), description: ""});
        bytes memory meta = LibGenParseMeta.buildParseMetaV2(metas, 8);

        // Append 1 extra byte.
        bytes memory extended = new bytes(meta.length + 1);
        for (uint256 i = 0; i < meta.length; i++) {
            extended[i] = meta[i];
        }
        vm.expectRevert(abi.encodeWithSelector(InvalidParseMeta.selector, meta.length, extended.length));
        this.checkParseMetaStructureExternal(extended);
    }

    /// Empty meta (zero length) should fail validation.
    function testCheckParseMetaStructureEmpty() external {
        bytes memory meta = new bytes(0);
        // depth=0, 0 expansions, 0 items → expected length = 1.
        vm.expectRevert(abi.encodeWithSelector(InvalidParseMeta.selector, META_PREFIX_SIZE, 0));
        this.checkParseMetaStructureExternal(meta);
    }

    /// Demonstrates M01: lookupWord does not check whether the word's bit is
    /// actually set in the bloom filter expansion before comparing fingerprints.
    /// We construct raw meta bytes where:
    /// - The expansion has a single bit set (NOT the lookup word's bit)
    /// - The item at position 0 has a fingerprint matching the lookup word
    /// This should return (false, 0) but currently returns (true, fakeIndex)
    /// because the bit-set check is missing.
    function testLookupWordMissingBitCheck() external pure {
        bytes32 word = bytes32("notinmeta");
        uint8 seed = 0;

        // Compute word's bitmap and fingerprint, then build crafted meta.
        bytes memory meta = _buildM01Meta(word, seed);

        // lookupWord should return (false, 0) because the word's bit is NOT
        // set in the expansion. But due to M01, it returns (true, 42).
        (bool exists, uint256 index) = LibParseMeta.lookupWord(meta, word);
        assertFalse(exists, "M01: word bit not set in expansion, should not match");
        assertEq(index, 0, "M01: index should be 0 for not-found");
    }

    /// Fuzz variant of M01: any word should fail to match when its bit is not
    /// set in the expansion, regardless of fingerprint.
    function testLookupWordMissingBitCheckFuzz(bytes32 word, uint8 seed) external pure {
        bytes memory meta = _buildM01Meta(word, seed);

        (bool exists, uint256 index) = LibParseMeta.lookupWord(meta, word);
        assertFalse(exists, "M01 fuzz: word bit not set, should not match");
        assertEq(index, 0, "M01 fuzz: index should be 0 for not-found");
    }

    /// Constructs a crafted meta that triggers M01. The meta has one bloom
    /// layer with a single bit set that is NOT the lookup word's bit. The item
    /// at the position lookupWord will compute has a fingerprint matching the
    /// word. Without the bit-set check, lookupWord returns a false positive.
    function _buildM01Meta(bytes32 word, uint8 seed) internal pure returns (bytes memory meta) {
        (uint256 shifted, uint256 hashed) = LibParseMeta.wordBitmapped(seed, word);
        uint256 wordFingerprint = hashed & FINGERPRINT_MASK;

        // Find the word's bit position.
        uint256 bitPos;
        for (uint256 i = 0; i < 256; i++) {
            if (shifted == (1 << i)) {
                bitPos = i;
                break;
            }
        }

        // Pick a different bit ABOVE the word's bit so ctpop gives pos = 0.
        // Wrap around if needed — the key requirement is the bit differs.
        uint256 fakeBitPos = (bitPos + 128) % 256;
        uint256 fakeExpansion = 1 << fakeBitPos;

        // Determine what pos lookupWord will compute:
        // pos = ctpop(expansion & (shifted - 1))
        uint256 expectedPos = (fakeBitPos < bitPos) ? uint256(1) : uint256(0);

        uint256 numItems = expectedPos + 1;
        meta = new bytes(META_PREFIX_SIZE + META_EXPANSION_SIZE + numItems * META_ITEM_SIZE);

        // Write depth, seed, expansion.
        meta[0] = bytes1(uint8(1));
        meta[1] = bytes1(seed);
        for (uint256 i = 0; i < 32; i++) {
            meta[2 + i] = bytes1(uint8((fakeExpansion >> (8 * (31 - i))) & 0xFF));
        }

        // Write item at expectedPos with the word's fingerprint and a fake
        // opcode index of 42.
        uint256 itemOffset = META_PREFIX_SIZE + META_EXPANSION_SIZE + expectedPos * META_ITEM_SIZE;
        meta[itemOffset] = bytes1(uint8(42));
        meta[itemOffset + 1] = bytes1(uint8((wordFingerprint >> 16) & 0xFF));
        meta[itemOffset + 2] = bytes1(uint8((wordFingerprint >> 8) & 0xFF));
        meta[itemOffset + 3] = bytes1(uint8(wordFingerprint & 0xFF));
    }

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
