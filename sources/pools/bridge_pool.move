module leizd::bridge_pool {
    use std::debug;
    use std::signer;
    use aptos_framework::coin;
    use leizd::bridge_coin::{BridgeCoin};
    use leizd::collateral_coin;
    use leizd::debt_coin;
    use leizd::price_oracle;

    friend leizd::asset_pool;

    const EZERO_AMOUNT: u64 = 0;

    struct BridgePool<phantom T> has key {
        coin: coin::Coin<BridgeCoin>
    }

    public(friend) entry fun initialize<T>(owner: &signer) {
        move_to(owner, BridgePool<T> {coin: coin::zero()});
    }

    public entry fun deposit<T>(account: &signer, amount: u64) acquires BridgePool {
        assert!(amount > 0, EZERO_AMOUNT);

        let withdrawed = coin::withdraw<BridgeCoin>(account, amount);
        let coin_ref = &mut borrow_global_mut<BridgePool<T>>(@leizd).coin;
        coin::merge(coin_ref, withdrawed);

        collateral_coin::mint<BridgeCoin>(account, amount);
    }

    public entry fun withdraw<T>() {
        // TODO
    }

    public entry fun borrow<T>(account: &signer, amount: u64) acquires BridgePool {

        let price = price_oracle::asset_price<T>();
        debug::print(&price);
        // TODO: validate health

        let account_addr = signer::address_of(account);
        let pool_ref = borrow_global_mut<BridgePool<T>>(@leizd);
        let deposited = coin::extract(&mut pool_ref.coin, amount);
        coin::deposit<BridgeCoin>(account_addr, deposited);

        debt_coin::mint<BridgeCoin>(account, amount);
    }

    public entry fun repay<T>() {
        // TODO
    }

    public fun balance<T>(): u64 acquires BridgePool {
        let coin = &borrow_global<BridgePool<T>>(@leizd).coin;
        coin::value(coin)
    }
}