#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

echo "Checking configuration"
./check.sh

export NIXOS_LABEL="$(jj log --no-graph -r @ | tail -n 1 | sed 's/[^a-zA-Z0-9]/-/g' | sed 's/-\{2,\}/-/g' | sed 's/^-//;s/-$//')"
echo "Generation label: $NIXOS_LABEL"
sudo NIXOS_LABEL="$NIXOS_LABEL" nixos-rebuild "$@" -I nixos-config="$PWD/configuration.nix"

