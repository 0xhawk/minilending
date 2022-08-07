module leizd::bridge_pool {

    use aptos_framework::coin;
    use leizd::bridge_coin::{BridgeCoin};
    use leizd::collateral_coin;

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

    public fun balance<T>(): u64 acquires BridgePool {
        let coin = &borrow_global<BridgePool<T>>(@leizd).coin;
        coin::value(coin)
    }
}