// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

interface IParserV2 {
    function parse2(bytes calldata data) external view returns (bytes calldata bytecode);
}
