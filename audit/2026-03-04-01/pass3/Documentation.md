<!-- SPDX-License-Identifier: LicenseRef-DCL-1.0 -->
<!-- SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd -->

# Pass 3: Documentation Review

**Agents:** A01-A12 (all source files)

---

## Findings

### P3-A02-1 — `NotAnExternContract` missing `@param` (LOW)

**File:** `src/error/ErrExtern.sol`, line 6

The `extern` address parameter has no `@param` tag. Every other error with parameters in the codebase has `@param` tags.

---

### P3-A04-1 — `EvaluableV4` `@param expression` does not match field name `bytecode` (LOW)

**File:** `src/interface/IInterpreterCallerV4.sol`, lines 22–28

NatSpec says `@param expression` but the struct field is `bytes bytecode`. Tooling cannot link the doc to the field.

---

### P3-A07-1 — `IInterpreterV4.sol` uses `pragma solidity ^0.8.25` violating interface convention (LOW)

**File:** `src/interface/IInterpreterV4.sol`, line 3

CLAUDE.md states interfaces use `^0.8.18`. All 5 other current interface files use `^0.8.18`. Only `IInterpreterV4.sol` uses `^0.8.25`, restricting downstream compatibility.

---

### P3-A07-2 — `IInterpreterV4` interface missing `@notice` tag (LOW)

**File:** `src/interface/IInterpreterV4.sol`, line 70

Has `@title` but the multi-line description uses plain `///` lines with no `@notice`. All other interfaces with descriptions include `@notice`.

---

### P3-A11-1 — `checkNoOOBPointers` missing `@param bytecode` tag (LOW)

**File:** `src/lib/bytecode/LibBytecode.sol`, lines 55–72

14-line descriptive block but no `@param bytecode` tag. Every other function in this file has `@param bytecode`.

---

### P3-A12-1 — `hash(SignedContextV1)` uses `@param hashed` for return value (LOW)

**File:** `src/lib/caller/LibContext.sol`, lines 74–76

`/// @param hashed The hashed signed context.` but `hashed` is the named return value. Should be `@return hashed`. The overload `hash(SignedContextV1[])` correctly uses `@return hashed`.

---

### P3-A05-1 — `EncodedExternDispatchV2` and `ExternDispatchV2` types lack natspec (INFO)

**File:** `src/interface/IInterpreterExternV4.sol`

---

### P3-A05-2 — `IInterpreterExternV4` interface missing `@notice` tag (INFO)

**File:** `src/interface/IInterpreterExternV4.sol`

---

### P3-A07-3 — Typo `prepoluated` should be `prepopulated` (INFO)

**File:** `src/interface/IInterpreterV4.sol`, line 77

---

### P3-A10-1 — `ISubParserV4` interface missing `@notice` tag (INFO)

**File:** `src/interface/ISubParserV4.sol`

---

## Summary Table

| ID | File | Severity | Title |
|----|------|----------|-------|
| P3-A02-1 | ErrExtern.sol | LOW | `NotAnExternContract` missing `@param` |
| P3-A04-1 | IInterpreterCallerV4.sol | LOW | `@param expression` does not match field name `bytecode` |
| P3-A07-1 | IInterpreterV4.sol | LOW | Pragma `^0.8.25` violates interface `^0.8.18` convention |
| P3-A07-2 | IInterpreterV4.sol | LOW | Interface missing `@notice` tag |
| P3-A11-1 | LibBytecode.sol | LOW | `checkNoOOBPointers` missing `@param bytecode` |
| P3-A12-1 | LibContext.sol | LOW | `@param hashed` should be `@return hashed` |
| P3-A05-1 | IInterpreterExternV4.sol | INFO | Types lack natspec |
| P3-A05-2 | IInterpreterExternV4.sol | INFO | Interface missing `@notice` |
| P3-A07-3 | IInterpreterV4.sol | INFO | Typo `prepoluated` |
| P3-A10-1 | ISubParserV4.sol | INFO | Interface missing `@notice` |
