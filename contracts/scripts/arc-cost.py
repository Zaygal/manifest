#!/usr/bin/env python3
"""Ask Arc mainnet what this contract costs to deploy, in USDC.

Gas on Arc is paid in USDC, and the mempool enforces a 20 Gwei maxFeePerGas
floor, so the cost of a deployment is a knowable number rather than an estimate.
CI runs this before anything is deployed so that nobody funds a wallet from a
guess when the chain will answer exactly, for free.

Usage:  python3 scripts/arc-cost.py <file containing the creation bytecode>
"""

import json
import sys
import urllib.request

RPC = "https://rpc.mainnet.arc.io"
FLOOR_WEI = 20_000_000_000      # Arc's maxFeePerGas floor, in wei
BATCH_GAS_3_LINES = 186_579     # measured by contracts/test/Manifest.t.sol


def rpc(method, params):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    req = urllib.request.Request(
        RPC,
        body,
        {
            "Content-Type": "application/json",
            # The public endpoint refuses requests that look like a bare script.
            "User-Agent": "manifest-cost-check/1.0",
        },
    )
    with urllib.request.urlopen(req, timeout=30) as fh:
        return json.load(fh)


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "bytecode.txt"
    try:
        with open(path) as fh:
            bytecode = fh.read().strip()
    except OSError as exc:
        print("could not read the bytecode: %s" % exc)
        return 0

    if not bytecode.startswith("0x"):
        bytecode = "0x" + bytecode
    print("initcode: %d bytes" % ((len(bytecode) - 2) // 2))

    try:
        out = rpc("eth_estimateGas", [{"data": bytecode}])
    except Exception as exc:                      # noqa: BLE001 - report, never fail CI
        print("could not reach Arc: %s" % exc)
        return 0

    if "error" in out:
        print("estimate failed: %s" % str(out["error"])[:200])
        return 0

    gas = int(out["result"], 16)

    def usdc(g):
        return g * FLOOR_WEI / 1e18

    print()
    print("  COST ON ARC MAINNET")
    print("  deploy gas .................... {:,}".format(gas))
    print("  deploy at the 20 Gwei floor ... %.8f USDC" % usdc(gas))
    print("  one 3-line batch .............. %.8f USDC" % usdc(BATCH_GAS_3_LINES))
    print("  deploy plus 3 batches ......... %.8f USDC" % usdc(gas + 3 * BATCH_GAS_3_LINES))
    return 0


if __name__ == "__main__":
    sys.exit(main())
