module leizd::trove {

    use aptos_framework::coin;
    use leizd::zusd;

    struct Trove<phantom C> has key {
        coin: coin::Coin<C>,
    }

    public fun open_trove(account: &signer, amount: u64) {

        // TODO: active pool -> increate ZUSD debt
        zusd::mint(account, amount);
    }
}