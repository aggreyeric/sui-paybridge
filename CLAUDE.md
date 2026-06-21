# CLAUDE.md — PayBridge on Sui

## Project Overview
Policy-gated payment vault on Sui. 4 on-chain Move policies (spend limit, whitelist, rate limit, time window) enforced before any SUI transfer.

## Tech Stack
- **Language:** Move 2024 (Sui)
- **Tests:** `sui move test` (4 unit tests)
- **Hackathon:** Sui Overflow 2026 ($500K pool)

## Commands
```bash
sui move build        # Compile
sui move test         # Run 4 unit tests
sui move test --filter paybridge  # Run specific tests
```

## Architecture
- `sources/paybridge.move` — Main module with policy enforcement logic
- `tests/paybridge_tests.move` — Unit tests for all 4 policies
- `Move.toml` — Package manifest (edition 2024)

## Key Features
1. **Spend Limit** — Caps transfer amount per transaction
2. **Whitelist** — Only allow transfers to approved addresses
3. **Rate Limit** — Limits transfer frequency
4. **Time Window** — Restrict transfers to specific time periods

## Notes
- No external dependencies (pure Move)
- Tests verify each policy independently
- Built for Sui Overflow 2026 hackathon
