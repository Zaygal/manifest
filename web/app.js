// Manifest - shared browser logic.
//
// No build step and no bundler: ethers is loaded from a CDN in the page, and CI
// publishes abi.json and bytecode.txt next to these files so the site always
// matches the contract that is in the repository.

const ARC = {
  chainId: '0x13b2',                       // 5042
  chainName: 'Arc',
  nativeCurrency: { name: 'USDC', symbol: 'USDC', decimals: 18 },
  rpcUrls: ['https://rpc.mainnet.arc.io'],
  blockExplorerUrls: ['https://explorer.arc.io'],
};

const EMITTER = '0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE';
const TRANSFER_TOPIC = '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef';

// USDC on Arc is the native asset, at 18 decimals - not the 6 that ERC-20 USDC
// uses everywhere else. Formatting with 6 would show a number off by 1e12.
const DECIMALS = 18;

const $ = (id) => document.getElementById(id);

function fmt(wei, places) {
  const n = Number(BigInt(wei)) / 1e18;
  return n.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: places === undefined ? 6 : places });
}

function short(a) { return a ? a.slice(0, 8) + '...' + a.slice(-6) : ''; }

function show(el, msg, cls) {
  if (!el) return;
  el.className = cls || 'err';
  el.textContent = msg;
}

async function provider() {
  if (!window.ethereum) throw new Error('No wallet found. This page has to be opened inside a wallet browser - see the note at the bottom.');
  return new ethers.BrowserProvider(window.ethereum, 'any');
}

async function connect() {
  const p = await provider();
  await p.send('eth_requestAccounts', []);
  try {
    await p.send('wallet_switchEthereumChain', [{ chainId: ARC.chainId }]);
  } catch (e) {
    // 4902 = the wallet does not know this chain yet.
    if (e.code === 4902 || (e.error && e.error.code === 4902) || /Unrecognized chain/i.test(e.message || '')) {
      await p.send('wallet_addEthereumChain', [ARC]);
    } else {
      throw e;
    }
  }
  const signer = await p.getSigner();
  return { provider: p, signer, address: await signer.getAddress() };
}

async function artifacts() {
  const [abi, bytecode, address] = await Promise.all([
    fetch('build/abi.json').then((r) => (r.ok ? r.json() : null)).catch(() => null),
    fetch('build/bytecode.txt').then((r) => (r.ok ? r.text() : null)).catch(() => null),
    fetch('address.txt').then((r) => (r.ok ? r.text() : null)).catch(() => null),
  ]);
  return {
    abi,
    bytecode: bytecode && bytecode.trim(),
    address: address && address.trim().length === 42 ? address.trim() : null,
  };
}

// Parse a manifest written as one line per person: address, amount, note
function parseLines(text) {
  const out = [];
  const bad = [];
  text.split('\n').forEach((raw, i) => {
    const line = raw.trim();
    if (!line || line.startsWith('#')) return;
    const parts = line.split(',');
    const payee = (parts[0] || '').trim();
    const amount = (parts[1] || '').trim();
    const note = parts.slice(2).join(',').trim();
    if (!/^0x[0-9a-fA-F]{40}$/.test(payee)) { bad.push({ line: i + 1, why: 'not an address' }); return; }
    if (payee.toLowerCase() === '0x0000000000000000000000000000000000000000') {
      bad.push({ line: i + 1, why: 'zero address (Arc reverts on these)' }); return;
    }
    const n = Number(amount);
    if (!isFinite(n) || n <= 0) { bad.push({ line: i + 1, why: 'amount must be more than zero' }); return; }
    out.push({ payee, amount, note, wei: ethers.parseUnits(amount, DECIMALS) });
  });
  return { lines: out, bad };
}

function totalWei(lines) { return lines.reduce((a, l) => a + l.wei, 0n); }

function lineTo(payee) { return '0x' + '0'.repeat(24) + payee.slice(2).toLowerCase(); }
