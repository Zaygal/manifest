# Manifest

**Pay everyone on the list, and give each of them the proof.**

A manifest is the list you send out with the goods — one document, many
destinations. To manifest is to make something real. And a manifest is the
original proof-of-delivery document: it travels with the shipment and comes back
stamped. That is this product, in one word.

Arc mainnet · chain ID 5042 · USDC is the native asset

---

## The problem this solves

Paying twenty people at once does not work on other chains:

- Multicall3 loses `msg.sender`, so a batch cannot prove who actually paid
- USDC is an ERC-20, so every transfer needs an `approve` first
- a native value transfer emits **no** event, so reconciliation means an indexer
- N transfers cost N transactions, which makes splitting small amounts uneconomic

Arc removes all four obstacles:

- **USDC is the native asset.** `msg.value` *is* dollars. No approvals, no
  `transferFrom`.
- **EIP-7708 makes every USDC movement emit a Transfer event** at the system
  emitter `0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE`. A whole address's payment
  history is readable with `eth_getLogs` and **no backend**.
- **Finality is sub-second**, so a receipt is true almost immediately.
- **Fees are USDC and predictable** — roughly 0.00042 USDC for a transfer — so
  small splits are finally worth doing.

## What Manifest is

Two halves, and the second one is the product:

1. **A batch payer.** Submit a list of (address, amount, note). One transaction
   pays everyone, each payment carrying its own note, each provably from the same
   payer.
2. **A receipt** each recipient can open, reconstructed from Arc's own event log
   rather than from any database we control. Nobody has to trust a screenshot.

## Status

In development. See `docs/DESIGN.md`.

## Build

Built and tested in CI. No local toolchain required.
