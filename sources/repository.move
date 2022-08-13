module leizd::repository {

    use std::signer;
    use leizd::interest_rate;

    const DECIMAL_PRECISION: u64 = 1000000000000000000;

    const DEFAULT_ENTRY_FEE: u128 = 1000000000000000000 / 1000 * 5; // 0.5%
    const DEFAULT_SHARE_FEE: u128 = 1000000000000000000 / 1000 * 5; // 0.5%
    const DEFAULT_LIQUIDATION_FEE: u128 = 1000000000000000000 / 1000 * 5; // 0.5%

    const DEFAULT_LTV: u128 = 1000000000000000000 / 100 * 5; // 50%
    const DEFAULT_THRESHOLD: u128 = 1000000000000000000 / 100 * 70 ; // 70%
    

    struct AssetConfig<phantom T> has key {
        ltv: u128,
        threshold: u128,
        interest_rate: interest_rate::Config<T>
    }

    struct Fees has drop, key {
        entry_fee: u128,
        protocol_share_fee: u128,
        liquidation_fee: u128
    }

    // TODO: friend
    public entry fun initialize(owner: &signer) {
        move_to(owner, Fees {
            entry_fee: DEFAULT_ENTRY_FEE,
            protocol_share_fee: DEFAULT_SHARE_FEE,
            liquidation_fee: DEFAULT_LIQUIDATION_FEE
        });
    }

    public fun new_asset<T>(owner: &signer) {
        move_to(owner, AssetConfig<T> {
            ltv: DEFAULT_LTV,
            threshold: DEFAULT_THRESHOLD,
            interest_rate: interest_rate::initialize<T>()
        });
    }

    public fun set_fees(owner: &signer, fees: Fees) acquires Fees {
        assert!(signer::address_of(owner) == @leizd, 0);

        let _fees = borrow_global_mut<Fees>(@leizd);
        _fees.entry_fee = fees.entry_fee;
        _fees.protocol_share_fee = fees.protocol_share_fee;
        _fees.liquidation_fee = fees.liquidation_fee;
    }

    public fun set_asset_config() {
        // TODO
    }

    public fun entry_fee(): u128 acquires Fees {
        borrow_global<Fees>(@leizd).entry_fee
    }
}