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

## Static analysis: findings we accept, and why

CI reports four findings that describe the product rather than a defect. They are
documented in the source so that a reader knows they were weighed:

| Finding | Why it stands |
|---|---|
| `arbitrary-send-eth` | Sending native value to a caller-supplied address **is** the product. Value never rests in the contract. |
| `calls-loop` | The external call in a loop is the batching. Nothing is read back from a payee, so one line cannot influence the next. |
| `require-revert-in-loop` | Reverting mid-loop is the atomicity guarantee. Full settlement or none. |
| `reentrancy-events` | **Fixed, not accepted.** `Paid` is now emitted *before* the transfer, so log order always matches manifest order and a re-entrant payee cannot interleave its logs ahead of a line. |

Two further warnings were genuine dead code and were fixed: an uninitialised loop
counter that the linter read as a variable read before assignment, and an unused
tuple binding in the tests.

## Cost on Arc mainnet

Measured by asking the chain, not by working it out by hand
(`contracts/scripts/arc-cost.py`, run in CI):

```
deploy gas .................... 448,692
deploy at the 20 Gwei floor ... 0.00897384 USDC
one 3-line batch .............. 0.00373158 USDC
deploy plus 3 batches ......... 0.02016858 USDC
```

## Non-goals

- No custody. Funds move payer to recipient inside a single transaction; the
  contract never holds a balance between calls.
- No token, no points, no governance.
- No off-chain database. If the chain cannot show it, the product does not claim it.
