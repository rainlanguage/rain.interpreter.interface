# Pass 1: Security Review — Interface Files
# Audit 2026-03-04-01

Agents: A04–A10
Scope: `src/interface/IInterpreterCallerV4.sol`, `IInterpreterExternV4.sol`,
`IInterpreterStoreV3.sol`, `IInterpreterV4.sol`, `IParserPragmaV1.sol`,
`IParserV2.sol`, `ISubParserV4.sol`

---

## A04 — `src/interface/IInterpreterCallerV4.sol`

### Evidence of thorough reading

**File:** `src/interface/IInterpreterCallerV4.sol` (49 lines)

**Definitions found:**

| Kind | Name | Lines |
|------|------|-------|
| struct | `EvaluableV4` | 25–29 |
| interface | `IInterpreterCallerV4` | 39–48 |
| event | `ContextV2(address sender, bytes32[][] context)` | 47 |

**Imports / re-exports:**

- `IParserV2` (re-exported for convenience, line 7)
- `IInterpreterStoreV3` (re-exported, line 8)
- `IInterpreterV4` (re-exported, line 9)
- `SignedContextV1`, `SIGNED_CONTEXT_SIGNER_OFFSET`, `SIGNED_CONTEXT_CONTEXT_OFFSET`, `SIGNED_CONTEXT_SIGNATURE_OFFSET` from deprecated `IInterpreterCallerV3.sol` (lines 14–18)

**Key observations:**

- `EvaluableV4` bundles an interpreter (`IInterpreterV4`), a store (`IInterpreterStoreV3`), and raw `bytes bytecode`. No validation of any field is required or suggested by the interface.
- `ContextV2` event carries the full context matrix but is marked OPTIONAL; callers that never emit it produce no onchain audit trail.
- The interface-level comment (lines 33–38) says callers OPTIONALLY set state; it does not document what the caller must verify about the interpreter/store addresses in `EvaluableV4` before calling `eval4`.

---

### P1-A04-1 — `EvaluableV4` fields carry no natspec guidance on address validation (LOW)

**File:** `src/interface/IInterpreterCallerV4.sol`, lines 22–29

`EvaluableV4` stores live contract addresses (`interpreter`, `store`) alongside
raw bytecode. A caller that trusts a user-supplied `EvaluableV4` without
checking that the addresses are non-zero, known-safe, or at least
code-containing contracts invites silent misuse (e.g. `interpreter == address(0)` would cause an external call to the zero address, succeeding in some EVM contexts and returning empty data that a poorly written caller might misinterpret).

The struct natspec says only "Will evaluate the expression" / "Will store state
changes" — it does not warn callers to validate addresses or bytecode before
use.

**Recommendation:** Add a natspec warning to the struct:

```diff
 /// @param interpreter Will evaluate the expression.
+/// Callers MUST NOT use an `EvaluableV4` with a zero or untrusted interpreter
+/// address; doing so may silently produce empty results or allow privilege
+/// escalation by a malicious interpreter.
 /// @param store Will store state changes due to evaluation of the expression.
+/// MAY be `NO_STORE` (address(0)) only if the expression never writes state.
 /// @param expression Will be evaluated by the interpreter.
```

---

### P1-A04-2 — Interface comment still references `IInterpreterStoreV2` (INFO)

**File:** `src/interface/IInterpreterCallerV4.sol`, line 38

The interface-level comment reads:

> OPTIONALLY set state on the associated `IInterpreterStoreV2`.

The correct type in `EvaluableV4` is `IInterpreterStoreV3`. This is a stale
copy-paste from `IInterpreterCallerV3`. (Note: this was previously identified
as P1-A06-1 in the `.fixes/` directory; it is recorded here for completeness
and cross-reference.)

**Recommendation:**
```diff
-/// - OPTIONALLY set state on the associated `IInterpreterStoreV2`.
+/// - OPTIONALLY set state on the associated `IInterpreterStoreV3`.
```

---

## A05 — `src/interface/IInterpreterExternV4.sol`

### Evidence of thorough reading

**File:** `src/interface/IInterpreterExternV4.sol` (47 lines)

**Definitions found:**

| Kind | Name | Lines |
|------|------|-------|
| user-defined type | `EncodedExternDispatchV2 is bytes32` | 7 |
| user-defined type | `ExternDispatchV2 is bytes32` | 9 |
| interface | `IInterpreterExternV4` | 21–47 |
| function | `externIntegrity(ExternDispatchV2, uint256, uint256) view returns (uint256, uint256)` | 33–36 |
| function | `extern(ExternDispatchV2, StackItem[] calldata) view returns (StackItem[] calldata)` | 43–46 |

**Key observations:**

- Both functions are `view` — no state mutation is possible through this interface itself.
- `EncodedExternDispatchV2` and `ExternDispatchV2` are distinct `bytes32` wrappers; the relationship between them (encoding/decoding) is not documented in this file.
- `externIntegrity` is intended to be called at integrity-check time (parse/deploy), not at eval time; the interface comment says "checks integrity" but does not mandate when it must be called.
- `extern` returns `StackItem[] calldata` — a calldata-aliased slice — which is an unusual return type. If the extern implementation returns a memory slice mislabeled as calldata, a caller might read garbage.

---

### P1-A05-1 — `extern` return type `StackItem[] calldata` is unsafe for memory-based implementations (MEDIUM)

**File:** `src/interface/IInterpreterExternV4.sol`, lines 43–46

```solidity
function extern(ExternDispatchV2 dispatch, StackItem[] calldata inputs)
    external
    view
    returns (StackItem[] calldata outputs);
```

The return type is `StackItem[] calldata`. For an external `view` function
called via ABI, Solidity decodes return data into memory; the `calldata`
qualifier on the return type is a Solidity-level alias to the return buffer
which the compiler internally handles correctly for ABI decoding.

However, this creates a subtle documentation hazard: interface implementors
unfamiliar with this pattern may attempt to return a `calldata` slice pointing
to `inputs` (aliasing the input), which would work as long as outputs are a
strict prefix of inputs — but any reordering or expansion would silently produce
corrupt results. No natspec warns implementors about this.

More concretely: an interpreter that calls `extern` receives the `calldata`
return and may make assumptions (e.g. pointer arithmetic on the output buffer)
that are only safe if the extern contract is trusted. A malicious extern could
return an oversized or crafted slice.

**Recommendation:** Add natspec to the `extern` function:

```diff
     /// Handles a single dispatch.
     /// @param dispatch Encoded information about the extern to dispatch.
     /// Analogous to the opcode/operand in the interpreter.
     /// @param inputs The array of inputs for the dispatched logic.
     /// @return outputs The result of the dispatched logic.
+    /// Callers MUST NOT assume `outputs` shares memory with `inputs`.
+    /// Implementations MUST return a correctly sized array; extra elements
+    /// beyond the expected output count SHOULD be ignored by callers.
     function extern(ExternDispatchV2 dispatch, StackItem[] calldata inputs)
```

---

### P1-A05-2 — No guidance on when `externIntegrity` must be called relative to `extern` (MEDIUM)

**File:** `src/interface/IInterpreterExternV4.sol`, lines 22–36

`externIntegrity` checks that the dispatch resolves to logic with the expected
input/output arity. Nothing in the interface mandates that `externIntegrity`
must be called (and its results verified) before `extern` is called at eval
time. An interpreter that skips the integrity check and calls `extern` directly
opens itself to malicious externs that report incorrect arities and corrupt
the stack.

The natspec for `externIntegrity` does not say "MUST be called before eval" or
"the interpreter MUST revert if actualInputs != expectedInputs".

**Recommendation:** Add natspec:

```diff
     /// Checks the integrity of some extern call.
+    /// Interpreters MUST call this during integrity checking (before eval) and
+    /// MUST revert if `actualInputs != expectedInputs` or
+    /// `actualOutputs != expectedOutputs`.
     /// @param dispatch Encoded information about the extern to dispatch.
```

---

### P1-A05-3 — `EncodedExternDispatchV2` vs `ExternDispatchV2` relationship undocumented (INFO)

**File:** `src/interface/IInterpreterExternV4.sol`, lines 7–9

Two distinct user-defined types exist — `EncodedExternDispatchV2` and
`ExternDispatchV2` — but the file contains no documentation explaining their
relationship (which is encoded, which is decoded, how to convert between them).
A reader must trace through the interpreter implementation to understand the
distinction. This is an information hazard for implementors.

**Recommendation:** Add a comment above each type explaining the encoding
relationship and which functions accept which form.

---

## A06 — `src/interface/IInterpreterStoreV3.sol`

### Evidence of thorough reading

**File:** `src/interface/IInterpreterStoreV3.sol` (66 lines)

**Definitions found:**

| Kind | Name | Lines |
|------|------|-------|
| interface | `IInterpreterStoreV3` | 31–66 |
| event | `Set(FullyQualifiedNamespace namespace, bytes32 key, bytes32 value)` | 36 |
| function | `set(StateNamespace namespace, bytes32[] calldata kvs) external` | 48 |
| function | `get(FullyQualifiedNamespace namespace, bytes32 key) external view returns (bytes32)` | 65 |

**Re-exports (via deprecated import):**

- `StateNamespace` (re-exported from `IInterpreterStoreV2.sol` → `IInterpreterStoreV1.sol`)
- `FullyQualifiedNamespace` (same chain)
- `NO_STORE` (same chain)

**Key observations:**

- `set` takes an **unqualified** `StateNamespace` and the store qualifies it (lines 43–47). This is the correct design: the store is responsible for isolation.
- `get` takes a **fully qualified** `FullyQualifiedNamespace`. The caller of `get` (the interpreter) must apply `LibNamespace.qualifyNamespace` itself to ensure consistency.
- The interface comment (lines 25–30) mandates corruption resilience and revert-on-detectable-invalid-state.
- Unset keys silently return `0` (line 61).
- The `Set` event is MANDATORY ("MUST be emitted") which gives a complete audit trail for all writes.

---

### P1-A06-1 — `get` with fully qualified namespace allows any caller to read any namespace (LOW)

**File:** `src/interface/IInterpreterStoreV3.sol`, lines 50–65

`get` is `view` and accepts a raw `FullyQualifiedNamespace`. Any external
caller who knows (or can guess) a fully qualified namespace can read the state
for any other caller's namespace. The comment (lines 56–59) acknowledges this:

> Technically also allows onchain reads of any set value from any contract

However, it does not warn that this creates an **information disclosure** risk:
sensitive values stored under any namespace are publicly readable. While this is
inherent to onchain storage, the natspec should explicitly warn implementors
that the store provides **no confidentiality**.

This is particularly relevant if an expression stores values that are intended
to be "private" within a namespace (e.g. internal accounting state). No such
privacy is provided.

**Recommendation:** Add an explicit warning:

```diff
     /// Given a fully qualified namespace and key, return the associated value.
+    /// NOTE: All stored values are publicly readable by any caller who knows
+    /// the fully qualified namespace and key. The store provides isolation
+    /// (write protection) between callers but NOT confidentiality.
```

---

### P1-A06-2 — `set` provides no per-call rate limiting or size constraint guidance (INFO)

**File:** `src/interface/IInterpreterStoreV3.sol`, line 48

`set(StateNamespace, bytes32[] calldata kvs)` accepts an unbounded `bytes32[]`.
A caller could pass an extremely large `kvs` array, consuming significant gas
in a single `set` call. While this is gas-cost borne by the caller, an
interpreter that forwards caller-controlled data to `set` without bounds
checking could be DoS'd in a gas-limited context.

No guidance exists in the interface or natspec about maximum `kvs` length.

**Recommendation (INFO — no fix file required):** Consider documenting whether
implementations SHOULD enforce a maximum `kvs` length, or whether callers
SHOULD bound the size before calling `set`.

---

## A07 — `src/interface/IInterpreterV4.sol`

### Evidence of thorough reading

**File:** `src/interface/IInterpreterV4.sol` (127 lines)

**Definitions found:**

| Kind | Name | Lines |
|------|------|-------|
| user-defined type | `OperandV2 is bytes32` | 41 |
| user-defined type | `StackItem is bytes32` | 45 |
| struct | `EvalV4` | 60–68 |
| interface | `IInterpreterV4` | 106–126 |
| function | `eval4(EvalV4 calldata) external view returns (StackItem[] calldata, bytes32[] calldata)` | 125 |

**Re-exports (via deprecated import):**

- `FullyQualifiedNamespace`, `StateNamespace`, `SourceIndexV2`, `DEFAULT_STATE_NAMESPACE`, `OPCODE_CONSTANT`, `OPCODE_CONTEXT`, `OPCODE_EXTERN`, `OPCODE_UNKNOWN`, `OPCODE_STACK` (from `IInterpreterV3.sol`)
- `IInterpreterStoreV3`

**`EvalV4` struct fields:**

| Field | Type | Lines |
|-------|------|-------|
| `store` | `IInterpreterStoreV3` | 61 |
| `namespace` | `FullyQualifiedNamespace` | 62 |
| `bytecode` | `bytes` | 63 |
| `sourceIndex` | `SourceIndexV2` | 64 |
| `context` | `bytes32[][]` | 65 |
| `inputs` | `StackItem[]` | 66 |
| `stateOverlay` | `bytes32[]` | 67 |

**Key observations:**

- The `EvalV4` struct natspec (lines 47–68) now includes the critical note that the interpreter MUST qualify the namespace itself using `LibNamespace.qualifyNamespace` with `msg.sender` (lines 52–54). This directly addresses namespace isolation.
- `eval4` is `view` — the interpreter cannot persist state. State changes are returned as `writes` for the caller to apply.
- The security model comment (lines 88–99) is comprehensive.
- `stateOverlay` is implementation-defined — no format is specified at the interface level.

---

### P1-A07-1 — `eval4` return type `StackItem[] calldata` and `bytes32[] calldata` exposes implementation to calldata aliasing (MEDIUM)

**File:** `src/interface/IInterpreterV4.sol`, line 125

```solidity
function eval4(EvalV4 calldata eval)
    external view
    returns (StackItem[] calldata stack, bytes32[] calldata writes);
```

Both return values are typed as `calldata`. As with `IInterpreterExternV4.extern`,
this is technically correct in the ABI sense but creates a documentation hazard
for callers. A caller that receives `stack` and `writes` as calldata return
values and then proceeds to call `store.set(namespace, writes)` is making an
implicit trust assumption: that the interpreter returned valid write data.

The interface does not warn callers to validate `writes` before passing them to
the store. A malicious or buggy interpreter could return a `writes` array of
odd length (which `IInterpreterStoreV3` should reject if the store treats it as
key/value pairs), but the interface gives no guidance on pre-validation.

**Recommendation:** Add natspec to `eval4`:

```diff
+    /// The caller is responsible for passing `writes` as-is to the associated
+    /// `IInterpreterStoreV3.set`. The store MUST validate the format of `writes`;
+    /// the caller SHOULD NOT pre-process or filter `writes` as this could
+    /// desynchronise the interpreter's expected state from what is stored.
+    /// Callers MUST handle the case where the store's `set` reverts (e.g. due
+    /// to malformed writes from a malicious interpreter).
     function eval4(EvalV4 calldata eval) external view returns (StackItem[] calldata stack, bytes32[] calldata writes);
```

---

### P1-A07-2 — `stateOverlay` format is implementation-defined with no interface-level constraints (LOW)

**File:** `src/interface/IInterpreterV4.sol`, lines 58–67

`EvalV4.stateOverlay` is described as:

> State overrides applied before evaluation for "what if" analysis. Format is implementation-defined (e.g. pairwise key/value).

Because the format is implementation-defined, there is no guidance on:

1. What happens if `stateOverlay` is non-empty but the interpreter ignores it (silently incorrect "what if" analysis).
2. Whether a caller should use `stateOverlay` in a production (non-simulation) context.
3. Whether `stateOverlay` values can override the namespace qualification (i.e. can an overlay inject values for a different caller's namespace).

If an overlay can inject arbitrary state values with arbitrary fully-qualified
namespaces, it could be used to simulate a different caller's state — which is
desirable for simulation but dangerous if misused in production.

**Recommendation:** Add natspec:

```diff
+/// @param stateOverlay State overrides applied before evaluation for "what if"
+/// simulation only. Format is implementation-defined (e.g. pairwise key/value
+/// using the same format as `writes`). MUST NOT be used in production
+/// state-mutating calls; callers that pass a non-empty overlay and then apply
+/// the resulting `writes` to the store may produce unexpected state.
```

---

### P1-A07-3 — No guidance on handling zero-address `store` in `EvalV4` (LOW)

**File:** `src/interface/IInterpreterV4.sol`, lines 60–62

`EvalV4.store` may be set to `NO_STORE` (address(0)) when the expression does
not write state. The interface does not document what happens if `store` is
address(0) but the bytecode contains state-write opcodes. An interpreter
implementation must handle this gracefully (revert or ignore), but neither
behavior is mandated by the interface.

**Recommendation:** Add natspec:

```diff
 /// @param store The store to read/write state from/to.
+/// MAY be `NO_STORE` (address(0)) if the expression is known not to write
+/// state. Implementations MUST revert or produce empty `writes` if `store` is
+/// `NO_STORE` and the expression attempts a state write.
```

---

## A08 — `src/interface/IParserPragmaV1.sol`

### Evidence of thorough reading

**File:** `src/interface/IParserPragmaV1.sol` (20 lines)

**Definitions found:**

| Kind | Name | Lines |
|------|------|-------|
| struct | `PragmaV1` | 9–11 |
| interface | `IParserPragmaV1` | 14–20 |
| function | `parsePragma1(bytes calldata data) external view returns (PragmaV1 calldata)` | 19 |

**Key observations:**

- `PragmaV1.usingWordsFrom` is an unbounded `address[]`. The natspec (lines 6–8) already says "Implementations SHOULD validate entries (reject zero addresses, handle duplicates)."
- `parsePragma1` returns `PragmaV1 calldata` — a calldata return of a struct containing a dynamic array.
- The function is `view`, so parsing is stateless.
- There is no event, no error, and no mention of what happens with malformed input.

---

### P1-A08-1 — `parsePragma1` return type `PragmaV1 calldata` may surprise implementors (LOW)

**File:** `src/interface/IParserPragmaV1.sol`, line 19

```solidity
function parsePragma1(bytes calldata data) external view returns (PragmaV1 calldata);
```

Returning a struct containing a dynamic array (`address[]`) as `calldata` is
unusual. Solidity supports this for external functions (the return data is
decoded from the ABI return buffer), but an implementor who attempts to return
a locally constructed `PragmaV1` memory struct will get a compiler error
("Return argument type ... is not implicitly convertible to expected type
... calldata").

This is not a security vulnerability per se, but the mismatch between natural
implementation (build a `PragmaV1` in memory and return it) and the declared
`calldata` return type may cause implementors to write workarounds that bypass
safety checks or use assembly incorrectly.

**Recommendation:** Consider changing the return type to `memory`:

```diff
-function parsePragma1(bytes calldata data) external view returns (PragmaV1 calldata);
+function parsePragma1(bytes calldata data) external view returns (PragmaV1 memory);
```

If `calldata` is intentional for gas efficiency (returning a pointer into
calldata), add a natspec note explaining this constraint.

---

### P1-A08-2 — No revert guidance for `parsePragma1` on malformed input (INFO)

**File:** `src/interface/IParserPragmaV1.sol`, lines 16–19

`IParserV2.parse2` explicitly states "MUST revert if the input is not valid
Rainlang." `parsePragma1` has no equivalent statement. It is unclear whether:

- Implementations MUST revert on malformed pragma input.
- Implementations MAY return an empty `PragmaV1` (with empty `usingWordsFrom`).

Callers that depend on `parsePragma1` for address validation of sub-parsers
could be misled by a silent empty return on malformed input.

**Recommendation:** Add natspec:

```diff
     /// Parses pragma directives from Rainlang source data.
+    /// MUST revert if the source contains syntactically invalid pragma
+    /// directives. MAY return a `PragmaV1` with an empty `usingWordsFrom`
+    /// array if no pragma is present.
     /// @param data The Rainlang source to extract pragmas from.
```

---

## A09 — `src/interface/IParserV2.sol`

### Evidence of thorough reading

**File:** `src/interface/IParserV2.sol` (17 lines)

**Definitions found:**

| Kind | Name | Lines |
|------|------|-------|
| interface | `IParserV2` | 10–17 |
| function | `parse2(bytes calldata data) external view returns (bytes calldata bytecode)` | 16 |

**Re-exports:**

- `AuthoringMetaV2` from deprecated `IParserV1.sol` (line 7)

**Key observations:**

- `parse2` is `view` and pure in behavior ("MUST be deterministic", from `IParserV1` doc conventions).
- Input is arbitrary `bytes`; there is no format requirement documented here.
- Output is `bytes calldata bytecode` — the same calldata-return pattern seen in other interfaces.
- "MUST revert if the input is not valid Rainlang" — this is the only behavioral constraint.
- No events, no custom errors, no struct definitions.

---

### P1-A09-1 — `parse2` output bytecode is unconstrained; no guidance on consuming untrusted parser output (MEDIUM)

**File:** `src/interface/IParserV2.sol`, lines 12–16

The caller of `parse2` receives raw `bytes calldata bytecode`. The interface
provides no guidance on:

1. Whether the caller should validate the returned bytecode before storing it
   in an `EvaluableV4` and passing it to `eval4`.
2. Whether a malicious or buggy parser could return syntactically valid but
   semantically dangerous bytecode (e.g. bytecode that causes gas exhaustion,
   infinite loops in the interpreter, or stack corruption).
3. Whether the bytecode returned by `parse2` is already validated against a
   specific interpreter, or if validation is interpreter-side only.

A caller that stores parser-returned bytecode into an `EvaluableV4` and passes
it to `eval4` without any intermediate validation places full trust in the
parser. The security model documented in `IInterpreterV4` puts resilience
responsibility on the interpreter, but the parser-to-eval pipeline lacks
explicit guidance.

**Recommendation:** Add natspec:

```diff
     /// Parses Rainlang source data into bytecode compatible with
     /// `IInterpreterV4.eval4`. MUST revert if the input is not valid Rainlang.
+    /// The returned bytecode is NOT guaranteed to be safe for all interpreters;
+    /// callers SHOULD use the bytecode only with interpreters known to be
+    /// compatible with the parser. The interpreter's integrity checking
+    /// (via `LibBytecode.checkNoOOBPointers` or equivalent) provides the
+    /// final safety gate before execution.
     /// @param data The Rainlang source to parse.
```

---

### P1-A09-2 — No guidance on parser determinism or canonicalization (INFO)

**File:** `src/interface/IParserV2.sol`, lines 12–16

The deprecated `IParserV1.parse` states "MUST be deterministic and MUST NOT
have side effects." `IParserV2.parse2` only says "MUST revert if the input is
not valid Rainlang." The determinism requirement is no longer stated.

While determinism may be implied by `view`, it is not guaranteed: a `view`
function can read blockchain state (block number, timestamps, other contracts'
storage) and return different results for the same input at different times. A
parser that returns different bytecode for the same source at different block
numbers would produce non-reproducible deployments.

**Recommendation:** Add the determinism requirement:

```diff
     /// Parses Rainlang source data into bytecode compatible with
-    /// `IInterpreterV4.eval4`. MUST revert if the input is not valid Rainlang.
+    /// `IInterpreterV4.eval4`. MUST be deterministic and MUST NOT have side
+    /// effects. MUST revert if the input is not valid Rainlang.
```

---

## A10 — `src/interface/ISubParserV4.sol`

### Evidence of thorough reading

**File:** `src/interface/ISubParserV4.sol` (72 lines)

**Definitions found:**

| Kind | Name | Lines |
|------|------|-------|
| interface | `ISubParserV4` | 18–72 |
| function | `subParseLiteral2(bytes calldata data) external view returns (bool success, bytes32 value)` | 40 |
| function | `subParseWord2(bytes calldata data) external view returns (bool success, bytes memory bytecode, bytes32[] memory constants)` | 68–71 |

**Re-exports:**

- `AuthoringMetaV2` from deprecated `ISubParserV3.sol` (line 7)
- `OperandV2` from `IInterpreterV4.sol` (line 9)

**Key observations:**

- Both functions are `view` — no state mutation.
- The "MUST NOT revert if unknown" / "MUST revert if known but malformed" pattern is clearly documented (lines 22–29 and 44–48).
- `subParseWord2` returns `bytes memory bytecode` and `bytes32[] memory constants` — memory returns (not calldata), which is the natural implementation pattern.
- `subParseLiteral2` returns `bytes32 value` — the literal value. No constraints on value range.
- No compatibility version parameter is present (unlike `ISubParserV3` which had a `compatibility` parameter). This means any main parser can call any sub-parser without checking compatibility — the sub-parser cannot reject based on the calling parser's version.

---

### P1-A10-1 — Removal of `compatibility` parameter eliminates version gating (HIGH)

**File:** `src/interface/ISubParserV4.sol`, lines 40 and 68

`ISubParserV3.subParseLiteral` and `ISubParserV3.subParseWord` both accepted a
`bytes32 compatibility` parameter (e.g. `COMPATIBILITY_V5`). This allowed a
sub-parser to reject callers using an incompatible format.

`ISubParserV4.subParseLiteral2` and `ISubParserV4.subParseWord2` have removed
this parameter entirely. The consequence is:

1. A main parser using `ISubParserV4` can call any `ISubParserV4`
   implementation without the sub-parser being able to distinguish the calling
   parser's expected data format.
2. If data format expectations differ between parsers (e.g. a new parser
   version changes the layout of the `data` bytes), a sub-parser has no way to
   detect this and will either silently parse garbage or revert due to
   malformed data.
3. Old sub-parsers implementing `ISubParserV3` (with the `compatibility`
   parameter) cannot be used with new parsers that call `ISubParserV4`, forcing
   reimplementation rather than adapter patterns.

The interface comment says "The data layout is identical to `COMPATIBILITY_V5`
from `ISubParserV3`" — this is an implicit version pin baked into the interface
name rather than enforced at call time. If a new version of `ISubParserV4` with
a different data layout is needed, there would be no graceful migration path
within the same interface version.

**Recommendation:** Document the implicit version pin explicitly:

```diff
 /// @title ISubParserV4
 /// Identical to `ISubParserV3` except the interface functions are versioned
 /// rather than using compatibility versions.
 ///
 /// The data layout is identical to `COMPATIBILITY_V5` from `ISubParserV3`,
 /// except that parsed values are `bytes32` to better represent that they are NOT
 /// expected to be used as integers (most likely packed float values).
+///
+/// IMPORTANT: The compatibility version is now implicit in the interface name
+/// (`ISubParserV4`). Sub-parsers implementing this interface MUST assume the
+/// `COMPATIBILITY_V5` data layout. If the data layout changes in future, a new
+/// interface version (e.g. `ISubParserV5`) MUST be created. Callers MUST NOT
+/// pass data in a format other than `COMPATIBILITY_V5` to `ISubParserV4`
+/// implementations.
 interface ISubParserV4 {
```

---

### P1-A10-2 — `subParseWord2` returns unconstrained `bytes memory bytecode`; no validation guidance (MEDIUM)

**File:** `src/interface/ISubParserV4.sol`, lines 68–71

`subParseWord2` returns arbitrary `bytes memory bytecode`. This bytecode is
merged into the main parser's output and will eventually be executed by an
interpreter. The interface provides no guidance on:

1. Whether the main parser must validate the returned bytecode structure before
   merging it.
2. Whether a malicious sub-parser could return bytecode that corrupts the
   main parser's output (e.g. by returning more bytes than expected for an
   opcode, causing misaligned parsing of subsequent opcodes).
3. Whether the sub-parser is trusted or untrusted from the main parser's
   perspective.

A sub-parser is typically registered via `PragmaV1.usingWordsFrom` (address
list). If a user supplies a malicious address as a sub-parser, the main parser
will call `subParseWord2` on it and receive arbitrary bytecode that gets
compiled into the expression.

The comment (lines 53–56) says "the sub parser relies on convention to ensure
that it is producing valid bytecode and constants" but does not tell the main
parser whether or how to validate the output.

**Recommendation:** Add natspec:

```diff
     /// @return bytecode The bytecode of the word.
+    /// The main parser MUST validate the structure and length of the returned
+    /// bytecode before merging it. A malicious sub-parser may return oversized
+    /// or misaligned bytecode. The interpreter's integrity checking provides
+    /// a final safety gate, but the parser SHOULD perform preliminary
+    /// validation to produce better error messages.
     /// @return constants The constants of the word.
```

---

### P1-A10-3 — No guidance on sub-parser address trust in the context of `PragmaV1` (MEDIUM)

**File:** `src/interface/ISubParserV4.sol` (whole file)

`ISubParserV4` is used via the `usingWordsFrom` mechanism in `PragmaV1`. The
sub-parser addresses in `PragmaV1` are user-supplied. There is no guidance in
`ISubParserV4` or `IParserPragmaV1` that warns:

- Sub-parsers are potentially untrusted code.
- The main parser SHOULD consider calling sub-parsers with bounded gas.
- A sub-parser that reverts unexpectedly (violating the "MUST NOT revert if
  unknown" contract) will cause parsing to fail for all subsequent words.
- A sub-parser that succeeds but returns `success = true` for every `data`
  input (even data it cannot parse correctly) will prevent other sub-parsers
  from being tried and may produce silently incorrect bytecode.

**Recommendation:** Add an interface-level natspec warning:

```diff
 /// @title ISubParserV4
+/// @notice Sub-parsers are invoked with arbitrary `data` by the main parser.
+/// Sub-parser addresses are typically supplied by end users via `PragmaV1`.
+/// Main parsers MUST treat sub-parser return values as untrusted and MUST
+/// validate returned bytecode structure before use. Sub-parsers MUST NOT
+/// return `success = true` for data they cannot correctly parse.
```

---

## Summary Table

| Finding | Agent | File | Severity |
|---------|-------|------|----------|
| P1-A04-1 | A04 | IInterpreterCallerV4.sol | LOW |
| P1-A04-2 | A04 | IInterpreterCallerV4.sol | INFO |
| P1-A05-1 | A05 | IInterpreterExternV4.sol | MEDIUM |
| P1-A05-2 | A05 | IInterpreterExternV4.sol | MEDIUM |
| P1-A05-3 | A05 | IInterpreterExternV4.sol | INFO |
| P1-A06-1 | A06 | IInterpreterStoreV3.sol | LOW |
| P1-A06-2 | A06 | IInterpreterStoreV3.sol | INFO |
| P1-A07-1 | A07 | IInterpreterV4.sol | MEDIUM |
| P1-A07-2 | A07 | IInterpreterV4.sol | LOW |
| P1-A07-3 | A07 | IInterpreterV4.sol | LOW |
| P1-A08-1 | A08 | IParserPragmaV1.sol | LOW |
| P1-A08-2 | A08 | IParserPragmaV1.sol | INFO |
| P1-A09-1 | A09 | IParserV2.sol | MEDIUM |
| P1-A09-2 | A09 | IParserV2.sol | INFO |
| P1-A10-1 | A10 | ISubParserV4.sol | HIGH |
| P1-A10-2 | A10 | ISubParserV4.sol | MEDIUM |
| P1-A10-3 | A10 | ISubParserV4.sol | MEDIUM |
