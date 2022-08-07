module sibylla::bridge_coin_factory {

    use aptos_std::simple_map;
    use aptos_std::signer;
    use aptos_std::type_info;
    use aptos_framework::coin;
    use sibylla::bridge_coin;

    struct BridgeCoin {}

    struct BridgeCoinPool<phantom T> has key {
        coin: coin::Coin<T>
    }

    struct BridgeCoinList has key {
        listed: simple_map::SimpleMap<vector<u8>, bool>
    }

    public entry fun initialize(account: &signer) {
        move_to(account, BridgeCoinList { listed: simple_map::create<vector<u8>, bool>() });
    }

    public entry fun add_bridge_coin(account: &signer, coin_name: vector<u8>) acquires BridgeCoinList {
        let account_addr = signer::address_of(account);
        assert!(account_addr == @sibylla, 0);
        let coin_list = &mut borrow_global_mut<BridgeCoinList>(account_addr).listed;
        simple_map::add<vector<u8>, bool>(coin_list, coin_name, true);
    }

    public entry fun mint<T>(account: &signer, amount: u64) acquires BridgeCoinList {
        let type_info = type_info::type_of<T>();
        let coin_name = type_info::module_name(&type_info);
        let owner_addr = @sibylla;
        let coin_list = &borrow_global<BridgeCoinList>(owner_addr).listed;
        assert!(simple_map::contains_key<vector<u8>, bool>(coin_list, &coin_name), 1);
        
        bridge_coin::mint(account, amount);
    }
}