# Submission Form Fields — Sui PayBridge

> Built for **[Sui Overflow 2026](https://overflow.sui.io)** — Agentic Web track

---

## Project Name

**Sui PayBridge — Policy-Gated Payment Vault**

## One-Liner

> 4 on-chain Move policies gate every SUI transfer — spend limits, whitelists, rate limits, time windows.

## Description

### What it does

Sui PayBridge is a decentralized payment vault written in **Move 2024** for the Sui blockchain. It holds SUI and releases funds **only** when a configurable set of on-chain policies all pass. Before any token moves, every `pay()` call is validated against four independent policies — a **spend limit** (per-transaction cap plus a daily cumulative cap), a **recipient whitelist**, a **rate limit** (the daily cap bounds total flow per day), and a **time window** (e.g. business-hours-only in UTC). If any single policy fails, the Move transaction aborts and reverts — no partial state, no off-chain workaround. The vault is a Sui object the owner configures once; from that point the rules enforce themselves immutably on-chain.

### Why it matters

Autonomous AI agents and treasury managers that move money need **guardrails they cannot bypass**. Today, most "policy" on payment rails lives in off-chain middleware or a backend service — a compromised prompt, a stolen API key, or a misconfigured agent can drain a wallet before anyone notices. PayBridge proves that the enforcement itself can live on-chain: the same instructions that tell an agent to pay *cannot override* the vault's limits, because the policy check is part of the Move transaction that moves the coins. This is the same trust model as our [PayGuard on Hedera](https://github.com/aggreyeric/payguard-agent), now ported to Sui's object model — composable, auditable, and trustless. For DeFi treasuries, agent payment rails, and custody scenarios, it turns "we hope the agent behaves" into "the chain mathematically prevents misbehavior."

### How it works

When a caller invokes `pay(vault, recipient, amount)`, the contract runs a fixed pre-transfer checkpoint pipeline: **(1) TimeWindow** checks the current UTC hour falls inside `[start, end)`; **(2) Whitelist** verifies the recipient is in the approved address vector; **(3) SpendLimit** asserts `amount ≤ max_per_tx`; **(4) DailyLimit** rolls the counter over on a new UTC day and asserts `daily_spent + amount ≤ daily_limit`. Only when all four pass does `balance::split` carve the payment out and `public_transfer` send the SUI to the recipient — emitting a `PaymentExecuted` event and updating `daily_spent`. Failures abort with a distinct error code (`E_OUTSIDE_TIME_WINDOW`, `E_NOT_WHITELISTED`, `E_EXCEEDS_TX_LIMIT`, `E_EXCEEDS_DAILY_LIMIT`), which is surfaced for monitoring via the `PaymentBlocked` event path. The owner manages whitelist membership and funds the vault through dedicated entry points; policy config is set at `create_vault` time. There are **zero external dependencies** — pure Sui Move, no oracles, no governance modules.

## Tech Stack

- **Move 2024** (Sui edition)
- **Sui Network** (object model, `Coin<SUI>` / `Balance<SUI>`, on-chain events)
- No external dependencies — pure Move 2024 stdlib + `sui` framework

## Test Results

```
sui move test
```

**4/4 Move tests passing** — covering vault creation (24/7 and business-hours configs), vault funding, and small-vault edge cases.

```
Running Move unit tests
[ PASS    ] paybridge::paybridge_tests::test_business_hours_config
[ PASS    ] paybridge::paybridge_tests::test_create_vault
[ PASS    ] paybridge::paybridge_tests::test_small_vault
[ PASS    ] paybridge::paybridge_tests::test_vault_funded
Test result: OK. Total tests: 4; passed: 4; failed: 0
```

## GitHub URL

https://github.com/aggreyeric/sui-paybridge

## Demo / Build & Publish (Sui testnet)

```bash
# 1. Clone
git clone https://github.com/aggreyeric/sui-paybridge.git
cd sui-paybridge

# 2. Build
sui move build

# 3. Test (4/4 passing)
sui move test

# 4. Publish to Sui testnet
sui client publish --gas-budget 100000000

# 5. Create a vault and exercise the policies
#    create_vault(max_per_tx=10 SUI, daily_limit=50 SUI,
#                 time_window 0-24, initial_fund)
#    mint values in mist: 1 SUI = 1_000_000_000
```

**Demo flow:** publish the package on Sui testnet → call `create_vault` with chosen policy params → `add_to_whitelist` an approved recipient → call `pay()` (passes) → attempt `pay()` to a non-whitelisted address or above the per-tx cap (aborts with the matching error code).

## License

MIT
