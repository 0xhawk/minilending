module leizd::asset_pool {

    use std::signer;
    use aptos_framework::coin;
    use leizd::collateral;
    use leizd::collateral_only;
    use leizd::debt;
    use leizd::repository;

    // TODO: util
    const U64_MAX: u64 = 18446744073709551615;

    struct Asset {}

    struct Shadow {}

    struct Pool<phantom C, phantom P> has key {
        coin: coin::Coin<C>
    }

    struct Storage<phantom C, phantom P> has key {
        total_deposits: u128,
        total_collateral_only_deposits: u128,
        total_borrow_amount: u128
    }

    // TODO: friend
    public entry fun init_pool<C>(owner: &signer) {
        move_to(owner, Pool<C,Asset> {
            coin: coin::zero<C>()
        });
        move_to(owner, Pool<C,Shadow> {
            coin: coin::zero<C>()
        });
        move_to(owner, Storage<C,Asset> {
            total_deposits: 0,
            total_collateral_only_deposits: 0,
            total_borrow_amount: 0
        });
        move_to(owner, Storage<C,Shadow> {
            total_deposits: 0,
            total_collateral_only_deposits: 0,
            total_borrow_amount: 0
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

    public entry fun deposit_asset<C>(account: &signer, amount: u64, is_collateral_only: bool): (u64, u64) acquires Pool, Storage {
        // TODO: accrue interest

        let asset_storage_ref = borrow_global_mut<Storage<C,Asset>>(@leizd);
        let pool_ref = borrow_global_mut<Pool<C,Asset>>(@leizd);

        deposit_internal<C,Asset>(account, amount, is_collateral_only, pool_ref, asset_storage_ref)
    }

    public entry fun deposit_shadow<C>(account: &signer, amount: u64, is_collateral_only: bool): (u64, u64) acquires Pool, Storage {
        // TODO: accrue interest

        let asset_storage_ref = borrow_global_mut<Storage<C,Shadow>>(@leizd);
        let pool_ref = borrow_global_mut<Pool<C,Shadow>>(@leizd);

        deposit_internal<C,Shadow>(account, amount, is_collateral_only, pool_ref, asset_storage_ref)
    }

    fun deposit_internal<C,P>(account: &signer, amount: u64, is_collateral_only: bool, pool_ref: &mut Pool<C,P>, asset_storage_ref: &mut Storage<C,P>): (u64, u64) {
        let collateral_amount = 0;
        let collateral_share;
        if (is_collateral_only) {
            collateral_share = to_share(
                (amount as u128),
                asset_storage_ref.total_collateral_only_deposits,
                collateral_only::supply<C>()
            );
            asset_storage_ref.total_collateral_only_deposits = asset_storage_ref.total_deposits + (amount as u128);
            collateral_only::mint<C>(account, collateral_share); 
        } else {
            collateral_share = to_share(
                (amount as u128),
                asset_storage_ref.total_deposits,
                collateral::supply<C>()
            );
            asset_storage_ref.total_deposits = asset_storage_ref.total_deposits + (amount as u128);
            collateral::mint<C>(account, collateral_share);
        };

        let withdrawn = coin::withdraw<C>(account, amount);
        coin::merge(&mut pool_ref.coin, withdrawn);

        (collateral_amount, collateral_share)
    }

    public entry fun withdraw<C>(account: &signer, amount: u64, is_collateral_only: bool): (u64, u64) acquires Pool, Storage {
        let account_addr = signer::address_of(account);
        // TODO: accrue interest

        let burned_share;
        let withdrawn_amount;
        if (amount == U64_MAX) {
            burned_share = collateral_balance<C>(account_addr, is_collateral_only);
            withdrawn_amount = 0; // TODO
        } else {
            burned_share = collateral_balance<C>(account_addr, is_collateral_only);
            withdrawn_amount = amount;
        };

        let asset_storage_ref = borrow_global_mut<Storage<C,Asset>>(@leizd);
        if (is_collateral_only) {
            asset_storage_ref.total_collateral_only_deposits = asset_storage_ref.total_collateral_only_deposits - (withdrawn_amount as u128);
            collateral_only::burn<C>(account, burned_share);
        } else {
            asset_storage_ref.total_deposits = asset_storage_ref.total_deposits - (withdrawn_amount as u128);
            collateral::burn<C>(account, burned_share);
        };

        let pool_ref = borrow_global_mut<Pool<C,Asset>>(@leizd);
        let deposited = coin::extract(&mut pool_ref.coin, amount);
        coin::deposit<C>(account_addr, deposited);

        // TODO is solvent

        (burned_share, withdrawn_amount)
    }

    public entry fun borrow<C>(account: &signer, amount: u64) acquires Pool, Storage {
        let account_addr = signer::address_of(account);
        // TODO: accrue interest
        // TODO: borrow possible
        // TODO: liquidity check

        let asset_storage_ref = borrow_global_mut<Storage<C,Asset>>(@leizd);
        
        let debt_share = 0; // TODO
        let fee = repository::entry_fee();

        asset_storage_ref.total_borrow_amount = asset_storage_ref.total_borrow_amount + (amount as u128) + fee;
        // TODO: transfer protocol fee to treasury

        debt::mint<C>(account, debt_share);

        let pool_ref = borrow_global_mut<Pool<C,Asset>>(@leizd);
        let deposited = coin::extract(&mut pool_ref.coin, amount);
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

    fun collateral_balance<C>(account_addr: address, is_collateral_only: bool): u64 {
        if (is_collateral_only) {
            collateral_only::balance_of<C>(account_addr)
        } else {
            collateral::balance_of<C>(account_addr)
        }
    }
}