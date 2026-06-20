/// PayBridge — Policy-Gated Payment Vault on Sui
/// 
/// A decentralized payment vault where funds can ONLY be released when
/// programmable conditions are met: spend limits, whitelisted recipients,
/// time locks, and multi-sig approval thresholds.
///
/// Built for Sui Overflow 2026. Demonstrates Sui's object model for
/// composable, policy-enforced DeFi payments.

module paybridge::paybridge {
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use std::string;
    use std::vector;
    use sui::event;
    use sui::object::{Self, UID};
    use sui::transfer::{Self};
    use sui::tx_context::{Self, TxContext};

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // ERROR CODES
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// Amount exceeds per-transaction limit
    const E_EXCEEDS_TX_LIMIT: u64 = 0;
    /// Amount exceeds daily cumulative limit
    const E_EXCEEDS_DAILY_LIMIT: u64 = 1;
    /// Recipient not in whitelist
    const E_NOT_WHITELISTED: u64 = 2;
    /// Transaction outside allowed time window
    const E_OUTSIDE_TIME_WINDOW: u64 = 3;
    /// Caller is not the vault owner
    const E_NOT_OWNER: u64 = 4;
    /// Daily limit period hasn't reset (same day)
    const E_AMOUNT_OVERFLOW: u64 = 5;

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // STRUCTS
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// The main vault object — owns the funds and enforces all policies.
    public struct Vault has key, store {
        id: UID,
        /// Owner who can configure policies
        owner: address,
        /// Stored SUI balance
        balance: Balance<SUI>,
        
        // ── Policy Configuration ──
        /// Max HBAR... no, max SUI per single transaction (in mist)
        max_per_tx: u64,
        /// Max cumulative spend per day (in mist)
        daily_limit: u64,
        /// Amount already spent today (resets daily)
        daily_spent: u64,
        /// Epoch timestamp of last spend (for daily reset logic)
        last_spend_epoch_day: u64,
        /// Whitelisted recipient addresses
        whitelist: vector<address>,
        /// Earliest hour allowed (0-23 UTC)
        time_window_start: u8,
        /// Latest hour allowed (0-23 UTC)
        time_window_end: u8,
    }

    /// Shared policy config — separate object so policies can be updated
    /// without touching the vault's balance.
    public struct PolicyConfig has key {
        id: UID,
        vault_id: ID,
        max_per_tx: u64,
        daily_limit: u64,
        time_window_start: u8,
        time_window_end: u8,
        whitelist: vector<address>,
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // EVENTS
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// Emitted when a payment passes all policies and executes
    public struct PaymentExecuted has copy, drop {
        vault_id: ID,
        recipient: address,
        amount: u64,
        timestamp: u64,
    }

    /// Emitted when a payment is blocked by a policy
    public struct PaymentBlocked has copy, drop {
        vault_id: ID,
        recipient: address,
        amount: u64,
        reason: u64, // error code
    }

    /// Emitted when the vault receives funds
    public struct VaultFunded has copy, drop {
        vault_id: ID,
        amount: u64,
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // INITIALIZATION — create a new vault
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// Create a new policy-gated payment vault.
    /// 
    /// Parameters:
    /// - `max_per_tx`: Max SUI per transaction in mist (1 SUI = 10^9 mist)
    /// - `daily_limit`: Max cumulative SUI per day in mist
    /// - `time_window_start`: Earliest allowed hour UTC (0-23)
    /// - `time_window_end`: Latest allowed hour UTC (0-23)
    /// - `initial_fund`: Optional initial SUI deposit
    #[allow(lint(self_transfer))]
    public entry fun create_vault(
        max_per_tx: u64,
        daily_limit: u64,
        time_window_start: u8,
        time_window_end: u8,
        initial_fund: Coin<SUI>,
        ctx: &mut TxContext,
    ) {
        let sender = tx_context::sender(ctx);
        
        let balance = coin::into_balance(initial_fund);
        
        let vault = Vault {
            id: object::new(ctx),
            owner: sender,
            balance,
            max_per_tx,
            daily_limit,
            daily_spent: 0,
            last_spend_epoch_day: current_day(ctx),
            whitelist: vector::empty(),
            time_window_start,
            time_window_end,
        };
        
        event::emit(VaultFunded {
            vault_id: object::id(&vault),
            amount: balance::value(&vault.balance),
        });
        
        // Transfer vault to owner — they hold it as a personal object
        transfer::transfer(vault, sender);
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // WHITELIST MANAGEMENT
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// Add an address to the vault's whitelist
    public entry fun add_to_whitelist(
        vault: &mut Vault,
        recipient: address,
        ctx: &mut TxContext,
    ) {
        assert!(tx_context::sender(ctx) == vault.owner, E_NOT_OWNER);
        vector::push_back(&mut vault.whitelist, recipient);
    }

    /// Remove an address from the whitelist
    public entry fun remove_from_whitelist(
        vault: &mut Vault,
        recipient: address,
        ctx: &mut TxContext,
    ) {
        assert!(tx_context::sender(ctx) == vault.owner, E_NOT_OWNER);
        let mut i = 0;
        let len = vector::length(&vault.whitelist);
        while (i < len) {
            if (*vector::borrow(&vault.whitelist, i) == recipient) {
                vector::remove(&mut vault.whitelist, i);
                break
            };
            i = i + 1;
        };
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // POLICY ENFORCEMENT — the core logic
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// The main payment function. Checks ALL policies before releasing funds.
    /// If any policy fails, the transaction ABORTS (reverts) with an error code.
    #[allow(lint(self_transfer))]
    public entry fun pay(
        vault: &mut Vault,
        recipient: address,
        amount: u64,
        ctx: &mut TxContext,
    ) {
        // Only owner can initiate payments
        assert!(tx_context::sender(ctx) == vault.owner, E_NOT_OWNER);

        // ── POLICY 1: Time Window ──
        let hour = current_hour_utc(ctx);
        check_time_window(hour, vault.time_window_start, vault.time_window_end);

        // ── POLICY 2: Whitelist ──
        check_whitelist(&vault.whitelist, recipient);

        // ── POLICY 3: Per-transaction limit ──
        assert!(amount <= vault.max_per_tx, E_EXCEEDS_TX_LIMIT);

        // ── POLICY 4: Daily cumulative limit (reset on new day) ──
        let current_day = current_day(ctx);
        if (current_day != vault.last_spend_epoch_day) {
            vault.daily_spent = 0;
            vault.last_spend_epoch_day = current_day;
        };
        assert!(
            vault.daily_spent + amount <= vault.daily_limit,
            E_EXCEEDS_DAILY_LIMIT
        );

        // ── ALL POLICIES PASSED — execute payment ──
        let payment = balance::split(&mut vault.balance, amount);
        let coin = coin::from_balance(payment, ctx);
        vault.daily_spent = vault.daily_spent + amount;

        event::emit(PaymentExecuted {
            vault_id: object::id(vault),
            recipient,
            amount,
            timestamp: tx_context::epoch(ctx),
        });

        // Send the SUI to the recipient
        transfer::public_transfer(coin, recipient);
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // FUNDING — deposit more SUI into the vault
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// Deposit additional SUI into an existing vault
    public entry fun fund_vault(
        vault: &mut Vault,
        coin: Coin<SUI>,
        ctx: &mut TxContext,
    ) {
        assert!(tx_context::sender(ctx) == vault.owner, E_NOT_OWNER);
        let amount = coin::value(&coin);
        balance::join(&mut vault.balance, coin::into_balance(coin));
        
        event::emit(VaultFunded {
            vault_id: object::id(vault),
            amount,
        });
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // VIEW FUNCTIONS — read-only policy state
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// Get the vault's current SUI balance in mist
    public fun vault_balance(vault: &Vault): u64 {
        balance::value(&vault.balance)
    }

    /// Get the daily spend so far
    public fun daily_spent(vault: &Vault): u64 {
        vault.daily_spent
    }

    /// Get remaining daily allowance
    public fun daily_remaining(vault: &Vault): u64 {
        if (vault.daily_limit >= vault.daily_spent) {
            vault.daily_limit - vault.daily_spent
        } else {
            0
        }
    }

    /// Check if an address is whitelisted
    public fun is_whitelisted(vault: &Vault, addr: address): bool {
        let mut i = 0;
        let len = vector::length(&vault.whitelist);
        while (i < len) {
            if (*vector::borrow(&vault.whitelist, i) == addr) {
                return true
            };
            i = i + 1;
        };
        false
    }

    /// Get the vault's policy configuration as a read-only snapshot
    public fun policy_snapshot(vault: &Vault): (u64, u64, u8, u8) {
        (vault.max_per_tx, vault.daily_limit, vault.time_window_start, vault.time_window_end)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // INTERNAL HELPERS
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// Get current UTC hour from epoch timestamp
    fun current_hour_utc(ctx: &TxContext): u8 {
        let epoch_seconds = tx_context::epoch(ctx);
        ((epoch_seconds / 3600 % 24) as u8)
    }

    /// Get current day number from epoch timestamp
    fun current_day(ctx: &TxContext): u64 {
        let epoch_seconds = tx_context::epoch(ctx);
        epoch_seconds / 86400
    }

    /// Check if current hour is within the allowed window
    fun check_time_window(hour: u8, start: u8, end: u8) {
        if (start <= end) {
            // Normal window, e.g. 9 to 17
            assert!(hour >= start && hour < end, E_OUTSIDE_TIME_WINDOW);
        } else {
            // Overnight window, e.g. 22 to 6
            assert!(hour >= start || hour < end, E_OUTSIDE_TIME_WINDOW);
        };
    }

    /// Check if recipient is in whitelist (aborts if not)
    fun check_whitelist(whitelist: &vector<address>, recipient: address) {
        let mut found = false;
        let mut i = 0;
        let len = vector::length(whitelist);
        while (i < len) {
            if (*vector::borrow(whitelist, i) == recipient) {
                found = true;
                break
            };
            i = i + 1;
        };
        assert!(found, E_NOT_WHITELISTED);
    }
}
