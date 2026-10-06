# Manifest

**Pay everyone on the list, and give each of them the proof.**

A manifest is the list you send out with the goods — one document, many
destinations. To manifest is to make something real. And a manifest is the
original proof-of-delivery document: it travels with the shipment and comes back
stamped. That is this product, in one word.

Arc mainnet · chain ID 5042 · USDC is the native asset

---

## Live on Arc mainnet

- **The app** — <https://zaygal.github.io/manifest/>
- **The contract** — `0xe0436a564d77ef02c3c7aec13253f050fd89bb6f`

It has settled a real batch. Three payments, one transaction, no approvals:

| | |
|---|---|
| transaction | [`0x328259da…8acc4d`](https://explorer.arc.io/tx/0x328259da76614fd8de1efb7f8b5a09c18128fc1df3a7dff6f05739f18e8acc4d) |
| paid | 0.01 `design work`, 0.02 `cover art`, 0.03 `translation` |
| cost | 86,452 gas — 0.00185872 USDC |

**A receipt anyone can open, with no wallet installed:**
<https://zaygal.github.io/manifest/?tx=0x328259da76614fd8de1efb7f8b5a09c18128fc1df3a7dff6f05739f18e8acc4d>

That is read from Arc's own logs in the browser. Nothing in it comes from a server
we run, because there isn't one.

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
   `?tx=<hash>` opens one; `&for=<address>` marks that person's own line.

## What it does not prove

Worth being exact about, because a receipt that overstates itself is worse than
none:

- The **amounts, recipients and block are read from the chain** and cannot be
  altered by us.
- The **notes are the payer's own words.** They are a claim, not a verified fact.
- A batch proves **who paid whom, and how much.** It says nothing about whether the
  work was done.

## Status

Deployed and working on Arc mainnet, and exercised: a real batch has settled and
its receipt reads correctly from a browser with no wallet. 11/11 contract tests run
in CI, which also measures the deploy cost against the live chain and refuses to
publish an ABI the site could not parse.

## Build

Built and tested in CI. No local toolchain required.
