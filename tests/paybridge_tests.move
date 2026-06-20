#[test_only]
module paybridge::paybridge_tests {
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};
    use paybridge::paybridge;

    // Helper: create a funded coin for testing
    fun mint_test_coin(amount: u64, ctx: &mut TxContext): Coin<SUI> {
        let balance = balance::create_for_testing<SUI>(amount);
        coin::from_balance(balance, ctx)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // TEST: Vault creation succeeds
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    #[test]
    fun test_create_vault() {
        let mut ctx = tx_context::dummy();
        let fund = mint_test_coin(100_000_000_000, &mut ctx); // 100 SUI
        
        paybridge::create_vault(
            10_000_000_000,  // 10 SUI per tx
            50_000_000_000,  // 50 SUI per day
            0,               // 24/7
            24,
            fund,
            &mut ctx,
        );
        // If we get here without abort, vault was created successfully
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // TEST: Funding the vault
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    #[test]
    fun test_vault_funded() {
        let mut ctx = tx_context::dummy();
        let fund = mint_test_coin(100_000_000_000, &mut ctx); // 100 SUI
        
        paybridge::create_vault(
            10_000_000_000,
            50_000_000_000,
            0, 24,
            fund,
            &mut ctx,
        );
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // TEST: Business hours config
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    #[test]
    fun test_business_hours_config() {
        let mut ctx = tx_context::dummy();
        let fund = mint_test_coin(200_000_000_000, &mut ctx); // 200 SUI
        
        paybridge::create_vault(
            10_000_000_000,  // 10 SUI per tx
            100_000_000_000, // 100 SUI daily
            9, 17,           // business hours 9-5
            fund,
            &mut ctx,
        );
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // TEST: Small vault config
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    #[test]
    fun test_small_vault() {
        let mut ctx = tx_context::dummy();
        let fund = mint_test_coin(5_000_000_000, &mut ctx); // 5 SUI
        
        paybridge::create_vault(
            1_000_000_000,  // 1 SUI per tx
            3_000_000_000,  // 3 SUI daily
            0, 24,
            fund,
            &mut ctx,
        );
    }
}
