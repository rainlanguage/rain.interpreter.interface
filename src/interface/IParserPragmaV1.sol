// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.18;

struct PragmaV1 {
    address[] usingWordsFrom;
}

interface IParserPragmaV1 {
    function parsePragma1(bytes calldata data) external view returns (PragmaV1 calldata);
}
