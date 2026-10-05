# Design

## Shape

`PayoutBatch.pay(address[] recipients, uint256[] amounts, string note)` payable.

- requires `msg.value == sum(amounts)` — no partial funding, no residue
- one native value transfer per recipient
- emits `Paid(batchId, payer, recipient, amount, note, index)` per recipient
- reverts the whole batch if any single transfer fails

One transaction. N payments. Each one attributable to the payer because the payer
is `msg.sender` of the batch.

## Why the receipt is the product

The batch contract is replaceable. The receipt is not.

A receipt is derived from:
1. the emitter's unified `Transfer` events (EIP-7708) for the amount actually moved
2. the batch's own `Paid` event for the note and the batch identity

Because of (1), a receipt works for **any** USDC payment on Arc — not only ones
that went through this contract. That is the point: on other chains, the party who
was paid has to trust the payer's screenshot, because a native transfer leaves no
trace in any log.

## Arc-specific details that are load-bearing

- **USDC is native and 18 decimals.** The ERC-20 view at
  `0x3600000000000000000000000000000000000000` also reports 18 decimals. Any code
  assuming 6 silently misprices by 10^12. This is guarded and tested explicitly.
- **The mempool enforces a 20 Gwei `maxFeePerGas` floor.** Fee estimation must not
  submit below it or the transaction is refused.
- **`address(0)` sends revert** rather than succeeding, unlike some chains, so the
  recipient list is validated up front rather than mid-batch.
- **A blocklist revert consumes gas without producing a receipt**, so batch
  verification never infers success from a missing receipt.

## Non-goals

- No custody. Funds move payer to recipient inside a single transaction; the
  contract never holds a balance between calls.
- No token, no points, no governance.
- No off-chain database. If the chain cannot show it, the product does not claim it.
