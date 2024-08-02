// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

// Reexport AuthoringMetaV2 for downstream use.
import {AuthoringMetaV2} from "./deprecated/IParserV1.sol";

interface IParserV2 {
    function parse2(bytes calldata data) external view returns (bytes calldata bytecode);
}
