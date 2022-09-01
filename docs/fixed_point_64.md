---
description: ferum_std::fixed_point_64
---


<a name="@fixedpoint64"></a>

# FixedPoint64


Ferum's implementation of a FixedPoint number.
Has fixed decimal places of 10 and a max value of
<code>MAX_U64 (18446744073709551615)</code>.

Operations that result in an overflow will error out.


<a name="@quick-example"></a>

# Quick Example


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




<a name="ferum_std_fixed_point_64_FixedPoint64"></a>

# Struct `FixedPoint64`

Fixedpoint struct. Can be stored, copied, and dropped.


<pre><code><b>struct</b> <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">FixedPoint64</a> <b>has</b> <b>copy</b>, drop, store
</code></pre>



<a name="@constants"></a>

# Constants


<a name="@decimal_places"></a>

## DECIMAL_PLACES


<a name="ferum_std_fixed_point_64_DECIMAL_PLACES"></a>

Number of decimal places in a FixedPoint value.


<pre><code><b>const</b> <a href="fixed_point_64.md#ferum_std_fixed_point_64_DECIMAL_PLACES">DECIMAL_PLACES</a>: u8 = 10;
</code></pre>



<a name="@err_exceed_max"></a>

## ERR_EXCEED_MAX


<a name="ferum_std_fixed_point_64_ERR_EXCEED_MAX"></a>

Thrown when the value of a FixedPoint64 exceeds the [max value](#max_value)
able to be represented.


<pre><code><b>const</b> <a href="fixed_point_64.md#ferum_std_fixed_point_64_ERR_EXCEED_MAX">ERR_EXCEED_MAX</a>: u64 = 4;
</code></pre>



<a name="@err_exceed_max_decimals"></a>

## ERR_EXCEED_MAX_DECIMALS


<a name="ferum_std_fixed_point_64_ERR_EXCEED_MAX_DECIMALS"></a>

Thrown when max decimals of FixedPoint64 is exceeded.
Possible examples:
- if trying to create a FixedPoint64 from a 12 decimal number
- if multiplying two 6 decimal numbers together


<pre><code><b>const</b> <a href="fixed_point_64.md#ferum_std_fixed_point_64_ERR_EXCEED_MAX_DECIMALS">ERR_EXCEED_MAX_DECIMALS</a>: u64 = 1;
</code></pre>



<a name="@err_exceed_max_exp"></a>

## ERR_EXCEED_MAX_EXP


<a name="ferum_std_fixed_point_64_ERR_EXCEED_MAX_EXP"></a>

Because move doesn't have a native power function, we need to hardcode powers of 10.
Thrown if we try to get a power of 10 that is not hardcoded.


<pre><code><b>const</b> <a href="fixed_point_64.md#ferum_std_fixed_point_64_ERR_EXCEED_MAX_EXP">ERR_EXCEED_MAX_EXP</a>: u64 = 2;
</code></pre>



<a name="@err_precision_loss"></a>

## ERR_PRECISION_LOSS


<a name="ferum_std_fixed_point_64_ERR_PRECISION_LOSS"></a>

Thrown when decimals are lost and not truncating or rounding up.
Possible examples:
- calling <code>[<a href="fixed_point_64.md#ferum_std_fixed_point_64_to_u64">to_u64</a>()](#function-to_u64)</code> to convert a number that has 6 decimal
places into 5 decimal places, losing a digit
- Dividing a number with 10 decimal places by 0.01, exceeding the max decimal places
FixedPoint64 can represent.


<pre><code><b>const</b> <a href="fixed_point_64.md#ferum_std_fixed_point_64_ERR_PRECISION_LOSS">ERR_PRECISION_LOSS</a>: u64 = 3;
</code></pre>



<a name="@max_value"></a>

## MAX_VALUE


<a name="ferum_std_fixed_point_64_MAX_VALUE"></a>

Max value a FixedPoint can represent.


<pre><code><b>const</b> <a href="fixed_point_64.md#ferum_std_fixed_point_64_MAX_VALUE">MAX_VALUE</a>: u128 = 18446744073709551615;
</code></pre>



<a name="@functions"></a>

# Functions


<a name="ferum_std_fixed_point_64_new_u64"></a>

## Function `new_u64`

Create a new FixedPoint from a u64 value. No conversion is performed.
Example: <code><a href="fixed_point_64.md#ferum_std_fixed_point_64_new_u64">new_u64</a>(12345) == 0.0000012345</code>


<pre><code><b>public</b> <b>fun</b> <a href="fixed_point_64.md#ferum_std_fixed_point_64_new_u64">new_u64</a>(val: u64): <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>
</code></pre>



<a name="ferum_std_fixed_point_64_new_u128"></a>

## Function `new_u128`

Create a new FixedPoint from a u128 value. No conversion is performed.
Example: <code><a href="fixed_point_64.md#ferum_std_fixed_point_64_new_u128">new_u128</a>(12345) == 0.0000012345</code>


<pre><code><b>public</b> <b>fun</b> <a href="fixed_point_64.md#ferum_std_fixed_point_64_new_u128">new_u128</a>(val: u128): <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>
</code></pre>



<a name="ferum_std_fixed_point_64_value"></a>

## Function `value`

Return then underlying value of the FixedPoint.


<pre><code><b>public</b> <b>fun</b> <a href="fixed_point_64.md#ferum_std_fixed_point_64_value">value</a>(a: <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>): u128
</code></pre>



<a name="ferum_std_fixed_point_64_zero"></a>

## Function `zero`

Return a FixedPoint that equals 0.


<pre><code><b>public</b> <b>fun</b> <a href="fixed_point_64.md#ferum_std_fixed_point_64_zero">zero</a>(): <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>
</code></pre>



<a name="ferum_std_fixed_point_64_one"></a>

## Function `one`

Return a FixedPoint that equals 1.


<pre><code><b>public</b> <b>fun</b> <a href="fixed_point_64.md#ferum_std_fixed_point_64_one">one</a>(): <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>
</code></pre>



<a name="ferum_std_fixed_point_64_half"></a>

## Function `half`

Return a FixedPoint that equals 0.5.


<pre><code><b>public</b> <b>fun</b> <a href="fixed_point_64.md#ferum_std_fixed_point_64_half">half</a>(): <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>
</code></pre>



<a name="ferum_std_fixed_point_64_max_fp"></a>

## Function `max_fp`

Returns the max FixedPoint value.


<pre><code><b>public</b> <b>fun</b> <a href="fixed_point_64.md#ferum_std_fixed_point_64_max_fp">max_fp</a>(): <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>
</code></pre>



<a name="ferum_std_fixed_point_64_min_fp"></a>

## Function `min_fp`

Returns the min FixedPoint value.


<pre><code><b>public</b> <b>fun</b> <a href="fixed_point_64.md#ferum_std_fixed_point_64_min_fp">min_fp</a>(): <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>
</code></pre>



<a name="ferum_std_fixed_point_64_trunc_to_decimals"></a>

## Function `trunc_to_decimals`

Returns a FixedPoint truncated to the given decimal places.


<pre><code><b>public</b> <b>fun</b> <a href="fixed_point_64.md#ferum_std_fixed_point_64_trunc_to_decimals">trunc_to_decimals</a>(a: <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>, decimals: u8): <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>
</code></pre>



<a name="ferum_std_fixed_point_64_round_up_to_decimals"></a>

## Function `round_up_to_decimals`

Returns a FixedPoint rounded up to the given decimal places.


<pre><code><b>public</b> <b>fun</b> <a href="fixed_point_64.md#ferum_std_fixed_point_64_round_up_to_decimals">round_up_to_decimals</a>(a: <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>, decimals: u8): <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>
</code></pre>



<a name="ferum_std_fixed_point_64_to_u64_trunc"></a>

## Function `to_u64_trunc`

Converts the FixedPoint to a u64 value with the given number of decimal places.
Truncates any digits that are lost.


<pre><code><b>public</b> <b>fun</b> <a href="fixed_point_64.md#ferum_std_fixed_point_64_to_u64_trunc">to_u64_trunc</a>(a: <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>, decimals: u8): u64
</code></pre>



<a name="ferum_std_fixed_point_64_to_u128_trunc"></a>

## Function `to_u128_trunc`

Converts the FixedPoint to a u128 value with the given number of decimal places.
Truncates any digits that are lost.


<pre><code><b>public</b> <b>fun</b> <a href="fixed_point_64.md#ferum_std_fixed_point_64_to_u128_trunc">to_u128_trunc</a>(a: <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>, decimals: u8): u64
</code></pre>



<a name="ferum_std_fixed_point_64_to_u64_round_up"></a>

## Function `to_u64_round_up`

Converts the FixedPoint to a u64 value with the given number of decimal places.
Rounds up if digits are lost.


<pre><code><b>public</b> <b>fun</b> <a href="fixed_point_64.md#ferum_std_fixed_point_64_to_u64_round_up">to_u64_round_up</a>(a: <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>, decimals: u8): u64
</code></pre>



<a name="ferum_std_fixed_point_64_to_u128_round_up"></a>

## Function `to_u128_round_up`

Converts the FixedPoint to a u128 value with the given number of decimal places.
Rounds up if digits are lost.


<pre><code><b>public</b> <b>fun</b> <a href="fixed_point_64.md#ferum_std_fixed_point_64_to_u128_round_up">to_u128_round_up</a>(a: <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>, decimals: u8): u64
</code></pre>



<a name="ferum_std_fixed_point_64_to_u64"></a>

## Function `to_u64`

Converts the FixedPoint to a u64 value with the given number of decimal places.
Errors if any digits are lost.


<pre><code><b>public</b> <b>fun</b> <a href="fixed_point_64.md#ferum_std_fixed_point_64_to_u64">to_u64</a>(a: <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>, decimals: u8): u64
</code></pre>



<a name="ferum_std_fixed_point_64_to_u128"></a>

## Function `to_u128`

Converts the FixedPoint to a u128 value with the given number of decimal places.
Errors if any digits are lost.


<pre><code><b>public</b> <b>fun</b> <a href="fixed_point_64.md#ferum_std_fixed_point_64_to_u128">to_u128</a>(a: <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>, decimals: u8): u64
</code></pre>



<a name="ferum_std_fixed_point_64_from_u64"></a>

## Function `from_u64`

Converts the value with the specified decimal places to a FixedPoint value.


<pre><code><b>public</b> <b>fun</b> <a href="fixed_point_64.md#ferum_std_fixed_point_64_from_u64">from_u64</a>(v: u64, decimals: u8): <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>
</code></pre>



<a name="ferum_std_fixed_point_64_from_u128"></a>

## Function `from_u128`

Converts the value with the specified decimal places to a FixedPoint value.


<pre><code><b>public</b> <b>fun</b> <a href="fixed_point_64.md#ferum_std_fixed_point_64_from_u128">from_u128</a>(v: u128, decimals: u8): <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>
</code></pre>



<a name="ferum_std_fixed_point_64_multiply_trunc"></a>

## Function `multiply_trunc`

Multiplies two FixedPoints, truncating if the number of decimal places exceeds DECIMAL_PLACES.


<pre><code><b>public</b> <b>fun</b> <a href="fixed_point_64.md#ferum_std_fixed_point_64_multiply_trunc">multiply_trunc</a>(a: <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>, b: <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>): <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>
</code></pre>



<a name="ferum_std_fixed_point_64_multiply_round_up"></a>

## Function `multiply_round_up`

Multiplies two FixedPoints, rounding up if the number of decimal places exceeds DECIMAL_PLACES.


<pre><code><b>public</b> <b>fun</b> <a href="fixed_point_64.md#ferum_std_fixed_point_64_multiply_round_up">multiply_round_up</a>(a: <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>, b: <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>): <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>
</code></pre>



<a name="ferum_std_fixed_point_64_divide_trunc"></a>

## Function `divide_trunc`

Divides two FixedPoints, truncating if the number of decimal places exceeds DECIMAL_PLACES.


<pre><code><b>public</b> <b>fun</b> <a href="fixed_point_64.md#ferum_std_fixed_point_64_divide_trunc">divide_trunc</a>(a: <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>, b: <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>): <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>
</code></pre>



<a name="ferum_std_fixed_point_64_divide_round_up"></a>

## Function `divide_round_up`

Divides two FixedPoints, rounding up if the number of decimal places exceeds DECIMAL_PLACES.


<pre><code><b>public</b> <b>fun</b> <a href="fixed_point_64.md#ferum_std_fixed_point_64_divide_round_up">divide_round_up</a>(a: <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>, b: <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>): <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>
</code></pre>



<a name="ferum_std_fixed_point_64_add"></a>

## Function `add`

Adds two FixedPoints.


<pre><code><b>public</b> <b>fun</b> <a href="fixed_point_64.md#ferum_std_fixed_point_64_add">add</a>(a: <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>, b: <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>): <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>
</code></pre>



<a name="ferum_std_fixed_point_64_sub"></a>

## Function `sub`

Subtracts two FixedPoints.


<pre><code><b>public</b> <b>fun</b> <a href="fixed_point_64.md#ferum_std_fixed_point_64_sub">sub</a>(a: <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>, b: <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>): <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>
</code></pre>



<a name="ferum_std_fixed_point_64_lt"></a>

## Function `lt`

Return true if a < b.


<pre><code><b>public</b> <b>fun</b> <a href="fixed_point_64.md#ferum_std_fixed_point_64_lt">lt</a>(a: <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>, b: <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>): bool
</code></pre>



<a name="ferum_std_fixed_point_64_lte"></a>

## Function `lte`

Return true if a <= b.


<pre><code><b>public</b> <b>fun</b> <a href="fixed_point_64.md#ferum_std_fixed_point_64_lte">lte</a>(a: <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>, b: <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>): bool
</code></pre>



<a name="ferum_std_fixed_point_64_gt"></a>

## Function `gt`

Return true if a > b.


<pre><code><b>public</b> <b>fun</b> <a href="fixed_point_64.md#ferum_std_fixed_point_64_gt">gt</a>(a: <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>, b: <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>): bool
</code></pre>



<a name="ferum_std_fixed_point_64_gte"></a>

## Function `gte`

Return true if a >= b.


<pre><code><b>public</b> <b>fun</b> <a href="fixed_point_64.md#ferum_std_fixed_point_64_gte">gte</a>(a: <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>, b: <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>): bool
</code></pre>



<a name="ferum_std_fixed_point_64_eq"></a>

## Function `eq`

Return true if a == b.


<pre><code><b>public</b> <b>fun</b> <a href="fixed_point_64.md#ferum_std_fixed_point_64_eq">eq</a>(a: <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>, b: <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>): bool
</code></pre>



<a name="ferum_std_fixed_point_64_max"></a>

## Function `max`

Returns max(a, b).


<pre><code><b>public</b> <b>fun</b> <a href="fixed_point_64.md#ferum_std_fixed_point_64_max">max</a>(a: <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>, b: <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>): <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>
</code></pre>



<a name="ferum_std_fixed_point_64_min"></a>

## Function `min`

Returns min(a, b).


<pre><code><b>public</b> <b>fun</b> <b>min</b>(a: <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>, b: <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>): <a href="fixed_point_64.md#ferum_std_fixed_point_64_FixedPoint64">fixed_point_64::FixedPoint64</a>
</code></pre>
