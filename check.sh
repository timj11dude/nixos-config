#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

mapfile -d '' nix_files < <(
  find . -name '*.nix' \
    -not -path './.git/*' \
    -not -path './.jj/*' \
    -not -path './.opencode/*' \
    -not -path '*/hardware-configuration.nix' \
    -print0
)

echo "==> Parsing Nix files"
for file in "${nix_files[@]}"; do
  nix-instantiate --parse "$file" > /dev/null
done

echo "==> Evaluating host configurations"
NIXPKGS_PATH="$(nix-instantiate --eval -E '(import ./pins.nix).nixpkgs' --raw)"
for host_dir in ./modules/hosts/*/; do
  host_dir="${host_dir%/}"
  host="$(basename "$host_dir")"
  [[ "$host" == _* ]] && continue
  echo "    Evaluating host: $host"
  if [[ -f "$host_dir/hardware-configuration.nix" ]]; then
    nix-instantiate -I nixpkgs="$NIXPKGS_PATH" '<nixpkgs/nixos>' -A system --arg configuration "$host_dir/default.nix" > /dev/null
  else
    nix-instantiate -I nixpkgs="$NIXPKGS_PATH" '<nixpkgs/nixos>' -A system \
      --arg configuration "{ imports = [ $host_dir/configuration.nix ./modules/system/hardware-stub.nix ]; }" > /dev/null
  fi
done

echo "==> Checking formatting (nixfmt)"
nixfmt --check "${nix_files[@]}"

echo "==> Linting (statix & deadnix)"
run_lints() {
  statix check --ignore hardware-configuration.nix --ignore .opencode .
  deadnix --fail "${nix_files[@]}"
}

if command -v statix > /dev/null && command -v deadnix > /dev/null; then
  run_lints
else
  nix-shell -p statix deadnix --run '
    statix check --ignore hardware-configuration.nix --ignore .opencode . &&
    deadnix --fail $(find . -name "*.nix" -not -path "./.git/*" -not -path "./.jj/*" -not -path "./.opencode/*" -not -path "*/hardware-configuration.nix")
  '
fi

echo "OK"
