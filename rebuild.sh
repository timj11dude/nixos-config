#!/usr/bin/env bash

NIXOS=/etc/nixos/

echo "Syncing files to ${NIXOS}"
sudo rsync -avR $(fd .nix) modules $NIXOS

sudo nixos-rebuild $@