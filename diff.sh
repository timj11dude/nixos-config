#!/usr/bin/env bash

NIXOS=/etc/nixos/
DIRECTORIES=$(fd --type d)
FILES=$(fd .nix)

TEMP=`mktemp -d`
rsync -avR $(fd .nix) modules $TEMP

diff -qr $NIXOS $TEMP
