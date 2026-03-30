#!/bin/bash

CHANNEL=${1-'mojo-community'}
echo "Publishing packages to: $CHANNEL"
# ignore errors because we want to ignore duplicate packages
for file in $CONDA_BLD_PATH/**/*.conda; do
    pixi upload prefix -c "$CHANNEL" "$file" || true
done

rm $CONDA_BLD_PATH/**/*.conda