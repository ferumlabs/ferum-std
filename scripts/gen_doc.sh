#!/usr/bin/env bash

if ! [[ $(move --version) =~ "ferum" ]]; then
   echo "Install the ferum version of the move cli"
   exit 1
fi

# Need to temporarily replace the module addresses defined in Move.toml.
sed -i '' 's/.*ferum_std=.*/ferum_std="0x1"/g' Move.toml

move docgen --exclude-impl --exclude-specs --exclude-private-fun --module-name ferum_std --section-level-start 0

# Restore Move.toml
git checkout Move.toml
