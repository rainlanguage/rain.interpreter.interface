// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity ^0.8.25;

import {AuthoringMetaV2} from "../../interface/IParserV2.sol";
import {
    META_ITEM_SIZE,
    FINGERPRINT_MASK,
    META_EXPANSION_SIZE,
    META_PREFIX_SIZE,
    LibParseMeta
} from "../parse/LibParseMeta.sol";
import {LibCtPop} from "rain.math.binary/lib/LibCtPop.sol";
import {Vm} from "forge-std/Vm.sol";
import {LibCodeGen} from "rain.sol.codegen/lib/LibCodeGen.sol";

uint256 constant META_ITEM_MASK = (1 << META_ITEM_SIZE) - 1;

/// @dev For metadata builder.
error DuplicateFingerprint();

library LibGenParseMeta {
    function findBestExpander(AuthoringMetaV2[] memory metas)
        internal
        pure
        returns (uint8 bestSeed, uint256 bestExpansion, AuthoringMetaV2[] memory remaining)
    {
        unchecked {
            {
                uint256 bestCt = 0;
                for (uint256 seed = 0; seed < type(uint8).max; seed++) {
                    uint256 expansion = 0;
                    for (uint256 i = 0; i < metas.length; i++) {
                        (uint256 shifted, uint256 hashed) = LibParseMeta.wordBitmapped(seed, metas[i].word);
                        (hashed);
                        expansion = shifted | expansion;
                    }
                    uint256 ct = LibCtPop.ctpop(expansion);
                    if (ct > bestCt) {
                        bestCt = ct;
                        bestSeed = uint8(seed);
                        bestExpansion = expansion;
                    }
                    // perfect expansion.
                    if (ct == metas.length) {
                        break;
                    }
                }

                uint256 remainingLength = metas.length - bestCt;
                assembly ("memory-safe") {
                    remaining := mload(0x40)
                    mstore(remaining, remainingLength)
                    mstore(0x40, add(remaining, mul(0x20, add(1, remainingLength))))
                }
            }
            uint256 usedExpansion = 0;
            uint256 j = 0;
            for (uint256 i = 0; i < metas.length; i++) {
                (uint256 shifted, uint256 hashed) = LibParseMeta.wordBitmapped(bestSeed, metas[i].word);
                (hashed);
                if ((shifted & usedExpansion) == 0) {
                    usedExpansion = shifted | usedExpansion;
                } else {
                    remaining[j] = metas[i];
                    j++;
                }
            }
        }
    }

    function buildParseMetaV2(AuthoringMetaV2[] memory authoringMeta, uint8 maxDepth)
        internal
        pure
        returns (bytes memory parseMeta)
    {
        unchecked {
            // Write out expansions.
            uint8[] memory seeds;
            uint256[] memory expansions;
            uint256 dataStart;
            {
                uint256 depth = 0;
                seeds = new uint8[](maxDepth);
                expansions = new uint256[](maxDepth);
                {
                    AuthoringMetaV2[] memory remainingAuthoringMeta = authoringMeta;
                    while (remainingAuthoringMeta.length > 0) {
                        uint8 seed;
                        uint256 expansion;
                        (seed, expansion, remainingAuthoringMeta) = findBestExpander(remainingAuthoringMeta);
                        seeds[depth] = seed;
                        expansions[depth] = expansion;
                        depth++;
                    }
                }

                uint256 parseMetaLength =
                    META_PREFIX_SIZE + depth * META_EXPANSION_SIZE + authoringMeta.length * META_ITEM_SIZE;
                parseMeta = new bytes(parseMetaLength);
                assembly ("memory-safe") {
                    mstore8(add(parseMeta, 0x20), depth)
                }
                for (uint256 j = 0; j < depth; j++) {
                    assembly ("memory-safe") {
                        // Write each seed immediately before its expansion.
                        let seedWriteAt := add(add(parseMeta, 0x21), mul(0x21, j))
                        mstore8(seedWriteAt, mload(add(seeds, add(0x20, mul(0x20, j)))))
                        mstore(add(seedWriteAt, 1), mload(add(expansions, add(0x20, mul(0x20, j)))))
                    }
                }

                {
                    uint256 dataOffset = META_PREFIX_SIZE + META_ITEM_SIZE + depth * META_EXPANSION_SIZE;
                    assembly ("memory-safe") {
                        dataStart := add(parseMeta, dataOffset)
                    }
                }
            }

            // Write words.
            for (uint256 k = 0; k < authoringMeta.length; k++) {
                uint256 s = 0;
                uint256 cumulativePos = 0;
                while (true) {
                    uint256 toWrite;
                    uint256 writeAt;

                    // Need some careful scoping here to avoid stack too deep.
                    {
                        uint256 expansion = expansions[s];

                        uint256 hashed;
                        {
                            uint256 shifted;
                            (shifted, hashed) = LibParseMeta.wordBitmapped(seeds[s], authoringMeta[k].word);

                            uint256 metaItemSize = META_ITEM_SIZE;
                            uint256 pos = LibCtPop.ctpop(expansion & (shifted - 1)) + cumulativePos;
                            assembly ("memory-safe") {
                                writeAt := add(dataStart, mul(pos, metaItemSize))
                            }
                        }

                        {
                            uint256 wordFingerprint = hashed & FINGERPRINT_MASK;
                            uint256 posFingerprint;
                            assembly ("memory-safe") {
                                posFingerprint := mload(writeAt)
                            }
                            posFingerprint &= FINGERPRINT_MASK;
                            if (posFingerprint != 0) {
                                if (posFingerprint == wordFingerprint) {
                                    revert DuplicateFingerprint();
                                }
                                // Collision, try next expansion.
                                s++;
                                cumulativePos = cumulativePos + LibCtPop.ctpop(expansion);
                                continue;
                            }
                            // Not collision, prepare the write with the
                            // fingerprint and index.
                            toWrite = wordFingerprint | (k << 0x18);
                        }
                    }

                    uint256 mask = ~META_ITEM_MASK;
                    assembly ("memory-safe") {
                        mstore(writeAt, or(and(mload(writeAt), mask), toWrite))
                    }
                    // We're done with this word.
                    break;
                }
            }
        }
    }

    function parseMetaConstantString(Vm vm, bytes memory authoringMetaBytes, uint8 buildDepth)
        internal
        pure
        returns (string memory)
    {
        AuthoringMetaV2[] memory authoringMeta = abi.decode(authoringMetaBytes, (AuthoringMetaV2[]));
        return string.concat(
            LibCodeGen.bytesConstantString(
                vm,
                string.concat(
                    "/// @dev The parse meta that is used to lookup word definitions.\n",
                    "/// The structure of the parse meta is:\n",
                    "/// - 1 byte: The depth of the bloom filters\n",
                    "/// - 1 byte: The hashing seed\n",
                    "/// - The bloom filters, each is 32 bytes long, one for each build depth.\n",
                    "/// - All the items for each word, each is 4 bytes long. Each item's first byte\n",
                    "///   is its opcode index, the remaining 3 bytes are the word fingerprint.\n",
                    "/// To do a lookup, the word is hashed with the seed, then the first byte of the\n",
                    "/// hash is compared against the bloom filter. If there is a hit then we count\n",
                    "/// the number of 1 bits in the bloom filter up to this item's 1 bit. We then\n",
                    "/// treat this a the index of the item in the items array. We then compare the\n",
                    "/// word fingerprint against the fingerprint of the item at this index. If the\n",
                    "/// fingerprints equal then we have a match, else we increment the seed and try\n",
                    "/// again with the next bloom filter, offsetting all the indexes by the total\n",
                    "/// bit count of the previous bloom filter. If we reach the end of the bloom\n",
                    "/// filters then we have a miss."
                ),
                "PARSE_META",
                LibGenParseMeta.buildParseMetaV2(authoringMeta, buildDepth)
            ),
            LibCodeGen.uint8ConstantString(
                vm, "/// @dev The build depth of the parser meta.\n", "PARSE_META_BUILD_DEPTH", buildDepth
            )
        );
    }
}
