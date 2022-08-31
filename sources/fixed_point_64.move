/// Ferum's implementation of a FixedPoint number, stored internally as
/// a u128. Has fixed decimal places of 10 and a max value of MAX_U64.
///
/// Operations that result in an overflow will error out.
module ferum_std::fixed_point_64 {

    struct FixedPoint64 has store, drop, copy {
        /// This might seem a bit odd at first; why is FixedPoint64 actually
        /// representing the value as 128 bits! But it makes sense since only
        /// the first 64 bits are used for the whole number, the rest are for
        /// fractional part.
        val: u128,
    }

    /// The max value that can be represented using a u128.
    const MAX_U128: u128 = 340282366920938463463374607431768211455u128;
    /// Number of decimal places in a FixedPoint value.
    const DECIMAL_PLACES: u8 = 10;
    /// Max value a FixedPoint can represent.
    const MAX_VALUE: u128 = 18446744073709551615;

    const MODE_ROUND_UP: u8 = 0;
    const MODE_TRUNCATE: u8 = 1;
    const MODE_NO_PRECISION_LOSS: u8 = 2;

    /// Errors.
    const ERR_EXCEED_MAX_DECIMALS: u64 = 1;
    const ERR_EXCEED_MAX_EXP: u64 = 2;
    const ERR_PRECISION_LOSS: u64 = 3;
    const ERR_EXCEED_MAX: u64 = 4;

    /// Create a new FixedPoint from a u64 value. No conversion is performed.
    /// Example: new_u64(12345) == 0.0000012345
    public fun new_u64(val: u64): FixedPoint64 {
        FixedPoint64 { val: (val as u128) }
    }

    /// Create a new FixedPoint from a u128 value. No conversion is performed.
    /// Example: new_u128(12345) == 0.0000012345
    public fun new_u128(val: u128): FixedPoint64 {
        FixedPoint64 { val }
    }

    /// Return then underlying value of the FixedPoint.
    public fun value(a: FixedPoint64): u128 {
        a.val
    }

    /// Return a FixedPoint that equals 0.
    public fun zero(): FixedPoint64 {
        FixedPoint64 { val: 0 }
    }

    /// Return a FixedPoint that equals 1.
    public fun one(): FixedPoint64 {
        FixedPoint64 { val: exp(DECIMAL_PLACES) }
    }

    /// Return a FixedPoint that equals 0.5.
    public fun half(): FixedPoint64 {
        FixedPoint64 { val: one().val / 2 }
    }

    /// Returns the max FixedPoint value.
    public fun max_fp(): FixedPoint64 {
        FixedPoint64 { val: MAX_U128 }
    }

    /// Returns the min FixedPoint value.
    public fun min_fp(): FixedPoint64 {
        FixedPoint64 { val: 0 }
    }

    /// Returns a FixedPoint truncated to the given decimal places.
    public fun trunc_to_decimals(a: FixedPoint64, decimals: u8): FixedPoint64 {
        from_u128(to_u128_internal(a, decimals, MODE_TRUNCATE), decimals)
    }

    /// Returns a FixedPoint rounded up to the given decimal places.
    public fun round_up_to_decimals(a: FixedPoint64, decimals: u8): FixedPoint64 {
        from_u128(to_u128_internal(a, decimals, MODE_ROUND_UP), decimals)
    }

    /// Converts the FixedPoint to a u64 value with the given number of decimal places.
    /// Truncates any digits that are lost.
    public fun to_u64_trunc(a: FixedPoint64, decimals: u8): u64 {
        let converted = to_u128_internal(a, decimals, MODE_TRUNCATE);
        // Runtime will error on overflow.
        (converted as u64)
    }

    /// Converts the FixedPoint to a u128 value with the given number of decimal places.
    /// Truncates any digits that are lost.
    public fun to_u128_trunc(a: FixedPoint64, decimals: u8): u64 {
        let converted = to_u128_internal(a, decimals, MODE_TRUNCATE);
        // Runtime will error on overflow.
        (converted as u64)
    }

    /// Converts the FixedPoint to a u64 value with the given number of decimal places.
    /// Rounds up if digits are lost.
    public fun to_u64_round_up(a: FixedPoint64, decimals: u8): u64 {
        let converted = to_u128_internal(a, decimals, MODE_ROUND_UP);
        // Runtime will error on overflow.
        (converted as u64)
    }

    /// Converts the FixedPoint to a u128 value with the given number of decimal places.
    /// Rounds up if digits are lost.
    public fun to_u128_round_up(a: FixedPoint64, decimals: u8): u64 {
        let converted = to_u128_internal(a, decimals, MODE_ROUND_UP);
        // Runtime will error on overflow.
        (converted as u64)
    }

    /// Converts the FixedPoint to a u64 value with the given number of decimal places.
    /// Errors if any digits are lost.
    public fun to_u64(a: FixedPoint64, decimals: u8): u64 {
        let converted = to_u128_internal(a, decimals, MODE_NO_PRECISION_LOSS);
        // Runtime will error on overflow.
        (converted as u64)
    }

    /// Converts the FixedPoint to a u128 value with the given number of decimal places.
    /// Errors if any digits are lost.
    public fun to_u128(a: FixedPoint64, decimals: u8): u64 {
        let converted = to_u128_internal(a, decimals, MODE_NO_PRECISION_LOSS);
        // Runtime will error on overflow.
        (converted as u64)
    }

    /// Converts the FixedPoint to a u64 value with the given number of decimal places.
    /// Errors if any digits are lost.
    fun to_u128_internal(a: FixedPoint64, decimals: u8, mode: u8): u128 {
        assert!(decimals <= DECIMAL_PLACES, ERR_EXCEED_MAX_DECIMALS);

        let decimalMult = exp(DECIMAL_PLACES);
        let decimalMultAdj = exp(DECIMAL_PLACES - decimals);

        let intPart = a.val / decimalMult;
        let decimalPart = (a.val % decimalMult) / decimalMultAdj;

        let val = intPart * exp(decimals) + decimalPart;
        let precisionLoss = decimalPart * decimalMultAdj < a.val % decimalMult;
        if (mode == MODE_NO_PRECISION_LOSS) {
            assert!(!precisionLoss, ERR_PRECISION_LOSS);
        } else if (mode == MODE_ROUND_UP && precisionLoss) {
            val = val + 1;
        } else if (mode == MODE_TRUNCATE) {
            // No need to do anything.
        };
        val
    }

    /// Converts the value with the specified decimal places to a FixedPoint value.
    public fun from_u64(v: u64, decimals: u8): FixedPoint64 {
        from_u128((v as u128), decimals)
    }

    /// Converts the value with the specified decimal places to a FixedPoint value.
    public fun from_u128(v: u128, decimals: u8): FixedPoint64 {
        assert!(decimals <= DECIMAL_PLACES, ERR_EXCEED_MAX_DECIMALS);

        let intPart = v / exp(decimals);
        let decimalsPart = v % exp(decimals);
        // Runtime will error on overflow.
        let decimalMult = exp(DECIMAL_PLACES);
        let val = intPart * decimalMult + decimalsPart * exp(DECIMAL_PLACES - decimals);
        assert!(val <= MAX_VALUE, ERR_EXCEED_MAX);
        FixedPoint64 { val: intPart * decimalMult + decimalsPart * exp(DECIMAL_PLACES - decimals) }
    }

    /// Multiplies two FixedPoints, truncating if the number of decimal places exceeds DECIMAL_PLACES.
    public fun multiply_trunc(a: FixedPoint64, b: FixedPoint64): FixedPoint64 {
        let val = a.val * b.val / exp(DECIMAL_PLACES);
        assert!(val <= MAX_VALUE, ERR_EXCEED_MAX);
        FixedPoint64 { val }
    }

    /// Multiplies two FixedPoints, rounding up if the number of decimal places exceeds DECIMAL_PLACES.
    public fun multiply_round_up(a: FixedPoint64, b: FixedPoint64): FixedPoint64 {
        let decimalMult = exp(DECIMAL_PLACES);
        let val = a.val * b.val / decimalMult;
        if (val * decimalMult < a.val * b.val) {
            val = val + 1;
        };
        assert!(val <= MAX_VALUE, ERR_EXCEED_MAX);
        FixedPoint64 { val }
    }

    /// Divides two FixedPoints, truncating if the number of decimal places exceeds DECIMAL_PLACES.
    public fun divide_trunc(a: FixedPoint64, b: FixedPoint64): FixedPoint64 {
        let val = a.val * exp(DECIMAL_PLACES) / b.val;
        assert!(val <= MAX_VALUE, ERR_EXCEED_MAX);
        FixedPoint64 { val }
    }

    /// Divides two FixedPoints, rounding up if the number of decimal places exceeds DECIMAL_PLACES.
    public fun divide_round_up(a: FixedPoint64, b: FixedPoint64): FixedPoint64 {
        let decimalMult = exp(DECIMAL_PLACES);
        let val = a.val * decimalMult / b.val;
        if (val * b.val < a.val * decimalMult) {
            val = val + 1;
        };
        assert!(val <= MAX_VALUE, ERR_EXCEED_MAX);
        FixedPoint64 { val }
    }

    /// Adds two FixedPoints.
    public fun add(a: FixedPoint64, b: FixedPoint64): FixedPoint64 {
        // Runtime will error on overflow.
        FixedPoint64 { val: a.val + b.val }
    }

    /// Subtracts two FixedPoints.
    public fun sub(a: FixedPoint64, b: FixedPoint64): FixedPoint64 {
        // Runtime will error on overflow.
        FixedPoint64 { val: a.val - b.val }
    }

    /// Self explanatory comparison functions.

    public fun lt(a: FixedPoint64, b: FixedPoint64): bool {
        a.val < b.val
    }

    public fun lte(a: FixedPoint64, b: FixedPoint64): bool {
        a.val <= b.val
    }

    public fun gt(a: FixedPoint64, b: FixedPoint64): bool {
        a.val > b.val
    }

    public fun gte(a: FixedPoint64, b: FixedPoint64): bool {
        a.val >= b.val
    }

    public fun eq(a: FixedPoint64, b: FixedPoint64): bool {
        a.val == b.val
    }

    public fun max(a: FixedPoint64, b: FixedPoint64): FixedPoint64 {
        if (a.val >= b.val) {
            a
        } else {
            b
        }
    }

    public fun min(a: FixedPoint64, b: FixedPoint64): FixedPoint64 {
        if (a.val < b.val) {
            a
        } else {
            b
        }
    }

    /// Exponents.
    const F0 : u128 = 1;
    const F1 : u128 = 10;
    const F2 : u128 = 100;
    const F3 : u128 = 1000;
    const F4 : u128 = 10000;
    const F5 : u128 = 100000;
    const F6 : u128 = 1000000;
    const F7 : u128 = 10000000;
    const F8 : u128 = 100000000;
    const F9 : u128 = 1000000000;
    const F10: u128 = 10000000000;
    const F11: u128 = 100000000000;
    const F12: u128 = 1000000000000;
    const F13: u128 = 10000000000000;
    const F14: u128 = 100000000000000;
    const F15: u128 = 1000000000000000;
    const F16: u128 = 10000000000000000;
    const F17: u128 = 100000000000000000;
    const F18: u128 = 1000000000000000000;
    const F19: u128 = 10000000000000000000;
    const F20: u128 = 100000000000000000000;

    /// Programatic way to get a power of 10.
    fun exp(e: u8): u128 {
        assert!(e <= 20, ERR_EXCEED_MAX_EXP);

        if (e == 0) {
            F0
        } else if (e == 1) {
            F1
        } else if (e == 2) {
            F2
        } else if (e == 3) {
            F3
        } else if (e == 4) {
            F4
        } else if (e == 5) {
            F5
        } else if (e == 5) {
            F5
        } else if (e == 6) {
            F6
        } else if (e == 7) {
            F7
        } else if (e == 8) {
            F8
        } else if (e == 9) {
            F9
        } else if (e == 10) {
            F10
        } else if (e == 11) {
            F11
        } else if (e == 12) {
            F12
        } else if (e == 13) {
            F13
        } else if (e == 14) {
            F14
        } else if (e == 15) {
            F15
        } else if (e == 16) {
            F16
        } else if (e == 17) {
            F17
        } else if (e == 18) {
            F18
        } else if (e == 19) {
            F19
        } else if (e == 20) {
            F20
        } else {
            0
        }
    }

    #[test]
    fun test_from_to_integer() {
        let input = from_u64(1, 0);
        assert!(input.val == exp(DECIMAL_PLACES), 0);
        let converted = to_u64(input, 6);
        assert!(converted == 1000000, 0);
    }

    #[test]
    fun test_zero() {
        let zero = zero();
        assert!(zero.val == 0, 0);
    }

    #[test]
    fun test_one() {
        let one = one();
        assert!(one.val == 10000000000, 0);
    }

    #[test]
    fun test_half() {
        let half = half();
        assert!(half.val == 5000000000, 0);
    }

    #[test]
    #[expected_failure]
    fun test_from_large_integer() {
        from_u128(MAX_U128, 10);
    }

    #[test]
    fun test_from_to_zero() {
        let input = from_u64(0, 5);
        assert!(input.val == 0, 0);
        let converted = to_u64(input, 6);
        assert!(converted == 0, 0);
    }

    #[test]
    fun test_from_to_decimals_increase() {
        let input = from_u64(101, 1);
        assert!(input.val == 101 * exp(DECIMAL_PLACES - 1), 0);
        let converted = to_u64(input, 6);
        assert!(converted == 10100000, 0);
    }

    #[test]
    #[expected_failure]
    fun test_from_to_decimals_decrease_lose_precision() {
        let input = from_u64(100000001, 10);
        assert!(input.val == 100000001 * exp(DECIMAL_PLACES - 10), 0);
        to_u64(input, 6);
    }

    #[test]
    fun test_from_to_decimals_decrease_lose_precision_round_up() {
        let input = from_u64(100000001, 10);
        assert!(input.val == 100000001 * exp(DECIMAL_PLACES - 10), 0);
        assert!(to_u64_round_up(input, 6) == 10001, 0);
    }

    #[test]
    fun test_from_to_decimals_decrease_lose_precision_truncate() {
        let input = from_u64(100000001, 10);
        assert!(input.val == 100000001 * exp(DECIMAL_PLACES - 10), 0);
        assert!(to_u64_trunc(input, 6) == 10000, 0);
    }

    #[test]
    fun test_multiply() {
        let a = from_u64(1056, 0);
        let b = from_u64(2056, 0);
        let product = multiply_trunc(a, b);
        assert!(to_u64(product, 0) == 2171136, 0);
    }

    #[test]
    fun test_multiply_with_decimals() {
        let a = from_u64(1056, 3);
        let b = from_u64(2056, 6);
        let product = multiply_trunc(a, b);
        assert!(to_u64(product, 0) == 2171136, 0);
    }

    #[test]
    fun test_multiply_round_up() {
        let a = from_u64(1, 10);
        let b = from_u64(1, 10);
        let product = multiply_trunc(a, b);
        assert!(to_u64(product, 0) == 0, 0);
        product = multiply_round_up(a, b);
        assert!(to_u64(product, 10) == 1, 0);
    }

    #[test]
    fun test_square_root_of_max() {
        // Note, isn't the exact root of MAX_U64.
        let a = from_u128(4294967295, 5);
        let product = multiply_trunc(a, a);
        assert!(to_u128(product, 10) == 18446744065119617025, 0);
    }

    #[test]
    #[expected_failure]
    fun test_square_root_of_max_plus_1() {
        let a = from_u128(4294967296, 5);
        multiply_trunc(a, a);
    }

    #[test]
    fun test_divide_trunc() {
        let a = from_u64(1056, 0);
        let b = from_u64(2056, 0);
        let q = divide_trunc(b, a);
        assert!(q.val == 19469696969, 0);
    }

    #[test]
    fun test_divide_round_up() {
        let a = from_u64(1056, 0);
        let b = from_u64(2056, 0);
        let q = divide_round_up(b, a);
        assert!(q.val == 19469696970, 0);
    }

    #[test]
    fun test_trunc_round_up_to_decimals() {
        let a = from_u64(1056, 3);
        assert!(trunc_to_decimals(a, 1).val == 10000000000, 0);
        assert!(round_up_to_decimals(a, 1).val == 11000000000, 0);

        let b = from_u64(1534, 2);
        assert!(trunc_to_decimals(b, 3).val == 153400000000, 0);
        assert!(round_up_to_decimals(b, 1).val == 154000000000, 0);
    }

    #[test]
    #[expected_failure]
    fun test_divide_exceed_max() {
        let a = from_u64(1, 10);
        let b = max_fp();
        divide_trunc(b, a);
    }
}