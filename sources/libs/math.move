module leizd::math {

    public fun to_share(amount: u128, total_amount: u128, total_shares: u128): u64 {
        if (total_shares == 0 || total_amount == 0) {
            (amount as u64)
        } else {
            let result = amount * total_shares / total_amount;

            // prevent rounding error
            assert!(result != 0 || amount == 0, 0);

            (result as u64)
        }
    }

    public fun to_share_roundup(amount: u128, total_amount: u128, total_shares: u128): u64 {
        if (total_amount == 0 || total_shares == 0 ) {
             (amount as u64)
        } else {
            let numerator = amount * total_shares;
            let result = numerator / total_amount;

            // round up
            if (numerator % total_amount != 0) {
                result = result + 1;
            };
            (result as u64)
        }
        
    }

    public fun to_amount_roundup(share: u128, total_amount: u128, total_shares: u128): u64 {
        if (total_amount == 0 || total_shares == 0 ) {
            return 0
        };
        let numerator = share * total_amount;
        let result = numerator / total_shares;

        // round up
        if (numerator % total_shares != 0) {
            result = result + 1;
        };
        (result as u64)
    }
}