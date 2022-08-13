module leizd::math {

    public fun to_share(amount: u128, total_amount: u128, total_shares: u128): u64 {
        if (total_shares == 0 || total_amount == 0) {
            (amount as u64)
        } else {
            let result = amount * total_shares / total_amount;
            assert!(result != 0 || amount == 0, 0);
            (result as u64)
        }
    }
}