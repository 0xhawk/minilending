module leizd::debt_coin {

    use std::string;
    use std::signer;
    use aptos_std::type_info;
    use aptos_framework::coin::{Self, Coin, MintCapability, BurnCapability};
    
    friend leizd::asset_pool;
    friend leizd::bridge_pool;
    friend leizd::bridge_coin_factory;

    struct Debt<phantom T> {
        borrowed_coin: Coin<T>
    }

    struct Capabilities<phantom T> has key {
        mint_cap: MintCapability<T>,
        burn_cap: BurnCapability<T>
    }

    public(friend) fun initialize<T>(account: &signer) {
        let coin_name = coin::name<T>();
        let coin_symbol = coin::symbol<T>();
        let coin_decimals = coin::decimals<T>();
        let prefix_name = b"Debt ";
        let prefix_symbol = b"d";
        string::insert(&mut coin_name, 0, string::utf8(prefix_name));
        string::insert(&mut coin_symbol, 0, string::utf8(prefix_symbol));        
        let (mint_cap, burn_cap) = coin::initialize<Debt<T>>(
            account,
            coin_name,
            coin_symbol,
            coin_decimals,
            true
        );
        move_to(account, Capabilities<Debt<T>> {
            mint_cap,
            burn_cap
        })
    }

    public(friend) fun mint<T>(dest: &signer, amount: u64) acquires Capabilities {
        let type_info = type_info::type_of<T>();
        let coin_owner = type_info::account_address(&type_info);
        let caps = borrow_global<Capabilities<Debt<T>>>(coin_owner);

        let dest_addr = signer::address_of(dest);
        if (!coin::is_account_registered<Debt<T>>(dest_addr)) {
            coin::register<Debt<T>>(dest);
        };

        let coin_minted = coin::mint(amount, &caps.mint_cap);
        coin::deposit(dest_addr, coin_minted);
    }

    public(friend) fun burn<T>() {
        // TODO
    }
}