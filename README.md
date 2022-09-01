# Ferum Standard Library

Move is an awesome langauge, but since the ecosystem is still early, it's missing some fundemental pieces. Ferum STD is our way of giving back to the community by open sourcing core components that we've built in house for everyone's use. If you have any questions or concerns, [join our discord](https://discord.gg/rk9T4MuppY) and also, [follow us on twitter](twitter.com/ferumxyz/) for updates.

[View on Gitbook](https://ferum.gitbook.io/ferum-standard-library/)

## List of Modules

* [`ferum_std::fixed_point_64`](docs/fixed\_point\_64.md) — Ferum's implementation of FixedPoint, helping manage decimal points represented as integers.

## Installing

1\. Add `FerumSTD` in your [`Move.toml`](https://move-language.github.io/move/packages.html#movetoml) as a depdency following the example below:

```
[dependencies]
AptosFramework = { git = "https://github.com/aptos-labs/aptos-core.git", subdir = "aptos-move/framework/aptos-framework/", rev = "devnet" }
FerumSTD = { git = "https://github.com/ferum-dex/ferum-std.git", rev = "main" }
```

2\. Run `aptos move compile`; sometimes you may need to run `aptos move clean`.

3\. Import a module and start using it. For example: &#x20;

```
use ferum_std::fixed_point_64::{Self, FixedPoint64};
...
let one = fixed_point_64::from_u64(100, 3);
```

## Contributing

We welcome all contributions; just make sure that you add unit tests to all new code added, and run `aptos move test` before making a pull request. All updates must be backwards compatible.
