<!-- SPDX-License-Identifier: LicenseRef-DCL-1.0 -->
<!-- SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd -->

# Pass 1 Security Review — Error Definition Files

**Date:** 2026-03-04
**Agents:** A01, A02, A03
**Scope:** `src/error/ErrBytecode.sol`, `src/error/ErrExtern.sol`, `src/error/ErrIntegrity.sol`

---

## A01 — `src/error/ErrBytecode.sol`

### Evidence of Thorough Reading

**File:** `src/error/ErrBytecode.sol`
**License:** LicenseRef-DCL-1.0 (REUSE compliant; SPDX header present at line 1)
**Copyright:** Copyright (c) 2020 Rain Open Source Software Ltd (line 2)
**Pragma:** `^0.8.25` (line 3)

**Errors defined (all are custom errors — no string reverts or require):**

| Line | Error Signature | Parameters |
|------|----------------|------------|
| 8 | `SourceIndexOutOfBounds(uint256 sourceIndex, bytes bytecode)` | out-of-bounds source index + full bytecode |
| 12 | `UnexpectedSources(bytes bytecode)` | full bytecode |
| 16 | `UnexpectedTrailingOffsetBytes(bytes bytecode)` | full bytecode |
| 21 | `TruncatedSource(bytes bytecode)` | full bytecode |
| 26 | `TruncatedHeader(bytes bytecode)` | full bytecode |
| 30 | `TruncatedHeaderOffsets(bytes bytecode)` | full bytecode |
| 36 | `StackSizingsNotMonotonic(bytes bytecode, uint256 relativeOffset)` | full bytecode + relative offset |

**Total:** 7 custom errors, 0 contract/library/function definitions, 0 assembly blocks, 0 state variables, 0 constants.

**Checks:**
- Custom errors only: YES — all 7 errors use the `error` keyword; no `revert("string")` or `require(cond, "string")` patterns exist in this file
- Assembly blocks: NONE
- Arithmetic: NONE
- Input validation logic: NONE (file is declarations only)
- Memory safety concerns: NONE (file is declarations only)

### Security Findings

No security findings.

One informational observation is recorded below.

### P1-A01-1 — Large `bytes` Parameters in Error Payloads (INFO)

**Classification:** INFO

**Location:** Lines 8, 12, 16, 21, 26, 30, 36

**Observation:**

Six of the seven custom errors carry a `bytes bytecode` parameter and one additionally carries `uint256 relativeOffset`. When these errors are thrown with large bytecode payloads the ABI-encoded revert data will be proportionally large. This is not a security vulnerability — it is the intended design so that callers receive diagnostic context — but callers and off-chain tooling should be aware that revert data can be arbitrarily sized.

There is no exploitable condition: the errors are purely for diagnostic purposes and contain no executable logic. No fix is required.

---

## A02 — `src/error/ErrExtern.sol`

### Evidence of Thorough Reading

**File:** `src/error/ErrExtern.sol`
**License:** LicenseRef-DCL-1.0 (REUSE compliant; SPDX header present at line 1)
**Copyright:** Copyright (c) 2020 Rain Open Source Software Ltd (line 2)
**Pragma:** `^0.8.25` (line 3)

**Errors defined (all are custom errors — no string reverts or require):**

| Line | Error Signature | Parameters |
|------|----------------|------------|
| 6 | `NotAnExternContract(address extern)` | address of non-conforming contract |
| 12 | `BadInputs(uint256 expected, uint256 actual)` | expected vs actual input count |

**Total:** 2 custom errors, 0 contract/library/function definitions, 0 assembly blocks, 0 state variables, 0 constants.

**Checks:**
- Custom errors only: YES — both errors use the `error` keyword; no `revert("string")` or `require(cond, "string")` patterns exist in this file
- Assembly blocks: NONE
- Arithmetic: NONE
- Input validation logic: NONE (file is declarations only)
- Memory safety concerns: NONE (file is declarations only)

### Security Findings

No security findings.

---

## A03 — `src/error/ErrIntegrity.sol`

### Evidence of Thorough Reading

**File:** `src/error/ErrIntegrity.sol`
**License:** LicenseRef-DCL-1.0 (REUSE compliant; SPDX header present at line 1)
**Copyright:** Copyright (c) 2020 Rain Open Source Software Ltd (line 2)
**Pragma:** `^0.8.25` (line 3)

**Errors defined (all are custom errors — no string reverts or require):**

| Line | Error Signature | Parameters |
|------|----------------|------------|
| 9 | `BadOpInputsLength(uint256 opIndex, uint256 calculatedInputs, uint256 bytecodeInputs)` | op index, integrity-calculated inputs, bytecode-declared inputs |
| 15 | `BadOpOutputsLength(uint256 opIndex, uint256 calculatedOutputs, uint256 bytecodeOutputs)` | op index, integrity-calculated outputs, bytecode-declared outputs |

**Total:** 2 custom errors, 0 contract/library/function definitions, 0 assembly blocks, 0 state variables, 0 constants.

**Checks:**
- Custom errors only: YES — both errors use the `error` keyword; no `revert("string")` or `require(cond, "string")` patterns exist in this file
- Assembly blocks: NONE
- Arithmetic: NONE
- Input validation logic: NONE (file is declarations only)
- Memory safety concerns: NONE (file is declarations only)

### Security Findings

No security findings.

---

## Summary

| Agent | File | Findings (CRITICAL/HIGH/MEDIUM/LOW) | INFO |
|-------|------|-------------------------------------|------|
| A01 | `src/error/ErrBytecode.sol` | 0 | 1 |
| A02 | `src/error/ErrExtern.sol` | 0 | 0 |
| A03 | `src/error/ErrIntegrity.sol` | 0 | 0 |

All three files are pure error-declaration files. They contain no executable logic, no assembly, no arithmetic, and no string-based reverts. The codebase correctly uses custom errors throughout, consistent with the project's stated requirement. No LOW or higher findings were identified; no `.fixes/` files were generated for this review.
