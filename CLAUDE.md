# CLAUDE.md — PayBridge on Sui

## Project Overview
Policy-gated payment vault on Sui. 4 on-chain Move policies enforced before any SUI transfer.

## Tech Stack
- **Language:** Move 2024 (Sui)
- **Platform:** Sui Network
- **Tests:** 4 Move unit tests (`sui move test`)

## Commands
```bash
# Run tests
sui move test

# Build
sui move build

# Publish (testnet)
sui client publish --gas-budget 100000000
```

## Architecture
- `sources/` — Move modules (policy enforcement logic)
- `tests/` — Move test files
- `Move.toml` — Package manifest (edition 2024)

## Key Features
- Spend limit policy
- Whitelist policy
- Rate limit policy
- Time window policy

## Hackathon Target
- Sui Overflow 2026 — $500K prize pool
