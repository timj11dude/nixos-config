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

if command -v nixfmt > /dev/null; then
  nixfmt "${nix_files[@]}"
else
  nix-shell -p nixfmt --run 'nixfmt "$@"' -- "${nix_files[@]}"
fi
