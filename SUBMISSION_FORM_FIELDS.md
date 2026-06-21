# Submission Form Fields — PayBridge on Sui

## Hackathon
Sui Overflow 2026 (Devpost) — $500K prize pool

## Project Name
PayBridge — Policy-Gated Payment Vault on Sui

## Tagline
Four on-chain policies guard every SUI transfer — spend limits, whitelists, rate limits, and time windows enforced in Move.

## Description (3-4 paragraphs)
PayBridge is a policy-constrained payment vault written in Move 2024 for the Sui blockchain. Before any SUI transfer can execute, PayBridge evaluates four independent on-chain policies: a spend limit that caps per-transaction amounts, a whitelist that restricts recipients to approved addresses, a rate limiter that prevents rapid successive transfers, and a time window that confines transfers to designated periods.

Each policy is enforced at the smart-contract level — not by an off-chain service — which means the constraints are immutable, auditable, and impossible to bypass. The architecture separates policy configuration from transfer execution, so vault owners can adjust parameters without redeploying.

The implementation is minimal and dependency-free: pure Move with no external oracle or governance dependencies. All four policies have dedicated unit tests (4/4 passing) that verify edge cases like zero-amount transfers, unauthorized recipients, and rate-threshold violations.

## Tech Stack
- Move 2024 (Sui blockchain)
- sui move test framework
- Zero external dependencies

## Demo / Screenshots
Test output: `sui move test` — 4/4 tests passing

## GitHub URL
https://github.com/aggreyeric/sui-paybridge

## Test Results
4/4 Move unit tests passing

## Built For
- Sui Overflow 2026 — Agentic Web track
- Policy-enforced DeFi on Sui
