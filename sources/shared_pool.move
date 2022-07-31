module sibylla::shared_pool {

    use std::signer;
    use aptos_framework::coin;
    use aptos_std::type_info;

    use sibylla::collateral_coin;

    const EZERO_AMOUNT: u64 = 0;
    const ENOT_INITIALIZED: u64 = 1;
    const EALREADY_LISTED: u64 = 2;

    public entry fun list_new_coin<T>(account: &signer) {
        assert!(coin::is_coin_initialized<T>(), ENOT_INITIALIZED);
        assert!(!collateral_coin::is_coin_initialized<T>(), EALREADY_LISTED);
        collateral_coin::initialize<T>(account);
    }

    public entry fun deposit<T>(account: &signer, amount: u64) {
        assert!(amount > 0, EZERO_AMOUNT);

        let type_info = type_info::type_of<T>();
        let coin_owner = type_info::account_address(&type_info);
        let withdrawed = coin::withdraw<T>(account, amount);
        coin::deposit<T>(coin_owner, withdrawed);

        let dest_addr = signer::address_of(account);
        collateral_coin::mint<T>(account, dest_addr, amount);
    }

    #[test_only]
    struct TestCoin {}

    #[test_only]
    use aptos_framework::managed_coin;

    #[test(source=@0xfbd6fbf6fd3d3cda4d65c59de97900a4797a37419298aa4a5eeacda77b34e691, user1 = @0x1)]
    public entry fun test_end_to_end(source: signer, user1: signer) {
        
        managed_coin::initialize<TestCoin>(
            &source,
            b"TestCoin",
            b"TEST",
            18,
            true
        );
        assert!(coin::is_coin_initialized<TestCoin>(), 0);
        
        managed_coin::register<TestCoin>(&source);
        managed_coin::register<TestCoin>(&user1);
        list_new_coin<TestCoin>(&source);

        let source_addr = signer::address_of(&source);
        let user_addr = signer::address_of(&user1);
        managed_coin::mint<TestCoin>(&source, user_addr, 100);
        assert!(coin::balance<TestCoin>(user_addr) == 100, 0);
        assert!(coin::balance<TestCoin>(source_addr) == 0, 1);

        deposit<TestCoin>(&user1, 30);
        assert!(coin::balance<TestCoin>(user_addr) == 70, 2);
        assert!(collateral_coin::balance<TestCoin>(user_addr) == 30, 3);
    }
}