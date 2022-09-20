module ferum_std::math {
    const MAX_U128: u128 = 340282366920938463463374607431768211455u128;

    /// The max value that can be represented using a u128.
    public fun max_u128(): u128 {
        MAX_U128
    }
}
