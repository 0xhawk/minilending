module sibylla::shared_pool {

    use std::signer;
    use aptos_framework::coin;

    use sibylla::collateral_coin;

    const EZERO_AMOUNT: u64 = 0;
    const ENOT_INITIALIZED: u64 = 1;
    const EALREADY_LISTED: u64 = 2;
    const ENOT_ENOUGH: u64 = 3;

    struct Pool<phantom T> has key {
        coin: coin::Coin<T>
    }

    public entry fun list_new_coin<T>(account: &signer) {
        assert!(coin::is_coin_initialized<T>(), ENOT_INITIALIZED);
        assert!(!collateral_coin::is_coin_initialized<T>(), EALREADY_LISTED);
        collateral_coin::initialize<T>(account);
    }

    public entry fun deposit<T>(account: &signer, amount: u64) acquires Pool {
        assert!(amount > 0, EZERO_AMOUNT);

        let withdrawed = coin::withdraw<T>(account, amount);
        let dest_addr = signer::address_of(account);
        if (exists<Pool<T>>(dest_addr)) {
            let coin_ref = &mut borrow_global_mut<Pool<T>>(dest_addr).coin;
            coin::merge(coin_ref, withdrawed);
        } else {
            let pool = Pool<T> {coin: withdrawed};
            move_to(account, pool);
        };
        
        collateral_coin::mint<T>(account, amount);
    }

    public fun deposited_value<T>(owner: address): u64 acquires Pool {
        let coin = &borrow_global<Pool<T>>(owner).coin;
        coin::value(coin)
    }

    public fun withdraw<T>(account: &signer, amount: u64) acquires Pool {
        assert!(amount > 0, EZERO_AMOUNT);

        let dest_addr = signer::address_of(account);
        let pool_ref = borrow_global_mut<Pool<T>>(dest_addr);
        assert!(coin::value<T>(&pool_ref.coin) >= amount, ENOT_ENOUGH);

        let deposited = coin::extract(&mut pool_ref.coin, amount);
        coin::deposit<T>(dest_addr, deposited);

        collateral_coin::burn<T>(account, amount);
    }

    #[test_only]
    struct CoinA {}
    struct CoinB {}

    #[test_only]
    use aptos_framework::managed_coin;

    #[test(source=@0xfbd6fbf6fd3d3cda4d65c59de97900a4797a37419298aa4a5eeacda77b34e691, user1 = @0x1)]
    public entry fun test_end_to_end(source: signer, user1: signer) acquires Pool {
        
        managed_coin::initialize<CoinA>(
            &source,
            b"CoinA",
            b"AAA",
            18,
            true
        );
        assert!(coin::is_coin_initialized<CoinA>(), 0);
        managed_coin::register<CoinA>(&source);
        managed_coin::register<CoinA>(&user1);

        managed_coin::initialize<CoinB>(
            &source,
            b"CoinB",
            b"BBB",
            18,
            true
        );
        assert!(coin::is_coin_initialized<CoinB>(), 0);
        managed_coin::register<CoinB>(&source);
        managed_coin::register<CoinB>(&user1);

        list_new_coin<CoinA>(&source);
        list_new_coin<CoinB>(&source);

        let source_addr = signer::address_of(&source);
        let user_addr = signer::address_of(&user1);

        managed_coin::mint<CoinA>(&source, user_addr, 100);
        assert!(coin::balance<CoinA>(user_addr) == 100, 0);
        assert!(coin::balance<CoinA>(source_addr) == 0, 0);

        managed_coin::mint<CoinB>(&source, user_addr, 100);
        assert!(coin::balance<CoinB>(user_addr) == 100, 0);

        deposit<CoinA>(&user1, 30);
        assert!(coin::balance<CoinA>(user_addr) == 70, 0);
        assert!(collateral_coin::balance<CoinA>(user_addr) == 30, 0);
        assert!(deposited_value<CoinA>(user_addr) == 30, 0);

        deposit<CoinA>(&user1, 10);
        assert!(coin::balance<CoinA>(user_addr) == 60, 0);
        assert!(collateral_coin::balance<CoinA>(user_addr) == 40, 0);
        assert!(deposited_value<CoinA>(user_addr) == 40, 0);

        deposit<CoinB>(&user1, 70);
        assert!(coin::balance<CoinB>(user_addr) == 30, 0);
        assert!(collateral_coin::balance<CoinB>(user_addr) == 70, 0);
        assert!(deposited_value<CoinB>(user_addr) == 70, 0);

        withdraw<CoinA>(&user1, 40);
        assert!(coin::balance<CoinA>(user_addr) == 100, 0);
        assert!(collateral_coin::balance<CoinA>(user_addr) == 0, 0);
        assert!(deposited_value<CoinA>(user_addr) == 0, 0);
        assert!(deposited_value<CoinB>(user_addr) == 70, 0);
    }
}