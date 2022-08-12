module leizd::asset_pool {

    use std::signer;
    use aptos_framework::coin;
    use leizd::collateral;
    use leizd::collateral_only;
    use leizd::debt;
    use leizd::repository;

    // TODO: util
    const U64_MAX: u64 = 18446744073709551615;

    struct Pool<phantom T> has key {
        coin: coin::Coin<T>
    }

    struct AssetStorage<phantom T> has key {
        total_deposits: u128,
        total_collateral_only_deposits: u128,
        total_borrow_amount: u128
    }

    // TODO: friend
    public entry fun init_pool<T>(owner: &signer) {
        move_to(owner, Pool<T> {
            coin: coin::zero<T>()
        });
        move_to(owner, AssetStorage<T> {
            total_deposits: 0,
            total_collateral_only_deposits: 0,
            total_borrow_amount: 0
        });
        collateral::initialize<T>(owner);
        collateral_only::initialize<T>(owner);
        debt::initialize<T>(owner);
    }

    fun to_share(amount: u128, total_amount: u128, total_shares: u128): u64 {
        if (total_shares == 0 || total_amount == 0) {
            (amount as u64)
        } else {
            let result = amount * total_shares / total_amount;
            assert!(result != 0 || amount == 0, 0);
            (result as u64)
        }
    }

    public entry fun deposit<T>(account: &signer, amount: u64, is_collateral_only: bool): (u64, u64) acquires Pool, AssetStorage {
        // TODO: accrue interest

        let collateral_amount = 0;
        let collateral_share;
        let asset_storage_ref = borrow_global_mut<AssetStorage<T>>(@leizd);
        if (is_collateral_only) {
            collateral_share = to_share(
                (amount as u128),
                asset_storage_ref.total_collateral_only_deposits,
                collateral_only::supply<T>()
            );
            asset_storage_ref.total_collateral_only_deposits = asset_storage_ref.total_deposits + (amount as u128);
            collateral_only::mint<T>(account, collateral_share); 
        } else {
            collateral_share = to_share(
                (amount as u128),
                asset_storage_ref.total_deposits,
                collateral::supply<T>()
            );
            asset_storage_ref.total_deposits = asset_storage_ref.total_deposits + (amount as u128);
            collateral::mint<T>(account, collateral_share);
        };

        let pool_ref = borrow_global_mut<Pool<T>>(@leizd);
        let withdrawn = coin::withdraw<T>(account, amount);
        coin::merge(&mut pool_ref.coin, withdrawn);

        (collateral_amount, collateral_share)
    }

    public entry fun withdraw<T>(account: &signer, amount: u64, is_collateral_only: bool): (u64, u64) acquires Pool, AssetStorage {
        let account_addr = signer::address_of(account);
        // TODO: accrue interest

        let burned_share;
        let withdrawn_amount;
        if (amount == U64_MAX) {
            burned_share = collateral_balance<T>(account_addr, is_collateral_only);
            withdrawn_amount = 0; // TODO
        } else {
            burned_share = collateral_balance<T>(account_addr, is_collateral_only);
            withdrawn_amount = amount;
        };

        let asset_storage_ref = borrow_global_mut<AssetStorage<T>>(@leizd);
        if (is_collateral_only) {
            asset_storage_ref.total_collateral_only_deposits = asset_storage_ref.total_collateral_only_deposits - (withdrawn_amount as u128);
            collateral_only::burn<T>(account, burned_share);
        } else {
            asset_storage_ref.total_deposits = asset_storage_ref.total_deposits - (withdrawn_amount as u128);
            collateral::burn<T>(account, burned_share);
        };

        let pool_ref = borrow_global_mut<Pool<T>>(@leizd);
        let deposited = coin::extract(&mut pool_ref.coin, amount);
        coin::deposit<T>(account_addr, deposited);

        // TODO is solvent

        (burned_share, withdrawn_amount)
    }

    public entry fun borrow<T>(account: &signer, amount: u64) acquires Pool, AssetStorage {
        let account_addr = signer::address_of(account);
        // TODO: accrue interest
        // TODO: borrow possible
        // TODO: liquidity check

        let asset_storage_ref = borrow_global_mut<AssetStorage<T>>(@leizd);
        
        let debt_share = 0; // TODO
        let fee = repository::entry_fee();

        asset_storage_ref.total_borrow_amount = asset_storage_ref.total_borrow_amount + (amount as u128) + fee;
        // TODO: transfer protocol fee to treasury

        debt::mint<T>(account, debt_share);

        let pool_ref = borrow_global_mut<Pool<T>>(@leizd);
        let deposited = coin::extract(&mut pool_ref.coin, amount);
        coin::deposit<T>(account_addr, deposited);

        // TODO: validate
    }

    public entry fun repay<T>() {
        // TODO
    }

    public entry fun flash_liquidate<T>() {
        // TODO
    }

    public entry fun harvest_protocol_fees() {
        // TODO
    }

    public entry fun accrue_interest() {
        // TODO
    }

    fun collateral_balance<T>(account_addr: address, is_collateral_only: bool): u64 {
        if (is_collateral_only) {
            account_addr;
            collateral_only::balance_of<T>(account_addr)
        } else {
            collateral::balance_of<T>(account_addr)
        }
    }
}