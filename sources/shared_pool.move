module sibylla::shared_pool {

    use std::debug;
    use std::signer;
    use aptos_framework::coin;
    use sibylla::collateral_coin;
    use sibylla::debt_coin;
    use sibylla::price_oracle;

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
        debt_coin::initialize<T>(account);
        move_to(account, Pool<T> {coin: coin::zero<T>()});
    }

    public entry fun deposit<T>(account: &signer, amount: u64) acquires Pool {
        assert!(amount > 0, EZERO_AMOUNT);

        let withdrawed = coin::withdraw<T>(account, amount);
        let coin_ref = &mut borrow_global_mut<Pool<T>>(@sibylla).coin;
        coin::merge(coin_ref, withdrawed);
    
        collateral_coin::mint<T>(account, amount);
    }

    public fun deposited_value<T>(): u64 acquires Pool {
        let coin = &borrow_global<Pool<T>>(@sibylla).coin;
        coin::value(coin)
    }

    public fun withdraw<T>(account: &signer, amount: u64) acquires Pool {
        assert!(amount > 0, EZERO_AMOUNT);

        let dest_addr = signer::address_of(account);
        let pool_ref = borrow_global_mut<Pool<T>>(@sibylla);
        assert!(coin::value<T>(&pool_ref.coin) >= amount, ENOT_ENOUGH);

        let deposited = coin::extract(&mut pool_ref.coin, amount);
        coin::deposit<T>(dest_addr, deposited);

        collateral_coin::burn<T>(account, amount);
    }

    public fun borrow<T>(account: &signer, amount: u64) acquires Pool {
        
        let price = price_oracle::asset_price<T>();
        debug::print(&price);
        // TODO: validate health

        let dest_addr = signer::address_of(account);
        let pool_ref = borrow_global_mut<Pool<T>>(@sibylla);
        let deposited = coin::extract(&mut pool_ref.coin, amount);
        coin::deposit<T>(dest_addr, deposited);

        debt_coin::mint<T>(account, amount);
    }

    #[test_only]
    struct CoinA {}
    struct CoinB {}

    #[test_only]
    use aptos_framework::managed_coin;

    #[test(source=@0xfbd6fbf6fd3d3cda4d65c59de97900a4797a37419298aa4a5eeacda77b34e691, user1 = @0x1)]
    public entry fun test_deposit_and_withdraw(source: signer, user1: signer) acquires Pool {
        
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
        assert!(deposited_value<CoinA>() == 30, 0);

        deposit<CoinA>(&user1, 10);
        assert!(coin::balance<CoinA>(user_addr) == 60, 0);
        assert!(collateral_coin::balance<CoinA>(user_addr) == 40, 0);
        assert!(deposited_value<CoinA>() == 40, 0);

        deposit<CoinB>(&user1, 70);
        assert!(coin::balance<CoinB>(user_addr) == 30, 0);
        assert!(collateral_coin::balance<CoinB>(user_addr) == 70, 0);
        assert!(deposited_value<CoinB>() == 70, 0);

        withdraw<CoinA>(&user1, 40);
        assert!(coin::balance<CoinA>(user_addr) == 100, 0);
        assert!(collateral_coin::balance<CoinA>(user_addr) == 0, 0);
        assert!(deposited_value<CoinA>() == 0, 0);
        assert!(deposited_value<CoinB>() == 70, 0);
    }

    #[test(source=@0xfbd6fbf6fd3d3cda4d65c59de97900a4797a37419298aa4a5eeacda77b34e691, user1 = @0x1, user2 = @0x2)]
    public entry fun test_borrow(source: signer, user1: signer, user2: signer) acquires Pool {
        
        managed_coin::initialize<CoinA>(
            &source,
            b"CoinA",
            b"AAA",
            18,
            true
        );
        assert!(coin::is_coin_initialized<CoinA>(), 0);
        managed_coin::register<CoinA>(&user1);
        managed_coin::register<CoinA>(&user2);

        managed_coin::initialize<CoinB>(
            &source,
            b"CoinB",
            b"BBB",
            18,
            true
        );
        assert!(coin::is_coin_initialized<CoinB>(), 0);
        managed_coin::register<CoinB>(&user1);
        managed_coin::register<CoinB>(&user2);

        list_new_coin<CoinA>(&source);
        list_new_coin<CoinB>(&source);

        let user1_addr = signer::address_of(&user1);
        managed_coin::mint<CoinA>(&source, user1_addr, 100);
        assert!(coin::balance<CoinA>(user1_addr) == 100, 0);
        

        let user2_addr = signer::address_of(&user2);
        managed_coin::mint<CoinB>(&source, user2_addr, 100);
        assert!(coin::balance<CoinB>(user2_addr) == 100, 0);
        
        deposit<CoinA>(&user1, 30);
        assert!(coin::balance<CoinA>(user1_addr) == 70, 0);

        deposit<CoinB>(&user2, 50);
        assert!(coin::balance<CoinB>(user2_addr) == 50, 0);
        
        borrow<CoinA>(&user2, 10);
        assert!(coin::balance<CoinA>(user2_addr) == 10, 0);
        assert!(coin::balance<CoinB>(user2_addr) == 50, 0);
    }
}