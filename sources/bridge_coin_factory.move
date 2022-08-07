module leizd::bridge_coin_factory {

    use aptos_std::simple_map;
    use aptos_std::type_info;
    use aptos_framework::coin;
    use leizd::bridge_coin;
    use leizd::collateral_coin;
    use leizd::debt_coin;

    const ENOT_PERMITED: u64 = 1;

    struct StablePool<phantom T> has key {
        coin: coin::Coin<T>
    }

    struct StableList has key {
        listed: simple_map::SimpleMap<vector<u8>, bool>
    }

    public entry fun initialize(owner: &signer) {
        bridge_coin::initialize(owner);
        collateral_coin::initialize<bridge_coin::BridgeCoin>(owner);
        debt_coin::initialize<bridge_coin::BridgeCoin>(owner);
        move_to(owner, StableList { listed: simple_map::create<vector<u8>, bool>() });
    }

    public entry fun init_pool<T>(owner: &signer) acquires StableList {
        move_to(owner, StablePool<T> { coin: coin::zero<T>()});
        let coin_list = &mut borrow_global_mut<StableList>(@leizd).listed;
        let type_info = type_info::type_of<T>();
        let coin_name = type_info::module_name(&type_info);
        simple_map::add<vector<u8>, bool>(coin_list, coin_name, true);
    }

    public entry fun deposit<T>(account: &signer, amount: u64) acquires StableList, StablePool {
        assert!(is_stable<T>(), 1);

        let withdrawed = coin::withdraw<T>(account, amount);
        let coin_ref = &mut borrow_global_mut<StablePool<T>>(@leizd).coin;
        coin::merge(coin_ref, withdrawed);
        
        bridge_coin::mint(account, amount);
    }

    public entry fun withdraw<T>() {
        // TODO
    }

    fun is_stable<T>(): bool acquires StableList {
        let type_info = type_info::type_of<T>();
        let coin_name = type_info::module_name(&type_info);
        let owner_addr = @leizd;
        let coin_list = &borrow_global<StableList>(owner_addr).listed;
        simple_map::contains_key<vector<u8>, bool>(coin_list, &coin_name)
    }

    public fun balance<T>(): u64 acquires StablePool {
        let coin = &borrow_global<StablePool<T>>(@leizd).coin;
        coin::value(coin)
    }
}