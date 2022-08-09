module leizd::vault {

    use std::signer;
    use aptos_framework::coin;
    use aptos_framework::simple_map;
    use leizd::zusd;
    use leizd::collateral_coin;
    use leizd::debt_coin;

    const ENOT_PERMITED_COIN: u64 = 0;
    const EALREADY_INITIALIZED: u64 = 1;
    const EZERO_AMOUNT: u64 = 2;
    const ENOT_ENOUGH: u64 = 3;

    struct Vault<phantom T> has key {
        coin: coin::Coin<T>,
        map: simple_map::SimpleMap<address,u64>
    }

    public entry fun initialize(owner: &signer) {
        zusd::initialize(owner);
        collateral_coin::initialize<zusd::ZUSD>(owner);
        debt_coin::initialize<zusd::ZUSD>(owner);
    }

    public entry fun add_coin_type<T>(owner: &signer) {
        assert!(!exists<Vault<T>>(@leizd), EALREADY_INITIALIZED);
        move_to(owner, Vault<T> { coin: coin::zero<T>(), map: simple_map::create<address,u64>() });
    }

    public entry fun deposit<T>(account: &signer, amount: u64) acquires Vault {
        assert!(exists<Vault<T>>(@leizd), ENOT_PERMITED_COIN);

        let withdrawed = coin::withdraw<T>(account, amount);
        let pool = borrow_global_mut<Vault<T>>(@leizd);
        coin::merge(&mut pool.coin, withdrawed);

        let account_addr = signer::address_of(account);
        if (simple_map::contains_key<address,u64>(&mut pool.map, &account_addr)) {
            let map = simple_map::borrow_mut<address,u64>(&mut pool.map, &account_addr);
            *map = *map + amount;
        } else {
            simple_map::add<address,u64>(&mut pool.map, account_addr, amount);
        };
        
        zusd::mint(account, amount);
    }

    public entry fun withdraw<T>(account: &signer, amount: u64) acquires Vault {
        assert!(exists<Vault<T>>(@leizd), ENOT_PERMITED_COIN);
        assert!(amount > 0, EZERO_AMOUNT);

        let account_addr = signer::address_of(account);
        let pool_ref = borrow_global_mut<Vault<T>>(@leizd);
        assert!(coin::value<T>(&pool_ref.coin) >= amount, ENOT_ENOUGH);

        let deposited = coin::extract(&mut pool_ref.coin, amount);
        coin::deposit<T>(account_addr, deposited);

        assert!(simple_map::contains_key<address,u64>(&mut pool_ref.map, &account_addr), ENOT_PERMITED_COIN);
        let map = simple_map::borrow_mut<address,u64>(&mut pool_ref.map, &account_addr);
        *map = *map - amount;

        zusd::burn(account, amount);
    }

    public fun balance<T>(): u64 acquires Vault {
        let coin = &borrow_global<Vault<T>>(@leizd).coin;
        coin::value(coin)
    }

    public fun balance_of<T>(account_addr: address):u64 acquires Vault {
        let map = &borrow_global<Vault<T>>(@leizd).map;
        *simple_map::borrow<address,u64>(map, &account_addr)
    }
}