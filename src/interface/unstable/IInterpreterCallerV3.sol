// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import {IParserV2} from "./IParserV2.sol";
import {IInterpreterStoreV2} from "../IInterpreterStoreV2.sol";
import {IInterpreterV3} from "./IInterpreterV3.sol";

/// Struct over the return of `IParserV2.parse2` which MAY be more convenient to
/// work with than raw addresses.
/// @param interpreter Will evaluate the expression.
/// @param store Will store state changes due to evaluation of the expression.
/// @param expression Will be evaluated by the interpreter.
struct EvaluableV3 {
    IInterpreterV3 interpreter;
    IInterpreterStoreV2 store;
    bytes bytecode;
}

/// Typed embodiment of some context data with associated signer and signature.
/// The signature MUST be over the packed encoded bytes of the context array,
/// i.e. the context array concatenated as bytes without the length prefix, then
/// hashed, then handled as per EIP-191 to produce a final hash to be signed.
///
/// The calling contract (likely with the help of `LibContext`) is responsible
/// for ensuring the authenticity of the signature, but not authorizing _who_ can
/// sign. IN ADDITION to authorisation of the signer to known-good entities the
/// expression is also responsible for:
///
/// - Enforcing the context is the expected data (e.g. with a domain separator)
/// - Tracking and enforcing nonces if signed contexts are only usable one time
/// - Tracking and enforcing uniqueness of signed data if relevant
/// - Checking and enforcing expiry times if present and relevant in the context
/// - Many other potential constraints that expressions may want to enforce
///
/// EIP-1271 smart contract signatures are supported in addition to EOA
/// signatures via. the Open Zeppelin `SignatureChecker` library, which is
/// wrapped by `LibContext.build`. As smart contract signatures are checked
/// onchain they CAN BE REVOKED AT ANY MOMENT as the smart contract can simply
/// return `false` when it previously returned `true`.
///
/// @param signer The account that produced the signature for `context`. The
/// calling contract MUST authenticate that the signer produced the signature.
/// @param context The signed data in a format that can be merged into a
/// 2-dimensional context matrix as-is.
/// @param signature The cryptographic signature for `context`. The calling
/// contract MUST authenticate that the signature is valid for the `signer` and
/// `context`.
struct SignedContextV1 {
    // The ordering of these fields is important and used in assembly offset
    // calculations and hashing.
    address signer;
    uint256[] context;
    bytes signature;
}

uint256 constant SIGNED_CONTEXT_SIGNER_OFFSET = 0;
uint256 constant SIGNED_CONTEXT_CONTEXT_OFFSET = 0x20;
uint256 constant SIGNED_CONTEXT_SIGNATURE_OFFSET = 0x40;

/// @title IInterpreterCallerV3
/// @notice A contract that calls an `IInterpreterV3` via. `eval3`. There are
/// near zero requirements on a caller other than:
///
/// - Provide the context, which can be built in a standard way by `LibContext`
/// - Handle the stack array returned from `eval3`
/// - OPTIONALLY emit the `Context` event
/// - OPTIONALLY set state on the `IInterpreterStoreV2` returned from `eval3`.
interface IInterpreterCallerV3 {
    /// Calling contracts SHOULD emit `Context` before calling `eval3` if they
    /// are able. Notably `eval3` MAY be called within a static call which means
    /// that events cannot be emitted, in which case this does not apply. It MAY
    /// NOT be useful to emit this multiple times for several eval calls if they
    /// all share a common context, in which case a single emit is sufficient.
    /// @param sender `msg.sender` building the context.
    /// @param context The context that was built.
    event Context(address sender, uint256[][] context);
}
