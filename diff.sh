#!/usr/bin/env bash

NIXOS=/etc/nixos/
DIRECTORIES=$(fd --type d)
FILES=$(fd .nix)

TEMP=`mktemp -d`
cp $FILES $TEMP
cp -r $DIRECTORIES $TEMP

diff -qr $NIXOS $TEMP