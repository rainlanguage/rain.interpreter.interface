// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

struct PragmaV1 {
    address[] usingWordsFrom;
}

interface IParserPragmaV1 {
    function parsePragma1(bytes calldata data) external view returns (bytes calldata PragmaV1);
}
