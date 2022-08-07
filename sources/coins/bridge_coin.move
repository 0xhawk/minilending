module leizd::bridge_coin {

    use std::string;
    use aptos_std::signer;
    use aptos_framework::coin::{Self, MintCapability, BurnCapability};

    friend leizd::bridge_coin_factory;

    struct BridgeCoin has key, store {}

    struct Capabilities<phantom T> has key {
        mint_cap: MintCapability<T>,
        burn_cap: BurnCapability<T>,
    }

    public(friend) fun initialize(owner: &signer) {
        let (mint_cap, burn_cap) = coin::initialize<BridgeCoin>(
            owner,
            string::utf8(b"BridgeCoin"),
            string::utf8(b"BRD"),
            18,
            true
        );
        move_to(owner, Capabilities<BridgeCoin> {
            mint_cap,
            burn_cap,
        });
    }

    public(friend) fun mint(dest: &signer, amount: u64) acquires Capabilities {
        let dest_addr = signer::address_of(dest);
        if (!coin::is_account_registered<BridgeCoin>(dest_addr)) {
            coin::register<BridgeCoin>(dest);
        };

        let caps = borrow_global<Capabilities<BridgeCoin>>(@leizd);
        let coin_minted = coin::mint(amount, &caps.mint_cap);
        coin::deposit(dest_addr, coin_minted);
    }

    public(friend) fun burn() {
        // TODO
    }

    public fun balance(owner: address): u64 {
        coin::balance<BridgeCoin>(owner)
    }
}