module leizd::interest_rate {

    struct Config<phantom T> has store {
        u_optimal: u64,
        u_large_threshold: u64,
        u_low_threshold: u64
    }

    public fun initialize<T>(): Config<T> {
        Config<T> {
            u_optimal: 0,
            u_large_threshold: 0,
            u_low_threshold: 0
        }
    }
}