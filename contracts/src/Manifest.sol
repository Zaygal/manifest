// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Manifest
/// @notice Pay a list of people in one transaction on Arc.
///
/// On Arc, USDC is the native asset, so `msg.value` *is* dollars. That is the
/// whole reason this contract is this small: there is no token to approve, no
/// `transferFrom`, and no allowance to get wrong. A batch is one signed
/// transaction that moves native value to every line on the manifest.
///
/// Two Arc-specific behaviours are load-bearing here:
///
///  * `address(0)` sends REVERT on Arc rather than quietly succeeding, so payees
///    are validated before any value moves and the caller gets a clean error
///    instead of a partly-paid batch.
///  * Native transfers emit Transfer events on Arc (EIP-7708), which is what
///    lets a receipt be rebuilt from the chain later instead of from a database.
///    Nothing here is responsible for that - it is a property of the chain - but
///    it is why the events below carry enough to be worth reading back.
///
/// The contract never holds a balance between calls: everything sent in is
/// distributed in the same transaction, and a single failed transfer reverts the
/// entire batch rather than leaving it half paid.
contract Manifest {
    /// @notice Number of batches this contract has settled. Doubles as the next
    /// batch id, so a receipt can be identified by (contract, batchId).
    uint256 public batches;

    /// @notice Emitted once per batch, before any value moves.
    event Batch(
        uint256 indexed batchId,
        address indexed payer,
        uint256 total,
        uint256 lines,
        string reference
    );

    /// @notice Emitted once per line, so a batch can be read back line by line.
    event Paid(
        uint256 indexed batchId,
        address indexed payer,
        address indexed payee,
        uint256 amount,
        string note
    );

    error EmptyManifest();
    error LengthMismatch(uint256 payees, uint256 amounts, uint256 notes);
    error PayeeIsZero(uint256 index);
    error AmountIsZero(uint256 index);
    error NotFullyFunded(uint256 required, uint256 sent);
    error PaymentFailed(uint256 index, address payee);

    /// @notice Settle a manifest. `msg.value` must equal the sum of `amounts`
    /// exactly: no residue is kept and nothing is refunded, so the amount the
    /// payer signs is the amount that reaches the payees.
    /// @param payees  Recipients, in order.
    /// @param amounts Amounts in the native unit, 18 decimals on Arc. One USDC is
    ///                1e18 - NOT 1e6, which is the habit this breaks.
    /// @param notes   A short note per line, for the receipt.
    /// @param reference A label for the whole batch, for the receipt.
    /// @return batchId The id of the settled batch, starting at 1.
    function pay(
        address[] calldata payees,
        uint256[] calldata amounts,
        string[] calldata notes,
        string calldata reference
    ) external payable returns (uint256 batchId) {
        uint256 n = payees.length;
        if (n == 0) revert EmptyManifest();
        if (amounts.length != n || notes.length != n) {
            revert LengthMismatch(n, amounts.length, notes.length);
        }

        uint256 required;
        for (uint256 i; i < n; ++i) {
            if (payees[i] == address(0)) revert PayeeIsZero(i);
            if (amounts[i] == 0) revert AmountIsZero(i);
            required += amounts[i];
        }
        // Exact funding only. Accepting more would strand value in a contract
        // that has no way to return it; accepting less would strand a payee.
        if (msg.value != required) revert NotFullyFunded(required, msg.value);

        batchId = ++batches;
        emit Batch(batchId, msg.sender, required, n, reference);

        for (uint256 i; i < n; ++i) {
            (bool ok, ) = payees[i].call{value: amounts[i]}("");
            if (!ok) revert PaymentFailed(i, payees[i]);
            emit Paid(batchId, msg.sender, payees[i], amounts[i], notes[i]);
        }
    }

    /// @notice Sum of a manifest, so a caller can compute the exact `msg.value`
    /// to send. Mirrors the check inside `pay`.
    function totalOf(uint256[] calldata amounts) external pure returns (uint256 sum) {
        for (uint256 i; i < amounts.length; ++i) {
            sum += amounts[i];
        }
    }
}
