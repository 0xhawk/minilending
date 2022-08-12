module leizd::collateral {

    use std::string;
    use std::signer;
    use std::option;
    use aptos_framework::coin;
    use aptos_framework::coins;

    friend leizd::asset_pool;

    struct Collateral<phantom T> {
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

        let prefix_name = b"Leizd Collateral ";
        let prefix_symbol = b"c";
        string::insert(&mut coin_name, 0, string::utf8(prefix_name));
        string::insert(&mut coin_symbol, 0, string::utf8(prefix_symbol));

        let (mint_cap, burn_cap) = coin::initialize<Collateral<T>>(
            owner,
            coin_name,
            coin_symbol,
            coin_decimals,
            true
        );
        move_to(owner, Capabilities<Collateral<T>> {
            mint_cap,
            burn_cap,
        });
        initialize_shadow<T>(owner);
    }

    fun initialize_shadow<T>(owner: &signer) {
        let coin_name = coin::name<T>();
        let coin_symbol = coin::symbol<T>();
        let coin_decimals = coin::decimals<T>();

        let prefix_name = b"Leizd Shadow Collateral ";
        let prefix_symbol = b"sc";
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
        let caps = borrow_global<Capabilities<Collateral<T>>>(@leizd);
        if (!coin::is_account_registered<Collateral<T>>(account_addr)) {
            coins::register<Collateral<T>>(account);
        };

        let coin_minted = coin::mint(amount, &caps.mint_cap);
        coin::deposit(account_addr, coin_minted);
    }

    public(friend) fun burn<T>(account: &signer, amount: u64) acquires Capabilities {
        let caps = borrow_global<Capabilities<Collateral<T>>>(@leizd);
        
        let coin_burned = coin::withdraw<Collateral<T>>(account, amount);
        coin::burn(coin_burned, &caps.burn_cap);
    }

    public fun balance_of<T>(addr: address): u64 {
        coin::balance<Collateral<T>>(addr)
    }

    public fun supply<T>(): u128 {
        let _supply = coin::supply<Collateral<T>>();
        if (option::is_some(&_supply)) {
            *option::borrow<u128>(&_supply)
        } else {
            0
        }
    }
}