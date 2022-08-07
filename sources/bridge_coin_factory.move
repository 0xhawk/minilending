module leizd::bridge_coin_factory {

    use aptos_framework::coin;
    use leizd::bridge_coin;
    use leizd::collateral_coin;
    use leizd::debt_coin;

    const ENOT_PERMITED_COIN: u64 = 1;
    const EALREADY_INITIALIZED: u64 = 2;

    struct StablePool<phantom T> has key {
        coin: coin::Coin<T>
    }

    public entry fun initialize(owner: &signer) {
        bridge_coin::initialize(owner);
        collateral_coin::initialize<bridge_coin::BridgeCoin>(owner);
        debt_coin::initialize<bridge_coin::BridgeCoin>(owner);
    }

    public entry fun init_pool<T>(owner: &signer) {
        assert!(!exists<StablePool<T>>(@leizd), EALREADY_INITIALIZED);
        move_to(owner, StablePool<T> { coin: coin::zero<T>()});
    }

    public entry fun deposit<T>(account: &signer, amount: u64) acquires StablePool {
        assert!(exists<StablePool<T>>(@leizd), ENOT_PERMITED_COIN);

        let withdrawed = coin::withdraw<T>(account, amount);
        let coin_ref = &mut borrow_global_mut<StablePool<T>>(@leizd).coin;
        coin::merge(coin_ref, withdrawed);
        
        bridge_coin::mint(account, amount);
    }

    public entry fun withdraw<T>() {
        // TODO
    }

    public fun balance<T>(): u64 acquires StablePool {
        let coin = &borrow_global<StablePool<T>>(@leizd).coin;
        coin::value(coin)
    }
}