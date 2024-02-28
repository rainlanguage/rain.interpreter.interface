// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

interface IParserV2 {
    function parse2(bytes calldata data) external pure returns (bytes calldata bytecode);
}
