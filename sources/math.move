module ferum_std::math {

    const MAX_U128: u128 = 340282366920938463463374607431768211455u128;

    // The max value that can be represented using a u128.
    public fun max_value_u128(): u128 {
        MAX_U128
    }

    public fun max_u128(a: u128, b: u128): u128 {
        if (a > b) {
            a
        } else {
            b
        }
    }

    public fun min_u128(a: u128, b: u128): u128 {
        if (a <= b) {
            a
        } else {
            b
        }
    }

    public fun max_u64(a: u64, b: u64): u64 {
        if (a > b) {
            a
        } else {
            b
        }
    }

    public fun min_u64(a: u64, b: u64): u64 {
        if (a <= b) {
            a
        } else {
            b
        }
    }

    public fun max_u8(a: u8, b: u8): u8 {
        if (a > b) {
            a
        } else {
            b
        }
    }

    public fun min_u8(a: u8, b: u8): u8 {
        if (a <= b) {
            a
        } else {
            b
        }
    }

    #[test]
    fun test_max_u128() {
        assert!(max_u128(10, 100) == 100, 0);
        assert!(max_u128(1, 10) == 10, 0);
        assert!(max_u128(10, 10) == 10, 0);
    }

    #[test]
    fun test_min_u128() {
        assert!(min_u128(10, 100) == 10, 0);
        assert!(min_u128(1, 10) == 1, 0);
        assert!(min_u128(10, 10) == 10, 0);
    }

    #[test]
    fun test_max_u64() {
        assert!(max_u64(10, 100) == 100, 0);
        assert!(max_u64(1, 10) == 10, 0);
        assert!(max_u64(10, 10) == 10, 0);
    }

    #[test]
    fun test_min_u64() {
        assert!(min_u64(10, 100) == 10, 0);
        assert!(min_u64(1, 10) == 1, 0);
        assert!(min_u64(10, 10) == 10, 0);
    }

    #[test]
    fun test_max_u8() {
        assert!(max_u8(10, 100) == 100, 0);
        assert!(max_u8(1, 10) == 10, 0);
        assert!(max_u8(10, 10) == 10, 0);
    }

    #[test]
    fun test_min_u8() {
        assert!(min_u8(10, 100) == 10, 0);
        assert!(min_u8(1, 10) == 1, 0);
        assert!(min_u8(10, 10) == 10, 0);
    }
}