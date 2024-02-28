// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

interface IAnalyzerV1 {
    function analyze(bytes calldata bytecode) external pure;
}
