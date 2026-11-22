#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

echo "==> Parsing Nix files"
while IFS= read -r -d '' file; do
  nix-instantiate --parse "$file" > /dev/null
done < <(find . -name '*.nix' -not -path './.git/*' -print0)

echo "==> Evaluating the system configuration"
nix-instantiate '<nixpkgs/nixos>' -A system --arg configuration ./configuration.nix > /dev/null

echo "==> Checking formatting of the AI module"
nixfmt --check pins.nix modules/home/ai/*.nix modules/home/herdr/*.nix modules/system/ai/*.nix modules/system/herdr/*.nix

echo "OK"
