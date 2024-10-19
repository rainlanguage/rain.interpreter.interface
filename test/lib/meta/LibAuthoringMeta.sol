// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity ^0.8.18;

import {AuthoringMetaV2} from "src/interface/IParserV2.sol";

library LibAuthoringMeta {
    function copyWordsFromAuthoringMeta(AuthoringMetaV2[] memory authoringMeta)
        internal
        pure
        returns (bytes32[] memory)
    {
        bytes32[] memory words = new bytes32[](authoringMeta.length);
        for (uint256 i = 0; i < authoringMeta.length; i++) {
            words[i] = authoringMeta[i].word;
        }
        return words;
    }
}
