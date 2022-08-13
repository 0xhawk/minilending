#[test_only]
module leizd::integration {

    #[test_only]
    struct USDC {}
    struct WETH {}
    struct UNI {}

    #[test_only]
    use std::signer;
    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::managed_coin;
    use leizd::pool;
    use leizd::pool_type::{Asset,Shadow};

    #[test(owner=@leizd)]
    public entry fun test_init_by_owner(owner: signer) {
        // init account
        account::create_account(signer::address_of(&owner));

        // init coins
        init_usdc(&owner);
        init_weth(&owner);

        // list coins on the pool
        pool::init_pool<USDC>(&owner);
        pool::init_pool<WETH>(&owner);

        assert!(pool::total_deposits<USDC,Asset>() == 0, 0);
        assert!(pool::total_deposits<USDC,Shadow>() == 0, 0);
    }

    #[test(owner=@leizd,account1=@0x111)]
    public entry fun test_deposit_weth(owner: signer, account1: signer) {
        let owner_addr = signer::address_of(&owner);
        let account1_addr = signer::address_of(&account1);
        account::create_account(owner_addr);
        account::create_account(account1_addr);
        init_weth(&owner);
        managed_coin::register<WETH>(&account1);
        managed_coin::mint<WETH>(&owner, account1_addr, 1000000);
        assert!(coin::balance<WETH>(account1_addr) == 1000000, 0);

        pool::init_pool<WETH>(&owner);

        pool::deposit<WETH>(&account1, 800000, false, false);
        assert!(coin::balance<WETH>(account1_addr) == 200000, 0);
        assert!(pool::total_deposits<WETH,Asset>() == 800000, 0);
    }

    #[test(owner=@leizd,account1=@0x111)]
    public entry fun test_withdraw_weth(owner: signer, account1: signer) {
        let owner_addr = signer::address_of(&owner);
        let account1_addr = signer::address_of(&account1);
        account::create_account(owner_addr);
        account::create_account(account1_addr);
        init_weth(&owner);
        managed_coin::register<WETH>(&account1);
        managed_coin::mint<WETH>(&owner, account1_addr, 1000000);
        assert!(coin::balance<WETH>(account1_addr) == 1000000, 0);

        pool::init_pool<WETH>(&owner);
        pool::deposit<WETH>(&account1, 800000, false, false);

        pool::withdraw<WETH>(&account1, 800000, false, false);

        assert!(coin::balance<WETH>(account1_addr) == 1000000, 0);
        assert!(pool::total_deposits<WETH,Asset>() == 0, 0);
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