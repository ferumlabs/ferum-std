# FixedPoint64

Ferum's implementation of a FixedPoint number. Has fixed decimal places of 10 and a max value of `MAX_U64 (18446744073709551615)`.

Operations that result in an overflow will error out.

## Quick Example

```
use ferum_std::fixed_point_64::{Self, FixedPoint64};

/// Create fixed points from input.
let a = fixed_point_64::from_u64(1024, 3); // 1.024
let b = fixed_point_64::from_u64(2056, 2); // 20.56

// Compare two numbers
assert!(fixed_point_64::lte(a, b), 0);
assert!(!fixed_point_64::gte(a, b), 0);

// Get min/max of two fixed points. 
let min = fixed_point_64::min(a, b);
let max = fixed_point_64::max(a, b);

// Perform addition / subtraction.
let added =  fixed_point_64::add(a, b);
let subtracted = fixed_point_64::sub(b, a);

// Perform multiplication / division with support for rounding up or truncating.
let multipliedRounded = fixed_point_64::multiply_round_up(a, a);
let multipliedTruncated = fixed_point_64::multiply_round_up(a, a);
let dividedRounded = fixed_point_64::divide_round_up(b, a);
let dividedTruncated = fixed_point_64::divide_trunc(b, a);

// Convert back to integers.
let au64 = fixed_point_64::to_u64(a, 3);
let bu64 = fixed_point_64::to_u64(b, 2);
```

## Struct `FixedPoint64`

Fixedpoint struct. Can be stored, copied, and dropped.

```
struct FixedPoint64 has copy, drop, store
```

## Constants

### DECIMAL\_PLACES

Number of decimal places in a FixedPoint value.

```
const DECIMAL_PLACES: u8 = 10;
```

### ERR\_EXCEED\_MAX

Thrown when the value of a FixedPoint64 exceeds the [max value](fixed\_point\_64.md#max\_value) able to be represented.

```
const ERR_EXCEED_MAX: u64 = 4;
```

### ERR\_EXCEED\_MAX\_DECIMALS

Thrown when max decimals of FixedPoint64 is exceeded. Possible examples:

* if trying to create a FixedPoint64 from a 12 decimal number
* if multiplying two 6 decimal numbers together

```
const ERR_EXCEED_MAX_DECIMALS: u64 = 1;
```

### ERR\_EXCEED\_MAX\_EXP

Because move doesn't have a native power function, we need to hardcode powers of 10. Thrown if we try to get a power of 10 that is not hardcoded.

```
const ERR_EXCEED_MAX_EXP: u64 = 2;
```

### ERR\_PRECISION\_LOSS

Thrown when decimals are lost and not truncating or rounding up. Possible examples:

* calling [`to_u64`](fixed\_point\_64.md#ferum\_std\_fixed\_point\_64\_to\_u64)`()` to convert a number that has 6 decimal places into 5 decimal places, losing a digit
* Dividing a number with 10 decimal places by 0.01, exceeding the max decimal places FixedPoint64 can represent.

```
const ERR_PRECISION_LOSS: u64 = 3;
```

### MAX\_VALUE

Max value a FixedPoint can represent.

```
const MAX_VALUE: u128 = 18446744073709551615;
```

## Functions

### Function `new_u64`

Create a new FixedPoint from a u64 value. No conversion is performed. Example: [`new_u64`](fixed\_point\_64.md#ferum\_std\_fixed\_point\_64\_new\_u64)`(12345) == 0.0000012345`

```
public fun new_u64(val: u64): fixed_point_64::FixedPoint64
```

### Function `new_u128`

Create a new FixedPoint from a u128 value. No conversion is performed. Example: [`new_u128`](fixed\_point\_64.md#ferum\_std\_fixed\_point\_64\_new\_u128)`(12345) == 0.0000012345`

```
public fun new_u128(val: u128): fixed_point_64::FixedPoint64
```

### Function `value`

Return then underlying value of the FixedPoint.

```
public fun value(a: fixed_point_64::FixedPoint64): u128
```

### Function `zero`

Return a FixedPoint that equals 0.

```
public fun zero(): fixed_point_64::FixedPoint64
```

### Function `one`

Return a FixedPoint that equals 1.

```
public fun one(): fixed_point_64::FixedPoint64
```

### Function `half`

Return a FixedPoint that equals 0.5.

```
public fun half(): fixed_point_64::FixedPoint64
```

### Function `max_fp`

Returns the max FixedPoint value.

```
public fun max_fp(): fixed_point_64::FixedPoint64
```

### Function `min_fp`

Returns the min FixedPoint value.

```
public fun min_fp(): fixed_point_64::FixedPoint64
```

### Function `trunc_to_decimals`

Returns a FixedPoint truncated to the given decimal places.

```
public fun trunc_to_decimals(a: fixed_point_64::FixedPoint64, decimals: u8): fixed_point_64::FixedPoint64
```

### Function `round_up_to_decimals`

Returns a FixedPoint rounded up to the given decimal places.

```
public fun round_up_to_decimals(a: fixed_point_64::FixedPoint64, decimals: u8): fixed_point_64::FixedPoint64
```

### Function `to_u64_trunc`

Converts the FixedPoint to a u64 value with the given number of decimal places. Truncates any digits that are lost.

```
public fun to_u64_trunc(a: fixed_point_64::FixedPoint64, decimals: u8): u64
```

### Function `to_u128_trunc`

Converts the FixedPoint to a u128 value with the given number of decimal places. Truncates any digits that are lost.

```
public fun to_u128_trunc(a: fixed_point_64::FixedPoint64, decimals: u8): u64
```

### Function `to_u64_round_up`

Converts the FixedPoint to a u64 value with the given number of decimal places. Rounds up if digits are lost.

```
public fun to_u64_round_up(a: fixed_point_64::FixedPoint64, decimals: u8): u64
```

### Function `to_u128_round_up`

Converts the FixedPoint to a u128 value with the given number of decimal places. Rounds up if digits are lost.

```
public fun to_u128_round_up(a: fixed_point_64::FixedPoint64, decimals: u8): u64
```

### Function `to_u64`

Converts the FixedPoint to a u64 value with the given number of decimal places. Errors if any digits are lost.

```
public fun to_u64(a: fixed_point_64::FixedPoint64, decimals: u8): u64
```

### Function `to_u128`

Converts the FixedPoint to a u128 value with the given number of decimal places. Errors if any digits are lost.

```
public fun to_u128(a: fixed_point_64::FixedPoint64, decimals: u8): u64
```

### Function `from_u64`

Converts the value with the specified decimal places to a FixedPoint value.

```
public fun from_u64(v: u64, decimals: u8): fixed_point_64::FixedPoint64
```

### Function `from_u128`

Converts the value with the specified decimal places to a FixedPoint value.

```
public fun from_u128(v: u128, decimals: u8): fixed_point_64::FixedPoint64
```

### Function `multiply_trunc`

Multiplies two FixedPoints, truncating if the number of decimal places exceeds DECIMAL\_PLACES.

```
public fun multiply_trunc(a: fixed_point_64::FixedPoint64, b: fixed_point_64::FixedPoint64): fixed_point_64::FixedPoint64
```

### Function `multiply_round_up`

Multiplies two FixedPoints, rounding up if the number of decimal places exceeds DECIMAL\_PLACES.

```
public fun multiply_round_up(a: fixed_point_64::FixedPoint64, b: fixed_point_64::FixedPoint64): fixed_point_64::FixedPoint64
```

### Function `divide_trunc`

Divides two FixedPoints, truncating if the number of decimal places exceeds DECIMAL\_PLACES.

```
public fun divide_trunc(a: fixed_point_64::FixedPoint64, b: fixed_point_64::FixedPoint64): fixed_point_64::FixedPoint64
```

### Function `divide_round_up`

Divides two FixedPoints, rounding up if the number of decimal places exceeds DECIMAL\_PLACES.

```
public fun divide_round_up(a: fixed_point_64::FixedPoint64, b: fixed_point_64::FixedPoint64): fixed_point_64::FixedPoint64
```

### Function `add`

Adds two FixedPoints.

```
public fun add(a: fixed_point_64::FixedPoint64, b: fixed_point_64::FixedPoint64): fixed_point_64::FixedPoint64
```

### Function `sub`

Subtracts two FixedPoints.

```
public fun sub(a: fixed_point_64::FixedPoint64, b: fixed_point_64::FixedPoint64): fixed_point_64::FixedPoint64
```

### Function `lt`

Return true if a < b.

```
public fun lt(a: fixed_point_64::FixedPoint64, b: fixed_point_64::FixedPoint64): bool
```

### Function `lte`

Return true if a <= b.

```
public fun lte(a: fixed_point_64::FixedPoint64, b: fixed_point_64::FixedPoint64): bool
```

### Function `gt`

Return true if a > b.

```
public fun gt(a: fixed_point_64::FixedPoint64, b: fixed_point_64::FixedPoint64): bool
```

### Function `gte`

Return true if a >= b.

```
public fun gte(a: fixed_point_64::FixedPoint64, b: fixed_point_64::FixedPoint64): bool
```

### Function `eq`

Return true if a == b.

```
public fun eq(a: fixed_point_64::FixedPoint64, b: fixed_point_64::FixedPoint64): bool
```

### Function `max`

Returns max(a, b).

```
public fun max(a: fixed_point_64::FixedPoint64, b: fixed_point_64::FixedPoint64): fixed_point_64::FixedPoint64
```

### Function `min`

Returns min(a, b).

```
public fun min(a: fixed_point_64::FixedPoint64, b: fixed_point_64::FixedPoint64): fixed_point_64::FixedPoint64
```
