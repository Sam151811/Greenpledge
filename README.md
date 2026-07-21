# GreenPledge 🌱

**Stake-backed climate commitments.** Pledge a green action, bond ETH to it, and let loss aversion do the motivational work.

*Built solo in one night for the Remix AI Bootcamp Build Week — Global Resilience track.*

**Live demo:** https://sam151811.github.io/Greenpledge/
**Contract (Sepolia):** [`0xfE0fC32195120566cC33F4328525b32CE0683dD7`](https://sepolia.etherscan.io/address/0xfE0fC32195120566cC33F4328525b32CE0683dD7)
**Verified source:** [Sourcify](https://repo.sourcify.dev/11155111/0xfE0fC32195120566cC33F4328525b32CE0683dD7/) · [Blockscout](https://eth-sepolia.blockscout.com/address/0xfE0fC32195120566cC33F4328525b32CE0683dD7?tab=contract)

---

## The idea

Individual climate action fails for a well-documented behavioral reason: **good intentions are free.** Behavioral economics has a proven answer — commitment devices. People follow through when breaking a promise costs them something (Thaler & Sunstein; StickK).

GreenPledge puts that mechanism on-chain:

1. **Pledge** a green action ("cycle to campus all week", "meat-free for 7 days") and **stake ETH** on it, naming a verifier you trust.
2. **Kept it?** Your verifier attests → stake returned **+ a soulbound ERC-1155 impact credit** minted to you.
3. **Broke it?** Stake is automatically forwarded to a **climate fund**. Loss aversion, made concrete.
4. **Verifier ghosted?** After a 3-day grace window, you reclaim your stake (no credit). No one can grief you.

### Why the credits are soulbound — a deliberate economic choice

The core failure of voluntary carbon markets is **unverified credits becoming tradeable assets** (greenwashing by construction). GreenPledge credits are earned through *social* attestation, so the contract **blocks all transfers** — they are reputation badges, not offsets. Credits should only become tradeable when verification is cryptographic, which is exactly the roadmap below.

## Architecture

```
index.html  (vanilla JS + ethers.js v6)
    │  read-only via public Sepolia RPC — no wallet needed to browse
    │  writes via MetaMask (injected provider)
    ▼
GreenPledge.sol  (Solidity 0.8.24, OpenZeppelin ERC-1155 v5)
    ├─ createPledge(verifier, deadline, category, description) payable
    ├─ attest(pledgeId, success)        — verifier only, deadline + 3d grace
    ├─ reclaimExpired(pledgeId)         — creator only, after grace
    ├─ soulbound _update override       — credits cannot be transferred
    └─ events: PledgeCreated / PledgeResolved (indexed, subgraph-ready)
```

**Security notes:** custom errors, checks-effects-interactions on all ETH transfers, verifier ≠ creator enforced, stake bounded to `uint96`.

## How this build uses the bootcamp stack

| Workshop | Used how |
|---|---|
| **Remix IDE** | Contract written, compiled, tested (Remix VM), and deployed entirely in Remix; auto-verified via Sourcify/Blockscout on deploy |
| **The Graph** | Events designed subgraph-first (indexed `PledgeCreated`/`PledgeResolved`); `queries/greenpledge.subgraph` demonstrates the new in-IDE query format & "Create dApp from Subgraph Query" AI feature |
| **zkVerify** | The verification roadmap (below) — swap social attestation for hardware-signed data + Noir ZK proofs for measurable actions |
| **ENS / Enscribe** | Planned: name the contract (e.g. `pledge.greenpledge.eth`) so users never interact with a raw hex address |

## Run it yourself

No build step. Clone → open `index.html` in a browser. The ledger loads read-only from Sepolia immediately; connect MetaMask (Sepolia) to create pledges and attest.

To redeploy the contract: open `contracts/GreenPledge.sol` in [Remix](https://remix.ethereum.org), compile with Solidity ≥0.8.24, deploy with constructor args `(_climateFund address, _uri string)`, and update `CONTRACT_ADDRESS` at the top of `index.html`'s script.

## Roadmap

- **zkVerify integration** — for measurable pledges (energy reduction), replace social attestation with hardware-signed meter data proven via Noir circuits and verified through zkVerify's Kurier proxy, as demonstrated in the bootcamp's green-energy workshop. Only then do credits become candidates for tradeable offsets.
- **Live subgraph** — deploy the GreenPledge subgraph to The Graph's hosted studio for leaderboards ("most ETH bonded to nature pledges this month").
- **ENS naming** via Enscribe for contract trust and address-poisoning protection.
- **Charity registry** — replace the single climate-fund address with a curated on-chain registry the pledger picks from.

## License

MIT
