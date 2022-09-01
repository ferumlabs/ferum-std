# Ferum Standard Library
Move is an awesome langauge, but since the ecosystem is still early, it's missing some fundemental pieces. Ferum STD is our way of giving back to the community by open sourcing core components that we've built in house for everyone's use. If you have any questions or concerns, [join our discord](https://discord.gg/rk9T4MuppY) and also, [follow us on twitter](twitter.com/ferumxyz) for updates. 


## List of Open Source Implementations 

* [`ferum_std::fixed_point_64`](https://github.com/ferum-dex/ferum-std/blob/main/README.md#fixedpoint) — Ferum's implementation of FixedPoint helping to managing decimal points represented as integers. 

## Installing

1. Add `FerumSTD` in your [`Move.toml`](https://move-language.github.io/move/packages.html#movetoml) as a depdency following the example below:

```
[dependencies]
AptosFramework = { git = "https://github.com/aptos-labs/aptos-core.git", subdir = "aptos-move/framework/aptos-framework/", rev = "devnet" }
FerumSTD = { git = "https://github.com/ferum-dex/ferum-std.git", rev = "main" }
```
2. Run `aptos move compile`; sometimes you may need to run `aptos move clean`. 
2. Inside your module, add `use ferum_std::fixed_point_64::{Self, FixedPoint64};`
3. Now you can create a fixed point via `let priceFixedPoint = fixed_point_64::from_u64(price, book.qDecimals);`


## Examples

### FixedPoint

```Move

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


## Contributing

We welcome all contributions; just make sure that you add unit tests to all new code added, and run `aptos move test` before making a pull request. All updates must be backwards compatible. 
