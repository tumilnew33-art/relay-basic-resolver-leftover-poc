# PoC: BasicCallResolver.execute is permissionless — any retained balance is drainable by anyone

Relay bug bounty report R-05. Run with Foundry (tested with forge 1.9.0):

```
forge test -vv
```

No setup, no network, no fork needed. All dependencies are vendored under `lib/`
(the settlement contracts are the unmodified sources from
`relayprotocol/relay-settlement` at commit `b2f3e0e`).

## What it proves (1/1 test passes)

- **ATTACK** `test_anyoneSweepsLeftover`: a leftover Hub balance of 1000 units
  of token 1 sits in the real, unmodified `BasicCallResolver` (e.g. a token
  the solver's sweep list omitted during a prior execution). An unrelated EOA
  holding no role anywhere calls the permissionless `execute()` with empty
  `calls` and a single sweep `{recipient: attacker, tokenId: 1}` — and
  receives the full 1000-unit leftover. The resolver's balance goes to 0.

The funding + `execute` call are atomic inside `RelayExecutor.execute`, so
there is no front-running window *during* an execution; this PoC targets the
post-execution leftover window, which is permanent: the resolver has no
sweep/rescue function of its own, so leftovers sit until someone calls
`execute()` — and anyone can.

This was independently reproduced in the executor-frontrun PoC
(`testBasicCallResolverRetainedFundsAreDrainable`): 50 tokens drained by an
unrelated EOA from the same real contracts.

## Setup notes

- Uses the real, unmodified `BasicCallResolver` and `RelayHub`; the leftover
  is simulated with `hub.mint` to the resolver, standing in for a balance a
  prior execution left behind.
- Honest-scope note: in honest flows the exposure is dust — the resolver is
  funded per-execution and swept in the same call. The drain is limited to
  whatever balance happens to be left in the resolver; it holds no Hub roles.
- Local test only; nothing here touches mainnet.
