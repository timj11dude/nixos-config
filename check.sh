#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

mapfile -d '' nix_files < <(
  find . -name '*.nix' \
    -not -path './.git/*' \
    -not -path './.jj/*' \
    -not -path './.opencode/*' \
    -not -path './hardware-configuration.nix' \
    -print0
)

echo "==> Parsing Nix files"
for file in "${nix_files[@]}"; do
  nix-instantiate --parse "$file" > /dev/null
done

echo "==> Evaluating the system configuration"
nix-instantiate '<nixpkgs/nixos>' -A system --arg configuration ./configuration.nix > /dev/null

echo "==> Checking formatting (nixfmt)"
nixfmt --check "${nix_files[@]}"

echo "==> Linting (statix & deadnix)"
run_lints() {
  statix check --ignore hardware-configuration.nix --ignore .opencode .
  deadnix --fail --exclude ./hardware-configuration.nix "${nix_files[@]}"
}

if command -v statix > /dev/null && command -v deadnix > /dev/null; then
  run_lints
else
  nix-shell -p statix deadnix --run '
    statix check --ignore hardware-configuration.nix --ignore .opencode . &&
    deadnix --fail --exclude ./hardware-configuration.nix $(find . -name "*.nix" -not -path "./.git/*" -not -path "./.jj/*" -not -path "./.opencode/*" -not -path "./hardware-configuration.nix")
  '
fi

echo "OK"
