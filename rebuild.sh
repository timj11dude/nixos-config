#!/usr/bin/env bash

NIXOS=/etc/nixos/

echo "Syncing files to ${NIXOS}"
sudo rsync -avR $(fd .nix) modules i3 $NIXOS

sudo nixos-rebuild $@
