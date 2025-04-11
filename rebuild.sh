#!/usr/bin/env bash

NIXOS=/etc/nixos/
DIRECTORIES=$(fd --type d)
FILES=$(fd .nix)

echo "moving files to ${NIXOS}"
sudo cp $FILES $NIXOS
sudo cp -r $DIRECTORIES $NIXOS

sudo nixos-rebuild $@