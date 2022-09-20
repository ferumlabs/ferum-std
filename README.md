# Ferum Standard Library

Move is an awesome langauge, but since the ecosystem is still early, it's missing some fundemental pieces. Ferum STD is our way of giving back to the community by open sourcing core components that we've built in house for everyone's use. If you have any questions or concerns, [join our discord](https://discord.gg/rk9T4MuppY) and also, [follow us on twitter](twitter.com/ferumxyz/) for updates!

## List of Modules

* [`ferum_std::fixed_point_64`](./#fixed-point) — Ferum's implementation of FixedPoint, helping manage decimal points represented as integers.
* [`ferum_std::red_black_tree`](./#red-black-tree) — Ferum's implementation of Red Black Trees, a self-balancing binary search tree.
* [`ferum_std::linked_lisr`](./#linked-list) — Ferum's implementation of a Linked List.

## Installing

1\. Add `FerumSTD` in your [`Move.toml`](https://move-language.github.io/move/packages.html#movetoml) as a depdency following the example below:

```
[dependencies]
AptosFramework = { git = "https://github.com/aptos-labs/aptos-core.git", subdir = "aptos-move/framework/aptos-framework/", rev = "devnet" }
FerumSTD = { git = "https://github.com/ferum-dex/ferum-std.git", rev = "main" }
```

Use `FerumSTD = { git = "https://github.com/ferum-dex/ferum-std.git", rev = "main" }` for mainnet and `FerumSTD = { git = "https://github.com/ferum-dex/ferum-std.git", rev = "devnet" }` for devnet.

2\. Run `aptos move compile`; sometimes you may need to run `aptos move clean`.

3\. Import a module and start using it. For example:

```
use ferum_std::fixed_point_64::{Self, FixedPoint64};
...
let one = fixed_point_64::from_u64(1000, 3);
```

## Documentation

There are some quick examples below for each module, but if you want to see more extensive docs for all the functions, checkout the [Ferum Standard Library Docs](https://ferum.gitbook.io/ferum-standard-library/).

## Quick Examples

### Fixed Point ([Full Docs](docs/fixed\_point\_64.md))

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

### Red Black Tree ([Full Docs](docs/red\_black\_tree.md))

```
use ferum_std::red_black_tree::{Self, Tree};

// Create a tree with u128 values.
let tree = red_black_tree::new<u128>();

// Insert
red_black_tree::insert(&mut tree, 100, 50);
red_black_tree::insert(&mut tree, 100, 40);
red_black_tree::insert(&mut tree, 120, 10);
red_black_tree::insert(&mut tree, 90, 5);

// Get min/max
let min = red_black_tree::min_key(&tree);
assert!(min == 90, 0);
let max = red_black_tree::max_key(&tree);
assert!(max == 90, 0);

// Delete values and keys.
red_black_tree::delete_value(&mut tree, 100, 40);
red_black_tree::delete_key(&mut tree, 90);
let min = red_black_tree::min_key(&tree);
assert!(min == 100, 0);
```

### Linked List ([Full Docs](docs/linked\_list.md))

```
use ferum_std::linked_list::{Self, List};

// Create a list with u128 values.
let list = linked_list::new<u128>();

// Add values
linked_list::add(&mut list, 100);
linked_list::add(&mut list, 50);
linked_list::add(&mut list, 20);
linked_list::add(&mut list, 200);
linked_list::add(&mut list, 100); // Duplicate

print_list(&list) // 100 <-> 50 <-> 20 <-> 200 <-> 100

// Get length of list.
linked_list::length(&list) // == 4

// Check if list contains value.
linked_list::contains(&list, 100) // true
linked_list::contains(&list, 10-0) // false

// Remove last
linked_list::remove_last(&list);
print_list(&list) // 100 <-> 50 <-> 20 <-> 200

// Remove first
linked_list::remove_first(&list);
print_list(&list) // 50 <-> 20 <-> 200
```

## Contributing

We welcome all contributions; just make sure that you add unit tests to all new code added, and run `aptos move test` before making a pull request. All updates must be backwards compatible.
