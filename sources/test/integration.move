module leizd::integration {

    #[test_only]
    struct USDC {}
    struct WETH {}
    struct UNI {}

    #[test_only]
    use aptos_std::signer;
    use aptos_framework::coin;
    use aptos_framework::managed_coin;
    use leizd::asset_pool;
    use leizd::bridge_coin_factory;
    use leizd::bridge_coin;
    use leizd::bridge_pool;
    use leizd::collateral_coin;

    #[test(owner=@leizd)]
    public entry fun test_init_by_owner(owner: signer) {
        // init coins
        init_usdc(&owner);
        init_weth(&owner);

        // list coins
        asset_pool::list_new_coin<USDC>(&owner);
        asset_pool::list_new_coin<WETH>(&owner);

        assert!(asset_pool::balance<USDC>() == 0, 0);
        assert!(asset_pool::balance<WETH>() == 0, 0);
    }

    #[test(owner=@leizd, account1=@0x1)]
    public entry fun test_deposit_asset(owner: signer, account1: signer) {
        init_usdc(&owner);
        asset_pool::list_new_coin<USDC>(&owner);

        let account1_addr = signer::address_of(&account1);
        managed_coin::register<USDC>(&account1);
        managed_coin::mint<USDC>(&owner, account1_addr, 100);
        assert!(coin::balance<USDC>(account1_addr) == 100, 0);

        asset_pool::deposit<USDC>(&account1, 10);
        assert!(coin::balance<USDC>(account1_addr) == 90, 0);
        assert!(asset_pool::balance<USDC>() == 10, 0);
        assert!(collateral_coin::balance<USDC>(account1_addr) == 10, 0);
    }

    #[test(owner=@leizd, account1=@0x1)]
    public entry fun test_deposit_stable(owner: signer, account1: signer) {
        init_usdc(&owner);

        // init bridge coin
        bridge_coin_factory::initialize(&owner);
        bridge_coin_factory::init_pool<USDC>(&owner);

        let account1_addr = signer::address_of(&account1);
        managed_coin::register<USDC>(&account1);
        managed_coin::mint<USDC>(&owner, account1_addr, 100);

        bridge_coin_factory::deposit<USDC>(&account1, 10);
        assert!(coin::balance<USDC>(account1_addr) == 90, 0);
        assert!(bridge_coin_factory::balance<USDC>() == 10, 0);
        assert!(bridge_coin::balance(account1_addr) == 10, 0);
    }

    #[test(owner=@leizd, account1=@0x1, account2=@0x2)]
    public entry fun test_deposit_bridge_coin(owner: signer, account1: signer, account2: signer) {
        init_usdc(&owner);
        init_uni(&owner);
        asset_pool::list_new_coin<USDC>(&owner);
        asset_pool::list_new_coin<UNI>(&owner);
        bridge_coin_factory::initialize(&owner);
        bridge_coin_factory::init_pool<USDC>(&owner);

        let account1_addr = signer::address_of(&account1);
        let account2_addr = signer::address_of(&account2);
        managed_coin::register<USDC>(&account1);
        managed_coin::mint<USDC>(&owner, account1_addr, 100);
        managed_coin::register<UNI>(&account2);
        managed_coin::mint<UNI>(&owner, account2_addr, 100);

        asset_pool::deposit<UNI>(&account2, 10);
        bridge_coin_factory::deposit<USDC>(&account1, 30);

        bridge_pool::deposit<USDC>(&account1, 10);
        assert!(bridge_pool::balance<USDC>() == 10, 0);
        assert!(bridge_pool::balance<UNI>() == 0, 0);
        assert!(bridge_coin::balance(account1_addr) == 20, 0);
    }

    fun init_usdc(account: &signer) {
        init_coin<USDC>(account, b"USDC", 6);
    }

    fun init_weth(account: &signer) {
        init_coin<WETH>(account, b"WETH", 18);
    }

    fun init_uni(account: &signer) {
        init_coin<UNI>(account, b"UNI", 18);
    }


    fun init_coin<T>(account: &signer, name: vector<u8>, decimals: u64) {
        managed_coin::initialize<T>(
            account,
            name,
            name,
            decimals,
            true
        );
        assert!(coin::is_coin_initialized<T>(), 0);
        managed_coin::register<T>(account);
    }
}