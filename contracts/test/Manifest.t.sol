// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Manifest} from "../src/Manifest.sol";

/// Minimal cheatcode interface, declared here rather than pulled from forge-std.
/// These tests have no dependencies on purpose: nothing to install, nothing to
/// keep in sync, and the CI job needs no package step at all.
interface Vm {
    function deal(address who, uint256 amount) external;
    function prank(address sender) external;
    function expectRevert() external;
}

Vm constant VM = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

/// A payee that refuses value, to prove one bad line reverts the whole batch.
contract Refuses {
    receive() external payable {
        revert("refused");
    }
}

contract ManifestTest {
    Manifest m;

    address constant ALICE = address(0xA11CE);
    address constant BOB = address(0xB0B);
    address constant CAROL = address(0xCA401);

    function setUp() public {
        m = new Manifest();
        VM.deal(address(this), 1_000e18);
    }

    function lines()
        internal
        pure
        returns (address[] memory p, uint256[] memory a, string[] memory n)
    {
        p = new address[](3);
        a = new uint256[](3);
        n = new string[](3);
        p[0] = ALICE;   a[0] = 1e18;  n[0] = "first";
        p[1] = BOB;     a[1] = 2e18;  n[1] = "second";
        p[2] = CAROL;   a[2] = 3e18;  n[2] = "third";
    }

    function test_pays_every_line() public {
        (address[] memory p, uint256[] memory a, string[] memory n) = lines();
        uint256 beforeAlice = ALICE.balance;

        uint256 id = m.pay{value: 6e18}(p, a, n, "october");

        require(id == 1, "first batch is id 1");
        require(ALICE.balance - beforeAlice == 1e18, "alice paid");
        require(BOB.balance == 2e18, "bob paid");
        require(CAROL.balance == 3e18, "carol paid");
        require(address(m).balance == 0, "contract keeps nothing");
    }

    function test_batch_ids_increment() public {
        (address[] memory p, uint256[] memory a, string[] memory n) = lines();
        require(m.pay{value: 6e18}(p, a, n, "one") == 1, "first");
        require(m.pay{value: 6e18}(p, a, n, "two") == 2, "second");
        require(m.batches() == 2, "count");
    }

    function test_rejects_empty_manifest() public {
        address[] memory p = new address[](0);
        uint256[] memory a = new uint256[](0);
        string[] memory n = new string[](0);
        VM.expectRevert();
        m.pay{value: 0}(p, a, n, "nothing");
    }

    function test_rejects_length_mismatch() public {
        (address[] memory p, uint256[] memory a, string[] memory n) = lines();
        uint256[] memory short = new uint256[](2);
        short[0] = 1e18;
        short[1] = 2e18;
        VM.expectRevert();
        m.pay{value: 3e18}(p, short, n, "ragged");
    }

    function test_rejects_zero_payee_up_front() public {
        (address[] memory p, uint256[] memory a, string[] memory n) = lines();
        p[1] = address(0);
        VM.expectRevert();
        m.pay{value: 6e18}(p, a, n, "burn");
    }

    function test_rejects_zero_amount() public {
        (address[] memory p, uint256[] memory a, string[] memory n) = lines();
        a[2] = 0;
        VM.expectRevert();
        m.pay{value: 3e18}(p, a, n, "free work");
    }

    function test_rejects_underfunding() public {
        (address[] memory p, uint256[] memory a, string[] memory n) = lines();
        VM.expectRevert();
        m.pay{value: 5e18}(p, a, n, "short");
    }

    function test_rejects_overfunding() public {
        (address[] memory p, uint256[] memory a, string[] memory n) = lines();
        VM.expectRevert();
        m.pay{value: 7e18}(p, a, n, "overpaid");
    }

    /// The Arc trap, tested rather than documented. On Arc one USDC is 1e18.
    /// A contract written from ERC-20 habit reaches for 1e6, which underfunds the
    /// batch by a factor of 1e12. Silent rounding here would be a real loss of
    /// money, so it must revert loudly.
    function test_six_decimal_habit_reverts_instead_of_underfunding() public {
        address[] memory p = new address[](1);
        uint256[] memory a = new uint256[](1);
        string[] memory n = new string[](1);
        p[0] = ALICE;
        a[0] = 1e18; // one USDC, correctly expressed for Arc
        n[0] = "one dollar";

        VM.expectRevert();
        m.pay{value: 1e6}(p, a, n, "erc20 habit"); // one dollar, as ERC-20 writes it

        uint256 paid = m.pay{value: 1e18}(p, a, n, "correct");
        require(paid == 1, "correct scale settles");
        require(ALICE.balance == 1e18, "exactly one USDC arrives");
    }

    /// A single bad payee must not leave the manifest half settled.
    function test_one_failing_line_reverts_the_whole_batch() public {
        Refuses refuses = new Refuses();
        address[] memory p = new address[](2);
        uint256[] memory a = new uint256[](2);
        string[] memory n = new string[](2);
        p[0] = ALICE;
        p[1] = address(refuses);
        a[0] = 1e18;
        a[1] = 1e18;
        n[0] = "paid";
        n[1] = "refused";

        uint256 beforeAlice = ALICE.balance;
        VM.expectRevert();
        m.pay{value: 2e18}(p, a, n, "doomed");

        require(ALICE.balance == beforeAlice, "alice must not be paid");
        require(m.batches() == 0, "no batch recorded");
    }

    function test_totalOf_matches_the_required_value() public {
        (, uint256[] memory a, ) = lines();
        require(m.totalOf(a) == 6e18, "sum");
    }
}
