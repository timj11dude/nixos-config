#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

echo "==> Parsing Nix files"
while IFS= read -r -d '' file; do
  nix-instantiate --parse "$file" > /dev/null
done < <(find . -name '*.nix' -not -path './.git/*' -print0)

echo "==> Evaluating the system configuration"
nix-instantiate '<nixpkgs/nixos>' -A system --arg configuration ./configuration.nix > /dev/null
nix-instantiate --extra-experimental-features 'nix-command flakes' '<nixpkgs/nixos>' -A system --arg configuration ./configuration.nix > /dev/null

echo "==> Checking formatting of the AI module"
nixfmt --check pins.nix modules/ai/*.nix

echo "OK"
