#!/usr/bin/env bash
set -euo pipefail

NIXOS=/etc/nixos/

echo "Checking configuration"
./check.sh

echo "Syncing files to ${NIXOS}"
sudo rsync -avR $(fd .nix) modules i3 $NIXOS

sudo nixos-rebuild "$@"
