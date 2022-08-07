module leizd::bridge_coin_factory {

    use aptos_std::simple_map;
    use aptos_std::signer;
    use aptos_std::type_info;
    use aptos_framework::coin;
    use leizd::bridge_coin;

    const ENOT_PERMITED: u64 = 1;

    struct BridgeCoin {}

    struct BridgeCoinPool<phantom T> has key {
        coin: coin::Coin<T>
    }

    struct StableList has key {
        listed: simple_map::SimpleMap<vector<u8>, bool>
    }

    public entry fun initialize(owner: &signer) {
        move_to(owner, StableList { listed: simple_map::create<vector<u8>, bool>() });
    }

    public entry fun init_pool<T>(owner: &signer) {
        move_to(owner, BridgeCoinPool<T> { coin: coin::zero<T>()});
    }

    public entry fun add_stable(owner: &signer, coin_name: vector<u8>) acquires StableList {
        let owner_addr = signer::address_of(owner);
        assert!(owner_addr == @leizd, 0);
        let coin_list = &mut borrow_global_mut<StableList>(owner_addr).listed;
        simple_map::add<vector<u8>, bool>(coin_list, coin_name, true);
    }

    public entry fun mint<T>(account: &signer, amount: u64) acquires StableList, BridgeCoinPool {
        assert!(is_stable<T>(), 1);

        let withdrawed = coin::withdraw<T>(account, amount);
        let coin_ref = &mut borrow_global_mut<BridgeCoinPool<T>>(@leizd).coin;
        coin::merge(coin_ref, withdrawed);
        
        bridge_coin::mint(account, amount);
    }

    fun is_stable<T>(): bool acquires StableList {
        let type_info = type_info::type_of<T>();
        let coin_name = type_info::module_name(&type_info);
        let owner_addr = @leizd;
        let coin_list = &borrow_global<StableList>(owner_addr).listed;
        simple_map::contains_key<vector<u8>, bool>(coin_list, &coin_name)
    }
}