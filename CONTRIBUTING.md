# Contributing to PayBridge

Thanks for your interest! This is a Move 2024 project for Sui.

## Development Setup

```bash
# Install Sui CLI
cargo install --locked --git https://github.com/MystenLabs/sui.git --branch main sui

# Clone and build
git clone https://github.com/aggreyeric/sui-paybridge.git
cd sui-paybridge
sui move build
```

## Running Tests

```bash
sui move test
```

## Making Changes

1. Fork the repo
2. Create a feature branch
3. Make your changes
4. Ensure `sui move test` passes
5. Open a Pull Request

## Code Style

- Move 2024 edition
- Keep functions small and focused
- Add comments for policy logic
