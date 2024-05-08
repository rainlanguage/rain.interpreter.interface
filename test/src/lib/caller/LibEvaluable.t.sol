// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {EvaluableV2} from "src/interface/IInterpreterCallerV2.sol";
import {LibEvaluable} from "src/lib/caller/LibEvaluable.sol";
import {LibEvaluableSlow} from "./LibEvaluableSlow.sol";
import {IInterpreterStoreV2} from "src/interface/IInterpreterStoreV2.sol";
import {IInterpreterV2} from "src/interface/IInterpreterV2.sol";

import {EvaluableV3} from "src/interface/unstable/IInterpreterCallerV3.sol";
import {IInterpreterV3} from "src/interface/unstable/IInterpreterV3.sol";

contract LibEvaluableTest is Test {
    using LibEvaluable for EvaluableV2;
    using LibEvaluable for EvaluableV3;

    /// Test a known hash so that if the hash function changes, we know.
    function testEvaluableV2KnownHash() external {
        EvaluableV2 memory evaluable =
            EvaluableV2(IInterpreterV2(address(1)), IInterpreterStoreV2(address(2)), address(3));
        assertEq(evaluable.hash(), bytes32(0x6e0c627900b24bd432fe7b1f713f1b0744091a646a9fe4a65a18dfed21f2949c));
    }

    function testEvaluableV2HashDifferent(EvaluableV2 memory a, EvaluableV2 memory b) public {
        vm.assume(a.interpreter != b.interpreter || a.store != b.store || a.expression != b.expression);
        assertTrue(a.hash() != b.hash());
    }

    function testEvaluableV2HashSame(EvaluableV2 memory a) public {
        EvaluableV2 memory b = EvaluableV2(a.interpreter, a.store, a.expression);
        assertEq(a.hash(), b.hash());
    }

    function testEvaluableV2HashSensitivity(EvaluableV2 memory a, EvaluableV2 memory b) public {
        vm.assume(a.interpreter != b.interpreter && a.store != b.store && a.expression != b.expression);

        EvaluableV2 memory c;

        assertTrue(a.hash() != b.hash());

        // Check interpreter changes hash.
        c = EvaluableV2(b.interpreter, a.store, a.expression);
        assertTrue(a.hash() != c.hash());

        // Check store changes hash.
        c = EvaluableV2(a.interpreter, b.store, a.expression);
        assertTrue(a.hash() != c.hash());

        // Check expression changes hash.
        c = EvaluableV2(a.interpreter, a.store, b.expression);
        assertTrue(a.hash() != c.hash());

        // Check match.
        c = EvaluableV2(a.interpreter, a.store, a.expression);
        assertEq(a.hash(), c.hash());

        // Check hash doesn't include extraneous data
        uint256 v0 = type(uint256).max;
        uint256 v1 = 0;
        EvaluableV2 memory d = EvaluableV2(IInterpreterV2(address(0)), IInterpreterStoreV2(address(0)), address(0));
        assembly ("memory-safe") {
            mstore(mload(0x40), v0)
        }
        bytes32 hash0 = d.hash();
        assembly ("memory-safe") {
            mstore(mload(0x40), v1)
        }
        bytes32 hash1 = d.hash();
        assertEq(hash0, hash1);
    }

    function testEvaluableV2HashGas0() public pure {
        EvaluableV2(IInterpreterV2(address(0)), IInterpreterStoreV2(address(0)), address(0)).hash();
    }

    function testEvaluableV2HashGasSlow0() public pure {
        LibEvaluableSlow.hashSlow(EvaluableV2(IInterpreterV2(address(0)), IInterpreterStoreV2(address(0)), address(0)));
    }

    function testEvaluableV2ReferenceImplementation(EvaluableV2 memory evaluable) public {
        assertEq(LibEvaluable.hash(evaluable), LibEvaluableSlow.hashSlow(evaluable));
    }

    /// Test a known hash so that if the hash function changes, we know.
    function testEvaluableV3KnownHash() external {
        EvaluableV3 memory evaluable =
            EvaluableV3(IInterpreterV3(address(1)), IInterpreterStoreV2(address(2)), hex"030405");
        assertEq(evaluable.hash(), bytes32(0x389371bb1206fa55c5ce170f501ebbe5aacd211e163a6076a349c8bc6437aaa9));
    }

    function testEvaluableV3HashDifferent(EvaluableV3 memory a, EvaluableV3 memory b) public {
        vm.assume(
            a.interpreter != b.interpreter || a.store != b.store || keccak256(a.bytecode) != keccak256(b.bytecode)
        );
        assertTrue(a.hash() != b.hash());
    }

    function testEvaluableV3HashSame(EvaluableV3 memory a) public {
        EvaluableV3 memory b = EvaluableV3(a.interpreter, a.store, a.bytecode);
        assertEq(a.hash(), b.hash());
    }

    function testEvaluableV3HashSensitivity(EvaluableV3 memory a, EvaluableV3 memory b) public {
        vm.assume(
            a.interpreter != b.interpreter && a.store != b.store && keccak256(a.bytecode) != keccak256(b.bytecode)
        );

        EvaluableV3 memory c;

        assertTrue(a.hash() != b.hash());

        // Check interpreter changes hash.
        c = EvaluableV3(b.interpreter, a.store, a.bytecode);
        assertTrue(a.hash() != c.hash());

        // Check store changes hash.
        c = EvaluableV3(a.interpreter, b.store, a.bytecode);
        assertTrue(a.hash() != c.hash());

        // Check bytecode changes hash.
        c = EvaluableV3(a.interpreter, a.store, b.bytecode);
        assertTrue(a.hash() != c.hash());

        // Check match.
        c = EvaluableV3(a.interpreter, a.store, a.bytecode);
        assertEq(a.hash(), c.hash());

        // Check hash doesn't include extraneous data
        uint256 v0 = type(uint256).max;
        uint256 v1 = 0;
        EvaluableV3 memory d = EvaluableV3(IInterpreterV3(address(0)), IInterpreterStoreV2(address(0)), hex"");
        assembly ("memory-safe") {
            mstore(mload(0x40), v0)
        }
        bytes32 hash0 = d.hash();
        assembly ("memory-safe") {
            mstore(mload(0x40), v1)
        }
        bytes32 hash1 = d.hash();
        assertEq(hash0, hash1);
    }

    function testEvaluableV3HashGas0() public pure {
        EvaluableV3(IInterpreterV3(address(0)), IInterpreterStoreV2(address(0)), hex"").hash();
    }

    function testEvaluableV3BytecodeLengthSensitivity() public {
        EvaluableV3 memory a = EvaluableV3(IInterpreterV3(address(0)), IInterpreterStoreV2(address(0)), hex"01");
        // `b` is identical to `a` except for the bytecode length.
        // Note the trailing `00` in the bytecode would be the same in memory as
        // the `00` padding that the allocator would add to `a`'s bytecode.
        EvaluableV3 memory b = EvaluableV3(IInterpreterV3(address(0)), IInterpreterStoreV2(address(0)), hex"0100");
        assertTrue(a.hash() != b.hash());
    }

    function testEvaluableV3HashGasSlow0() public pure {
        LibEvaluableSlow.hashSlow(EvaluableV3(IInterpreterV3(address(0)), IInterpreterStoreV2(address(0)), hex""));
    }

    function testEvaluableV3ReferenceImplementation(EvaluableV3 memory evaluable) public {
        assertEq(LibEvaluable.hash(evaluable), LibEvaluableSlow.hashSlow(evaluable));
    }
}
