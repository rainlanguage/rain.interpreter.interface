# Pass 1 Security Review — LibContext.sol
Agent: A12
Date: 2026-03-04

---

## Evidence of Thorough Reading

**File reviewed:** `src/lib/caller/LibContext.sol`

**Library name:** `LibContext`

**Functions and line numbers:**

| Function | Line | Visibility | Mutability |
|---|---|---|---|
| `base()` | 60 | `internal` | `view` |
| `hash(SignedContextV1 memory)` | 76 | `internal` | `pure` |
| `hash(SignedContextV1[] memory)` | 105 | `internal` | `pure` |
| `build(bytes32[][] memory, SignedContextV1[] memory)` | 168 | `internal` | `view` |

**Imports:**

| Import | Source |
|---|---|
| `LibHashNoAlloc`, `HASH_NIL` | `rain.lib.hash/LibHashNoAlloc.sol` |
| `SignatureChecker` | `openzeppelin-contracts/contracts/utils/cryptography/SignatureChecker.sol` |
| `MessageHashUtils` | `openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol` |
| `SignedContextV1`, `SIGNED_CONTEXT_SIGNER_OFFSET`, `SIGNED_CONTEXT_SIGNATURE_OFFSET`, `SIGNED_CONTEXT_CONTEXT_OFFSET` | `../../interface/IInterpreterCallerV4.sol` (re-exported from `deprecated/v1/IInterpreterCallerV2.sol`) |

**Errors defined:**

| Error | Line | Parameters |
|---|---|---|
| `InvalidSignature` | 19 | `uint256 i` |

**Constants defined:**

| Constant | Line | Value | Type |
|---|---|---|---|
| `CONTEXT_BASE_COLUMN` | 24 | `0` | `uint256` |
| `CONTEXT_BASE_ROWS` | 27 | `2` | `uint256` |
| `CONTEXT_BASE_ROW_SENDER` | 30 | `0` | `uint256` |
| `CONTEXT_BASE_ROW_CALLING_CONTRACT` | 33 | `1` | `uint256` |

**Types defined:** None (types imported from interface files)

---

## Security Analysis

### Scope

The library constructs the 2-D execution context array that is passed to interpreter `eval` calls and authenticates `SignedContextV1` structs submitted by `msg.sender`. It is the primary trust boundary between off-chain signers and on-chain expression execution.

---

## Findings

### P1-A12-1 — No Domain Separator or Chain ID in the Signed Message Hash (HIGH)

**File:** `src/lib/caller/LibContext.sol`
**Lines:** 204–210

**Description:**

`build()` verifies each `SignedContextV1` using:

```solidity
MessageHashUtils.toEthSignedMessageHash(
    LibHashNoAlloc.hashWords(signedContexts[i].context)
)
```

The signed digest is `keccak256("\x19Ethereum Signed Message:\n32" || keccak256(context_words))`. It contains:

- No chain ID
- No contract address (calling contract or interpreter)
- No function selector / operation type

A signature produced for a legitimate call on chain A / contract X / function F is therefore valid for any call on chain B / contract Y / function G that presents the same raw context words. This enables cross-chain and cross-contract replay.

The NatSpec on `SignedContextV1` (line 41-43, `IInterpreterCallerV2.sol`) acknowledges this explicitly:

> "Enforcing the context is the expected data (e.g. with a domain separator)" … "Tracking and enforcing nonces" … "Checking and enforcing expiry times"

and places responsibility on the **expression** (Rainlang bytecode), not on the library. This is a deliberate architectural choice: the library handles authentication (is the signature from the stated signer?) while domain binding is delegated to expression logic. The architecture is therefore intentional.

However, callers may implement expressions that forget to include a domain separator in the context payload, and there is no enforcement at the library level. The result is broad, undocumented, cross-contract and cross-chain replay potential if expression authors overlook the requirement.

**Severity:** HIGH — the risk is real and structural; the only mitigation is correct expression authorship, which is not enforced.

**Recommendation:** Add a prominent `@security` NatSpec tag to `build()` stating that the signed payload contains no chain or contract binding. Consider whether the library should optionally or mandatorily include `block.chainid` and `address(this)` in the hashed payload, or provide a helper that does so.

---

### P1-A12-2 — address(0) Signer Accepted by SignatureChecker for ERC-1271 Path (MEDIUM)

**File:** `src/lib/caller/LibContext.sol`
**Lines:** 204–213

**Description:**

`SignatureChecker.isValidSignatureNow` (OZ v5.5.0, line 32–39 in its source) checks:

```solidity
if (signer.code.length == 0) {
    (address recovered, ECDSA.RecoverError err, ) = ECDSA.tryRecover(hash, signature);
    return err == ECDSA.RecoverError.NoError && recovered == signer;
} else {
    return isValidERC1271SignatureNow(signer, hash, signature);
}
```

For `signer == address(0)`:

- `address(0).code.length == 0` (no code at the zero address on mainnet).
- `ECDSA.tryRecover` will never return `address(0)` without also returning `RecoverError.InvalidSignature` (see ECDSA.sol line 191–193), so the EOA path correctly rejects `address(0)`.

However, on networks or testnets where `address(0)` has been given code (unusual but possible), the ERC-1271 path would be taken and the call would be forwarded to whatever contract sits at `address(0)`. This is an edge case and unlikely in practice, but:

- There is no explicit guard that prevents `SignedContextV1.signer == address(0)` from being submitted.
- On anomalous chains, a malicious zero-address contract could approve arbitrary payloads.

Additionally, `signers[i] = bytes32(uint256(uint160(signedContexts[i].signer)))` (line 215) will insert `bytes32(0)` into the signers column, potentially confusing expressions that test `signer != 0` as a sentinel for "no signer present" in the column.

**Severity:** MEDIUM — low likelihood on mainnet, but the absence of an explicit zero-address guard creates subtle risk.

**Recommendation:** Add an explicit check `require(signedContexts[i].signer != address(0), ...)` or a corresponding custom error at the top of the loop before calling `isValidSignatureNow`.

---

### P1-A12-3 — Scratch Space Clobbering in `hash(SignedContextV1 memory)` (LOW)

**File:** `src/lib/caller/LibContext.sol`
**Lines:** 81–93

**Description:**

`hash(SignedContextV1 memory)` performs multiple scratch-space writes at `0x00` and `0x20` in sequence:

```assembly
mstore(0, keccak256(add(signedContext, signerOffset), 0x20))  // writes 0x00
// ...
mstore(0x20, keccak256(add(context_, 0x20), mul(mload(context_), 0x20)))  // writes 0x20
mstore(0, keccak256(0, 0x40))  // writes 0x00 (clobbers first store)
// ...
mstore(0x20, keccak256(add(signature_, 0x20), mload(signature_)))  // writes 0x20
hashed := keccak256(0, 0x40)
```

This is labelled `memory-safe`. EVM scratch space (`0x00`–`0x3f`) is defined as a valid scratch area that assembly can freely use without notifying the Solidity memory allocator, so the annotation is technically correct. However, any caller that also uses `assembly ("memory-safe")` and relies on scratch-space values surviving across a `CALL` or `JUMP` into this function will have those values silently overwritten. Because Solidity itself uses this area for keccak, this is an inherent hazard that the annotation correctly signals — but the wider call chain in `hash(SignedContextV1[] memory)` (lines 117–131) manually saves and restores slot `0x00` (`mem0`) precisely because it is aware of this hazard.

The use in `build()` does not preserve scratch space around the `hash` call, but `build()` does not need any scratch-space values to survive across that call, so there is no actual bug in the current code. The risk is latent: if the `build()` function is extended or refactored to do scratch-space work before/after calling `hash`, the clobber could introduce a silent corruption.

**Severity:** LOW — no current exploit, but a latent maintenance hazard.

**Recommendation:** Document in a NatSpec comment on `hash(SignedContextV1 memory)` that this function writes to EVM scratch space (`0x00`–`0x3f`) and callers must not assume those slots are preserved across the call.

---

### P1-A12-4 — Signed Context Data Passed by Reference, Not Copied into Context Array (INFO)

**File:** `src/lib/caller/LibContext.sol`
**Lines:** 217

**Description:**

```solidity
context[offset] = signedContexts[i].context;
```

This assigns the pointer to the `bytes32[]` that is already inside the caller-supplied `signedContexts` struct. The context array entry and the original `signedContexts[i].context` share the same underlying memory. After `build()` returns, if a caller mutates `signedContexts[i].context` (e.g., in tests or via assembly), the already-returned `context` array is also mutated.

In normal Solidity usage within a single transaction this does not introduce an exploit because:

1. The entire context is consumed by `eval` before any mutations are plausible.
2. The interpreter itself only reads context.

However, callers who store or cache the returned `context` and later compare or re-use it after further mutations of the original `SignedContextV1` structs may observe unexpected behaviour. The issue is inherent to the gas-optimised design (avoiding a copy) and is correctly documented implicitly — but there is no explicit NatSpec warning.

**Severity:** INFO — no exploit in the standard usage pattern; documentation gap only.

**Recommendation:** Add a NatSpec note that the returned context array shares memory with the input `signedContexts` context fields and should be treated as read-only.

---

### P1-A12-5 — Unchecked Arithmetic in `build()` Used for Array Length Calculation (INFO)

**File:** `src/lib/caller/LibContext.sol`
**Lines:** 173, 178

**Description:**

The entire `build()` body is wrapped in `unchecked { ... }`. The length calculation:

```solidity
uint256 contextLength = 1 + baseContext.length + (signedContexts.length > 0 ? signedContexts.length + 1 : 0);
```

is performed without overflow protection. An overflow would cause `new bytes32[][](contextLength)` to allocate a much smaller array than expected, and subsequent indexed writes (`context[offset] = ...`) would write past the array bounds, corrupting adjacent memory.

In practice, `baseContext.length` and `signedContexts.length` are bounded by available calldata/memory and will not realistically approach `type(uint256).max`. The maximum array length in an EVM transaction is constrained by the block gas limit. Overflow here is not a realistic attack vector, but the `unchecked` scope is wider than necessary: only the loop increment (`offset++`, `i++`) genuinely benefits from being unchecked.

**Severity:** INFO — theoretical only given gas constraints.

**Recommendation:** Consider moving the length arithmetic outside (or narrowing) the `unchecked` block, or add an explicit comment explaining why overflow is impossible here.

---

### P1-A12-6 — `base()` Uses `caller()` Not `msg.sender` — Correct but Subtle (INFO)

**File:** `src/lib/caller/LibContext.sol`
**Lines:** 61–68

**Description:**

```assembly
mstore(add(baseArray, 0x20), caller())
mstore(add(baseArray, 0x40), address())
```

`caller()` is the EVM opcode that returns the immediate caller of the current execution frame. In a normal external call chain `User -> CallingContract -> LibContext.base()`, because `LibContext` is a library (DELEGATECALL), `caller()` within library code is the same as `msg.sender` in the calling contract's context. This is correct.

However, the NatSpec says "the `msg.sender`" and in the slow reference implementation (`LibContextSlow.sol` line 42) it uses `msg.sender` explicitly. These are equivalent in the library context but may confuse developers who are unfamiliar with how DELEGATECALL propagates `msg.sender` / `caller()`.

**Severity:** INFO — documentation clarity only; no security impact.

**Recommendation:** Mention in the NatSpec that `caller()` is used rather than `msg.sender` because the library executes in the calling contract's context via DELEGATECALL, and clarify they are equivalent here.

---

## Summary Table

| ID | Title | Severity |
|---|---|---|
| P1-A12-1 | No Domain Separator or Chain ID in Signed Message Hash | HIGH |
| P1-A12-2 | address(0) Signer Accepted without Explicit Guard | MEDIUM |
| P1-A12-3 | Scratch Space Clobbering in `hash(SignedContextV1)` | LOW |
| P1-A12-4 | Signed Context Data Passed by Reference into Result Array | INFO |
| P1-A12-5 | Unchecked Arithmetic Scope Wider Than Necessary in `build()` | INFO |
| P1-A12-6 | `base()` Uses `caller()` vs `msg.sender` — Subtle but Correct | INFO |
