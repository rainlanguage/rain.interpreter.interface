// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {LibCtPop} from "rain.math.binary/lib/LibCtPop.sol";

/// @dev 4 = 1 byte opcode index + 3 byte fingerprint
uint256 constant META_ITEM_SIZE = 4;

/// @dev 1 = 1 byte for depth
uint256 constant META_PREFIX_SIZE = 1;

/// @dev 0xFFFFFF = 3 byte fingerprint
/// The fingerprint is 3 bytes because we're targetting the same collision
/// resistance on words as solidity functions. As we already use a fully byte to
/// map words across the expander, we only need 3 bytes for the fingerprint to
/// achieve 4 bytes of collision resistance, which is the same as a solidity
/// selector. This assumes that the byte selected to expand is uncorrelated with
/// the fingerprint bytes, which is a reasonable assumption as long as we use
/// different bytes from a keccak256 hash for each.
/// This assumes a single expander, if there are multiple expanders, then the
/// collision resistance only improves, so this is still safe.
uint256 constant FINGERPRINT_MASK = 0xFFFFFF;

/// @dev 33 = 32 bytes for expansion + 1 byte for seed
uint256 constant META_EXPANSION_SIZE = 0x21;

/// @title LibParseMeta
/// @notice Common logic for working with parse meta, which is the data structure
/// used to store information about the words in a parser. The parse meta is
/// designed to be compact and efficient to lookup.
library LibParseMeta {
    /// @dev Given a word and a seed, return the bitmap and fingerprint for the
    /// word. The bitmap is a uint256 with a single bit set, which can be used
    /// to check if the word is present in an expansion. The fingerprint is a
    /// uint256 with the low 3 bytes set, which can be used to check for
    /// collisions when a word is found in an expansion.
    /// @param seed The seed to use for the bitmap, which should be a byte value
    /// between 0 and 255.
    /// @param word The word to generate the bitmap and fingerprint for.
    /// @return bitmap A uint256 with a single bit set, which can be used to
    /// check if the word is present in an expansion.
    /// @return hashed A uint256 with the low 3 bytes set, which can be used to
    /// check for collisions when a word is found in an expansion.
    function wordBitmapped(uint256 seed, bytes32 word) internal pure returns (uint256 bitmap, uint256 hashed) {
        assembly ("memory-safe") {
            mstore(0, word)
            mstore8(0x20, seed)
            hashed := keccak256(0, 0x21)
            // We have to be careful here to avoid using the same byte for both
            // the expansion and the fingerprint. This is because we are relying
            // on the combined effect of both for collision resistance. We do
            // this by using the high byte of the hash for the bitmap, and the
            // low 3 bytes for the fingerprint.
            //slither-disable-next-line incorrect-shift
            bitmap := shl(byte(0, hashed), 1)
        }
    }

    /// Given the parse meta and a word, return the index and io fn pointer for
    /// the word. If the word is not found, then `exists` will be false. The
    /// caller MUST check `exists` before using the other return values.
    /// @param meta The parser meta.
    /// @param word The word to lookup.
    /// @return True if the word exists in the parse meta.
    /// @return The index of the word in the parse meta.
    function lookupWord(bytes memory meta, bytes32 word) internal pure returns (bool, uint256) {
        unchecked {
            uint256 dataStart;
            uint256 cursor;
            uint256 end;
            {
                uint256 metaExpansionSize = META_EXPANSION_SIZE;
                uint256 metaItemSize = META_ITEM_SIZE;
                assembly ("memory-safe") {
                    // Read depth from first meta byte.
                    cursor := add(meta, 1)
                    let depth := and(mload(cursor), 0xFF)
                    // 33 bytes per depth
                    end := add(cursor, mul(depth, metaExpansionSize))
                    dataStart := add(end, metaItemSize)
                }
            }

            uint256 cumulativeCt = 0;
            while (cursor < end) {
                uint256 expansion;
                uint256 posData;
                uint256 wordFingerprint;
                // Lookup the data at pos.
                {
                    uint256 seed;
                    assembly ("memory-safe") {
                        cursor := add(cursor, 1)
                        seed := and(mload(cursor), 0xFF)
                        cursor := add(cursor, 0x20)
                        expansion := mload(cursor)
                    }

                    (uint256 shifted, uint256 hashed) = wordBitmapped(seed, word);
                    uint256 pos = LibCtPop.ctpop(expansion & (shifted - 1)) + cumulativeCt;
                    wordFingerprint = hashed & FINGERPRINT_MASK;
                    uint256 metaItemSize = META_ITEM_SIZE;
                    assembly ("memory-safe") {
                        posData := mload(add(dataStart, mul(pos, metaItemSize)))
                    }
                }

                // Match
                if (wordFingerprint == posData & FINGERPRINT_MASK) {
                    uint256 index;
                    assembly ("memory-safe") {
                        index := byte(28, posData)
                    }
                    return (true, index);
                } else {
                    cumulativeCt += LibCtPop.ctpop(expansion);
                }
            }
            return (false, 0);
        }
    }
}
