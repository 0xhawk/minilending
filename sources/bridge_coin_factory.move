module leizd::bridge_coin_factory {

    use std::signer;
    use aptos_framework::coin;
    use aptos_framework::simple_map;
    use leizd::bridge_coin;
    use leizd::collateral_coin;
    use leizd::debt_coin;

    const ENOT_PERMITED_COIN: u64 = 1;
    const EALREADY_INITIALIZED: u64 = 2;

    struct StablePool<phantom T> has key {
        coin: coin::Coin<T>,
        map: simple_map::SimpleMap<address,u64>
    }

    public entry fun initialize(owner: &signer) {
        bridge_coin::initialize(owner);
        collateral_coin::initialize<bridge_coin::BridgeCoin>(owner);
        debt_coin::initialize<bridge_coin::BridgeCoin>(owner);
    }

    public entry fun init_pool<T>(owner: &signer) {
        assert!(!exists<StablePool<T>>(@leizd), EALREADY_INITIALIZED);
        move_to(owner, StablePool<T> { coin: coin::zero<T>(), map: simple_map::create<address,u64>() });
    }

    public entry fun deposit<T>(account: &signer, amount: u64) acquires StablePool {
        assert!(exists<StablePool<T>>(@leizd), ENOT_PERMITED_COIN);

        let withdrawed = coin::withdraw<T>(account, amount);
        let pool = borrow_global_mut<StablePool<T>>(@leizd);
        coin::merge(&mut pool.coin, withdrawed);

        let account_addr = signer::address_of(account);
        if (simple_map::contains_key<address,u64>(&mut pool.map, &account_addr)) {
            let map = simple_map::borrow_mut<address,u64>(&mut pool.map, &account_addr);
            *map = *map + amount;
        } else {
            simple_map::add<address,u64>(&mut pool.map, account_addr, amount);
        };
        
        bridge_coin::mint(account, amount);
    }

    public entry fun withdraw<T>() {
        // TODO
    }

    public fun balance<T>(): u64 acquires StablePool {
        let coin = &borrow_global<StablePool<T>>(@leizd).coin;
        coin::value(coin)
    }

    public fun balance_of<T>(account_addr: address):u64 acquires StablePool {
        let map = &borrow_global<StablePool<T>>(@leizd).map;
        *simple_map::borrow<address,u64>(map, &account_addr)
    }
}