# WDATA

WDATA is a wrapped-token contract that lets users exchange native DATA for an
ERC-20-compatible representation at a one-to-one ratio. It is inspired by WETH9
and built on [Solady](https://github.com/Vectorized/solady)'s `ERC20`.

## Overview

| | |
|---|---|
| Name | `Wrapped DATA` |
| Symbol | `WDATA` |
| Decimals | 18 |
| Solidity | 0.8.23 (EVM `cancun`) |
| Base | `solady/tokens/ERC20` |

Deposits mint WDATA 1:1 with the native DATA sent; withdrawals burn WDATA and
return the native DATA. The contract holds the native DATA backing the supply,
so the WDATA total supply always equals the contract's native balance.

## Contract behavior

`src/WDATA.sol` implements:

- **`deposit()`** (`payable`) — mints `msg.value` WDATA to the caller and emits
  `Deposit`. Plain native transfers to the contract route here via `receive()`.
- **`withdraw(uint value)`** — burns `value` WDATA from the caller, forwards the
  same amount of native DATA back via a low-level call, and emits `Withdrawal`.
  Reverts with `DATATransferFailed` if the transfer fails.

It overrides four inherited functions:

- **`name()` / `symbol()`** — return the constants `"Wrapped DATA"` and `"WDATA"`.
- **`approve`** — reverts with `ERC20InvalidSpender` on self-approval.
- **`transfer` / `transferFrom`** — revert with `ERC20InvalidReceiver` when the
  recipient is the zero address or the WDATA contract itself.
- **`_givePermit2InfiniteAllowance()`** — returns `true`, granting the canonical
  Permit2 contract an infinite allowance on every holder's balance.

## Deployment

WDATA is deployed via a CREATE3 factory, so its address depends only on
`(factory, salt)` — not on the contract's init code:

- Factory: `0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf` (Story Protocol's Create3
  genesis predeploy; override with `CREATE3_FACTORY`)
- Salt: `keccak256("WDATA")`
- Deterministic address: `0xD18a56346227f25D1410F98f78234305660bB877`

```sh
forge script script/Deploy.s.sol:Deploy \
  --rpc-url https://aeneid.storyrpc.io \
  --account <keystore> --broadcast --legacy
```

The script deploys a `Create3` factory itself if none exists at the target, and
is idempotent — re-running against an already-deployed address is a no-op.

### Live smoke test

`script/Smoke.s.sol` sends real transactions against a live deployment: it
deposits a small amount, verifies the mint, then withdraws it so the broadcasting
account's balance is left unchanged (minus gas).

```sh
forge script script/Smoke.s.sol:Smoke \
  --rpc-url https://aeneid.storyrpc.io \
  --account aeneid --broadcast --legacy --with-gas-price 1gwei
```

Override the target with `WDATA_ADDRESS`, the deposit amount (wei) with
`SMOKE_AMOUNT`, and the gas reserve with `SMOKE_GAS_RESERVE`. Fund the sender at
the [Story Aeneid faucet](https://aeneid.faucet.story.foundation).

## Development

Built with [Foundry](https://book.getfoundry.sh/). Dependencies are git
submodules under `lib/`.

```sh
git submodule update --init --recursive   # fetch forge-std and solady
forge build
forge test
```

## Audit

A security review by Nethermind (NM-0663-0950, June 2026) reported no issues.
The report is in [`audit/`](audit/).

## License

GPL-3.0-only
