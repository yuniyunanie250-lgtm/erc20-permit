# erc20-permit

An ERC-20 with EIP-2612 `permit`: approvals signed off-chain and submitted by a
third party.

Without permit, using a token takes two transactions: `approve`, then act. With
permit, the approval is a signature the user produces for free, and whoever
wants to move the tokens submits `permit` and the action together. That removes
one transaction from every swap, deposit and vault entry.

## How the signature is built

```
digest = keccak256(0x1901 || DOMAIN_SEPARATOR || structHash)
structHash = keccak256(PERMIT_TYPEHASH, owner, spender, value, nonce, deadline)
```

The domain separator binds the signature to this chain and this contract
address, so a signature for one deployment is useless on another. The per-owner
nonce is incremented inside `permit`, which makes a replayed signature fail.

## What it deliberately does not do

- **No `ecrecover` malleability guard.** A high-`s` signature would also verify;
  most auditors want `s <= secp256k1n/2` enforced. Add it before production use.
- **No EIP-2612 `DOMAIN_SEPARATOR` caching across chain forks** beyond
  recomputing when `block.chainid` changes; this version computes it once at
  deployment.
- **No ERC-20 extensions**: no burn, no capped supply, no pausing.

## Development

```bash
forge install foundry-rs/forge-std
forge test -vvv
```

## License

MIT
