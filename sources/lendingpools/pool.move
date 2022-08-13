module leizd::pool {

    use std::signer;
    use aptos_framework::coin;
    use leizd::collateral;
    use leizd::collateral_only;
    use leizd::debt;
    use leizd::repository;
    use leizd::pool_type::{Asset,Shadow};

    // TODO: util
    const U64_MAX: u64 = 18446744073709551615;

    struct Pool<phantom C> has key {
        asset: coin::Coin<C>,
        shadow: coin::Coin<ZUSD>,
    }

    struct Storage<phantom C, phantom P> has key {
        total_deposits: u128,
        total_collateral_only_deposits: u128,
        total_borrows: u128
    }

    // TODO: friend
    public entry fun init_pool<C>(owner: &signer) {
        move_to(owner, Pool<C> {
            asset: coin::zero<C>(),
            shadow: coin::zero<ZUSD>()
        });
        move_to(owner, Storage<C,Asset> {
            total_deposits: 0,
            total_collateral_only_deposits: 0,
            total_borrows: 0
        });
        move_to(owner, Storage<C,Shadow> {
            total_deposits: 0,
            total_collateral_only_deposits: 0,
            total_borrows: 0
        });

        collateral::initialize<C>(owner);
        collateral_only::initialize<C>(owner);
        debt::initialize<C>(owner);
    }

    // util
    fun to_share(amount: u128, total_amount: u128, total_shares: u128): u64 {
        if (total_shares == 0 || total_amount == 0) {
            (amount as u64)
        } else {
            let result = amount * total_shares / total_amount;
            assert!(result != 0 || amount == 0, 0);
            (result as u64)
        }
    }

    public entry fun deposit<C>(account: &signer, amount: u64, is_collateral_only: bool, is_shadow: bool) acquires Pool, Storage {
        if (is_shadow) {
            deposit_shadow<C>(account, amount, is_collateral_only);
        } else {
            deposit_asset<C>(account, amount, is_collateral_only);
        };
    }

    public entry fun withdraw<C>(account: &signer, amount: u64, is_collateral_only: bool, is_shadow: bool) acquires Pool, Storage {
        if (is_shadow) {
            withdraw_shadow<C>(account, amount, is_collateral_only);
        } else {
            withdraw_asset<C>(account, amount, is_collateral_only);
        };
    }

    public entry fun borrow<C>(account: &signer, amount: u64, is_shadow: bool) acquires Pool, Storage {
        if (is_shadow) {
            borrow_shadow<C>(account, amount);
        } else {
            borrow_asset<C>(account, amount);
        };
    }
    

    public entry fun deposit_asset<C>(account: &signer, amount: u64, is_collateral_only: bool): (u64, u64) acquires Pool, Storage {
        let asset_storage_ref = borrow_global_mut<Storage<C,Asset>>(@leizd);
        let pool_ref = borrow_global_mut<Pool<C>>(@leizd);

        let withdrawn = coin::withdraw<C>(account, amount);
        coin::merge(&mut pool_ref.asset, withdrawn);
        deposit_internal<C,Asset>(account, amount, is_collateral_only, asset_storage_ref)
    }

    public entry fun deposit_shadow<C>(account: &signer, amount: u64, is_collateral_only: bool): (u64, u64) acquires Pool, Storage {
        let asset_storage_ref = borrow_global_mut<Storage<C,Shadow>>(@leizd);
        let pool_ref = borrow_global_mut<Pool<C>>(@leizd);

        let withdrawn = coin::withdraw<ZUSD>(account, amount);
        coin::merge(&mut pool_ref.shadow, withdrawn);
        deposit_internal<C,Shadow>(account, amount, is_collateral_only, asset_storage_ref)
    }

    fun deposit_internal<C,P>(account: &signer, amount: u64, is_collateral_only: bool, asset_storage_ref: &mut Storage<C,P>): (u64, u64) {
        // TODO: accrue interest
        let collateral_amount = 0;
        let collateral_share;
        if (is_collateral_only) {
            collateral_share = to_share(
                (amount as u128),
                asset_storage_ref.total_collateral_only_deposits,
                collateral_only::supply<C,P>()
            );
            asset_storage_ref.total_collateral_only_deposits = asset_storage_ref.total_deposits + (amount as u128);
            collateral_only::mint<C,P>(account, collateral_share); 
        } else {
            collateral_share = to_share(
                (amount as u128),
                asset_storage_ref.total_deposits,
                collateral::supply<C,P>()
            );
            asset_storage_ref.total_deposits = asset_storage_ref.total_deposits + (amount as u128);
            collateral::mint<C,P>(account, collateral_share);
        };

        (collateral_amount, collateral_share)
    }

    public entry fun withdraw_asset<C>(account: &signer, amount: u64, is_collateral_only: bool) acquires Pool, Storage {
        let pool_ref = borrow_global_mut<Pool<C>>(@leizd);
        let asset_storage_ref = borrow_global_mut<Storage<C,Asset>>(@leizd);

        withdraw_internal<C,Asset>(account, amount, is_collateral_only, pool_ref, asset_storage_ref);
    }

    public entry fun withdraw_shadow<C>(account: &signer, amount: u64, is_collateral_only: bool) acquires Pool, Storage { 
        let pool_ref = borrow_global_mut<Pool<C>>(@leizd);
        let asset_storage_ref = borrow_global_mut<Storage<C,Shadow>>(@leizd);

        withdraw_internal<C,Shadow>(account, amount, is_collateral_only, pool_ref, asset_storage_ref);
    }

    fun withdraw_internal<C,P>(account: &signer, amount: u64, is_collateral_only: bool, pool_ref: &mut Pool<C>, asset_storage_ref: &mut Storage<C,P>): (u64, u64) {
        let account_addr = signer::address_of(account);
        // TODO: accrue interest

        let burned_share;
        let withdrawn_amount;
        if (amount == U64_MAX) {
            burned_share = collateral_balance<C,P>(account_addr, is_collateral_only);
            withdrawn_amount = 0; // TODO
        } else {
            burned_share = collateral_balance<C,P>(account_addr, is_collateral_only);
            withdrawn_amount = amount;
        };

        if (is_collateral_only) {
            asset_storage_ref.total_collateral_only_deposits = asset_storage_ref.total_collateral_only_deposits - (withdrawn_amount as u128);
            collateral_only::burn<C,P>(account, burned_share);
        } else {
            asset_storage_ref.total_deposits = asset_storage_ref.total_deposits - (withdrawn_amount as u128);
            collateral::burn<C,P>(account, burned_share);
        };

        let deposited = coin::extract(&mut pool_ref.asset, amount);
        coin::deposit<C>(account_addr, deposited);

        // TODO is solvent

        (burned_share, withdrawn_amount)
    }


    public entry fun borrow_asset<C>(account: &signer, amount: u64) acquires Pool, Storage {
        let pool_ref = borrow_global_mut<Pool<C>>(@leizd);
        let asset_storage_ref = borrow_global_mut<Storage<C,Asset>>(@leizd);

        borrow_internal<C,Asset>(account, amount, pool_ref, asset_storage_ref);
    }

    public entry fun borrow_shadow<C>(account: &signer, amount: u64) acquires Pool, Storage {
        let pool_ref = borrow_global_mut<Pool<C>>(@leizd);
        let asset_storage_ref = borrow_global_mut<Storage<C,Shadow>>(@leizd);

        borrow_internal<C,Shadow>(account, amount, pool_ref, asset_storage_ref);
    }


    fun borrow_internal<C,P>(account: &signer, amount: u64, pool_ref: &mut Pool<C>, asset_storage_ref: &mut Storage<C,P>) {
        let account_addr = signer::address_of(account);
        // TODO: accrue interest
        // TODO: borrow possible
        // TODO: liquidity check

        let debt_share = 0; // TODO
        let fee = repository::entry_fee();

        asset_storage_ref.total_borrows = asset_storage_ref.total_borrows + (amount as u128) + fee;
        // TODO: transfer protocol fee to treasury

        debt::mint<C,P>(account, debt_share);

        let deposited = coin::extract(&mut pool_ref.asset, amount);
        coin::deposit<C>(account_addr, deposited);

        // TODO: validate
    }

    public entry fun repay<C>() {
        // TODO
    }

    public entry fun flash_liquidate<C>() {
        // TODO
    }

    public entry fun harvest_protocol_fees() {
        // TODO
    }

    public entry fun accrue_interest() {
        // TODO
    }

    fun collateral_balance<C,P>(account_addr: address, is_collateral_only: bool): u64 {
        if (is_collateral_only) {
            collateral_only::balance_of<C,P>(account_addr)
        } else {
            collateral::balance_of<C,P>(account_addr)
        }
    }

    public fun total_deposits<C,P>(): u128 acquires Storage {
        borrow_global<Storage<C,P>>(@leizd).total_deposits
    }

    public fun total_conly_deposits<C,P>(): u128 acquires Storage {
        borrow_global<Storage<C,P>>(@leizd).total_collateral_only_deposits
    }

    public fun total_borrows<C,P>(): u128 acquires Storage {
        borrow_global<Storage<C,P>>(@leizd).total_borrows
    }

    #[test_only]
    use aptos_framework::account;
    use aptos_framework::managed_coin;
    use leizd::common::{Self,WETH};
    use leizd::zusd::{Self,ZUSD};
    use leizd::trove;

    #[test(owner=@leizd,account1=@0x111)]
    public entry fun test_deposit_weth(owner: signer, account1: signer) acquires Pool, Storage {
        let owner_addr = signer::address_of(&owner);
        let account1_addr = signer::address_of(&account1);
        account::create_account(owner_addr);
        account::create_account(account1_addr);
        common::init_weth(&owner);
        managed_coin::register<WETH>(&account1);
        managed_coin::mint<WETH>(&owner, account1_addr, 1000000);
        assert!(coin::balance<WETH>(account1_addr) == 1000000, 0);

        init_pool<WETH>(&owner);

        deposit<WETH>(&account1, 800000, false, false);
        assert!(coin::balance<WETH>(account1_addr) == 200000, 0);
        assert!(total_deposits<WETH,Asset>() == 800000, 0);
        assert!(total_conly_deposits<WETH,Asset>() == 0, 0);
    }

    #[test(owner=@leizd,account1=@0x111)]
    public entry fun test_deposit_weth_for_only_collateral(owner: signer, account1: signer) acquires Pool, Storage {
        let owner_addr = signer::address_of(&owner);
        let account1_addr = signer::address_of(&account1);
        account::create_account(owner_addr);
        account::create_account(account1_addr);
        common::init_weth(&owner);
        managed_coin::register<WETH>(&account1);
        managed_coin::mint<WETH>(&owner, account1_addr, 1000000);
        assert!(coin::balance<WETH>(account1_addr) == 1000000, 0);

        init_pool<WETH>(&owner);

        deposit<WETH>(&account1, 800000, true, false);
        assert!(coin::balance<WETH>(account1_addr) == 200000, 0);
        assert!(total_deposits<WETH,Asset>() == 0, 0);
        assert!(total_conly_deposits<WETH,Asset>() == 800000, 0);
    }

    #[test(owner=@leizd,account1=@0x111)]
    public entry fun test_deposit_shadow(owner: signer, account1: signer) acquires Pool, Storage {
        let owner_addr = signer::address_of(&owner);
        let account1_addr = signer::address_of(&account1);
        account::create_account(owner_addr);
        account::create_account(account1_addr);
        common::init_weth(&owner);
        trove::initialize(&owner);
        managed_coin::register<WETH>(&account1);
        managed_coin::mint<WETH>(&owner, account1_addr, 1000000);
        assert!(coin::balance<WETH>(account1_addr) == 1000000, 0);
        managed_coin::register<ZUSD>(&account1);
        zusd::mint_for_test(&account1, 1000000);
        assert!(coin::balance<ZUSD>(account1_addr) == 1000000, 0);

        init_pool<WETH>(&owner);

        deposit<WETH>(&account1, 800000, false, true);
        assert!(coin::balance<WETH>(account1_addr) == 1000000, 0);
        assert!(total_deposits<WETH,Shadow>() == 800000, 0);
        assert!(coin::balance<ZUSD>(account1_addr) == 200000, 0);
    }

    #[test(owner=@leizd,account1=@0x111)]
    public entry fun test_withdraw_weth(owner: signer, account1: signer) acquires Pool, Storage {
        let owner_addr = signer::address_of(&owner);
        let account1_addr = signer::address_of(&account1);
        account::create_account(owner_addr);
        account::create_account(account1_addr);
        common::init_weth(&owner);
        managed_coin::register<WETH>(&account1);
        managed_coin::mint<WETH>(&owner, account1_addr, 1000000);
        assert!(coin::balance<WETH>(account1_addr) == 1000000, 0);

        init_pool<WETH>(&owner);
        deposit<WETH>(&account1, 800000, false, false);

        withdraw<WETH>(&account1, 800000, false, false);

        assert!(coin::balance<WETH>(account1_addr) == 1000000, 0);
        assert!(total_deposits<WETH,Asset>() == 0, 0);
    }
}