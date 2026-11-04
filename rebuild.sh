#!/usr/bin/env bash
set -euo pipefail

NIXOS=/etc/nixos/

echo "Checking configuration"
./check.sh

echo "Syncing files to ${NIXOS}"
sudo rsync -avR $(fd .nix) modules i3 $NIXOS

export NIXOS_LABEL="$(jj log --no-graph -r @ | tail -n 1 | sed 's/[^a-zA-Z0-9]/-/g' | sed 's/-\{2,\}/-/g' | sed 's/^-//;s/-$//')"
echo "Generation label: $NIXOS_LABEL"
sudo NIXOS_LABEL="$NIXOS_LABEL" nixos-rebuild "$@"

