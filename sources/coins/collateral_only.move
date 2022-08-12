module leizd::collateral_only {

    use std::string;
    use std::signer;
    use std::option;
    use aptos_framework::coin;
    use aptos_framework::coins;

    friend leizd::asset_pool;

    struct CollateralOnly<phantom T> {
        coin: coin::Coin<T>
    }

    struct Shadow<phantom T> {
        coin: coin::Coin<T>
    }

    struct Capabilities<phantom T> has key {
        mint_cap: coin::MintCapability<T>,
        burn_cap: coin::BurnCapability<T>
    }

    public(friend) fun initialize<T>(owner: &signer) {
        let coin_name = coin::name<T>();
        let coin_symbol = coin::symbol<T>();
        let coin_decimals = coin::decimals<T>();

        let prefix_name = b"Leizd Collateral Only ";
        let prefix_symbol = b"co";
        string::insert(&mut coin_name, 0, string::utf8(prefix_name));
        string::insert(&mut coin_symbol, 0, string::utf8(prefix_symbol));

        let (mint_cap, burn_cap) = coin::initialize<CollateralOnly<T>>(
            owner,
            coin_name,
            coin_symbol,
            coin_decimals,
            true
        );
        move_to(owner, Capabilities<CollateralOnly<T>> {
            mint_cap,
            burn_cap,
        });
        initialize_shadow<T>(owner);
    }

    fun initialize_shadow<T>(owner: &signer) {
        let coin_name = coin::name<T>();
        let coin_symbol = coin::symbol<T>();
        let coin_decimals = coin::decimals<T>();

        let prefix_name = b"Leizd Shadow Collateral Only ";
        let prefix_symbol = b"sco";
        string::insert(&mut coin_name, 0, string::utf8(prefix_name));
        string::insert(&mut coin_symbol, 0, string::utf8(prefix_symbol));

        let (mint_cap, burn_cap) = coin::initialize<Shadow<T>>(
            owner,
            coin_name,
            coin_symbol,
            coin_decimals,
            true
        );
        move_to(owner, Capabilities<Shadow<T>> {
            mint_cap,
            burn_cap,
        });
    }

    public(friend) fun mint<T>(account: &signer, amount: u64) acquires Capabilities {
        let account_addr = signer::address_of(account);
        let caps = borrow_global<Capabilities<CollateralOnly<T>>>(@leizd);
        if (!coin::is_account_registered<CollateralOnly<T>>(account_addr)) {
            coins::register<CollateralOnly<T>>(account);
        };

        let coin_minted = coin::mint(amount, &caps.mint_cap);
        coin::deposit(account_addr, coin_minted);
    }

    public(friend) fun burn<T>(account: &signer, amount: u64) acquires Capabilities {
        let caps = borrow_global<Capabilities<CollateralOnly<T>>>(@leizd);
        
        let coin_burned = coin::withdraw<CollateralOnly<T>>(account, amount);
        coin::burn(coin_burned, &caps.burn_cap);
    }

    public fun balance_of<T>(addr: address): u64 {
        coin::balance<CollateralOnly<T>>(addr)
    }

    public fun supply<T>(): u128 {
        let _supply = coin::supply<CollateralOnly<T>>();
        if (option::is_some(&_supply)) {
            *option::borrow<u128>(&_supply)
        } else {
            0
        }
    }
}