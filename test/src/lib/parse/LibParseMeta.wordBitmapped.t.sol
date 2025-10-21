// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";

import {LibParseMeta} from "src/lib/parse/LibParseMeta.sol";

contract LitParseMetaTest is Test {
    function referenceWordBitmapped(uint256 seed, bytes32 word) public pure returns (uint256 bitmap, uint256 hashed) {
        // taking the low byte of the seed is intentional.
        //forge-lint: disable-next-line(unsafe-typecast)
        hashed = uint256(keccak256(abi.encodePacked(word, uint8(seed))));
        // Taking the type byte of hashed only.
        //forge-lint: disable-next-line(unsafe-typecast, incorrect-shift)
        bitmap = 1 << uint256(uint8(uint256(hashed) >> 0xF8));
    }

    function testWordBitmapped(uint256 seed, bytes32 word) public pure {
        (uint256 bitmap, uint256 hashed) = LibParseMeta.wordBitmapped(seed, word);
        (uint256 refBitmap, uint256 refHashed) = referenceWordBitmapped(seed, word);
        assertEq(bitmap, refBitmap, "bitmap");
        assertEq(hashed, refHashed, "hashed");
    }
}
