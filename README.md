# 🌉 PayBridge on Sui — Policy-Gated Payment Vault

**Built for [Sui Overflow 2026](https://overflow.sui.io)**

A decentralized payment vault on Sui where funds can **ONLY** be released when programmable conditions are met. Four on-chain policies enforce themselves before any SUI transfer executes.

> Every `pay()` call is validated against spend limits, recipient whitelists, and time windows — **before** a single token moves. If any policy fails, the transaction aborts (reverts).

## 🛡️ The 4 On-Chain Policies

| Policy | Enforces | Checkpoint |
|--------|----------|------------|
| **SpendLimit** | Per-transaction cap + daily cumulative cap | Pre-transfer |
| **Whitelist** | Transfers only to pre-approved addresses | Pre-transfer |
| **RateLimit** | Daily transaction counter (max N payments/day) | Pre-transfer |
| **TimeWindow** | Business-hours enforcement (UTC) | Pre-transfer |

## 🏗️ Architecture

```
User calls pay(vault, recipient, amount)
        │
        ▼
┌─ POLICY 1: TimeWindow ───────────────┐
│  Is current UTC hour within window?   │ → ❌ ABORT if outside
└───────────────────────────────────────┘
        │ PASS
        ▼
┌─ POLICY 2: Whitelist ────────────────┐
│  Is recipient in approved list?       │ → ❌ ABORT if not
└───────────────────────────────────────┘
        │ PASS
        ▼
┌─ POLICY 3: SpendLimit (per-tx) ──────┐
│  amount ≤ max_per_tx?                 │ → ❌ ABORT if exceeds
└───────────────────────────────────────┘
        │ PASS
        ▼
┌─ POLICY 4: DailyLimit (cumulative) ──┐
│  daily_spent + amount ≤ daily_limit?  │ → ❌ ABORT if exceeds
└───────────────────────────────────────┘
        │ ALL PASS
        ▼
   ✅ SUI transferred to recipient
   ✅ Event emitted (PaymentExecuted)
   ✅ Daily counter updated
```

## 🚀 Quick Start

```bash
# Install Sui CLI
brew install sui

# Clone
git clone https://github.com/aggreyeric/sui-paybridge.git
cd sui-paybridge

# Build
sui move build

# Run tests
sui move test
# Expected: 4/4 PASS

# Create a vault on testnet
sui client publish --gas-budget 100000000

# Then call create_vault with your policy params:
# - max_per_tx: 10 SUI (in mist: 10000000000)
# - daily_limit: 50 SUI
# - time_window: 0-24 (24/7) or 9-17 (business hours)
```

## 📦 Functions

### Entry Points
- `create_vault(max_per_tx, daily_limit, time_start, time_end, initial_fund)` — Create a new policy-gated vault
- `pay(vault, recipient, amount)` — Attempt a payment (all policies must pass)
- `fund_vault(vault, coin)` — Deposit more SUI
- `add_to_whitelist(vault, address)` — Approve a recipient
- `remove_from_whitelist(vault, address)` — Remove a recipient

### View Functions
- `vault_balance(vault)` — Current balance in mist
- `daily_spent(vault)` — Amount spent today
- `daily_remaining(vault)` — Remaining daily allowance
- `is_whitelisted(vault, address)` — Check whitelist status
- `policy_snapshot(vault)` — Read-only policy config

## 🎯 Why This Matters

Autonomous AI agents that move money need guardrails. PayBridge proves that **on-chain policy enforcement** can prevent an agent from exceeding its mandate — no matter what instructions it receives.

This is the same concept as our [PayGuard on Hedera](https://github.com/aggreyeric/payguard-agent), ported to Sui's Move language and object model. The vault is a **shared object** that enforces its own rules immutably.

## 🛠️ Tech Stack
- **Sui Move** (edition 2024)
- **Sui Object Model** — vaults are ownable, transferable objects
- **On-chain events** — every payment and block is logged

## License
MIT
