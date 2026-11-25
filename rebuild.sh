#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

sanitize_label() {
  printf '%s' "$1" \
    | sed -E 's/[^a-zA-Z0-9._-]+/-/g; s/-{2,}/-/g; s/^-+//; s/-+$//' \
    | cut -c1-64 \
    | sed -E 's/-+$//'
}

compute_label() {
  local raw=""
  local label=""

  if command -v jj >/dev/null 2>&1 && [[ -d .jj ]]; then
    raw="$(jj log --no-graph -r @ 2>/dev/null | tail -n 1 || true)"
    label="$(sanitize_label "$raw")"
    if [[ -n "$label" ]]; then
      printf '%s\n' "$label"
      return 0
    fi
  fi

  if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    raw="$(git rev-parse --short HEAD 2>/dev/null || true)"
    label="$(sanitize_label "$raw")"
    if [[ -n "$label" ]]; then
      printf '%s\n' "$label"
      return 0
    fi
  fi

  raw="$(hostname -s)-$(date +%Y%m%d-%H%M)"
  sanitize_label "$raw"
  printf '\n'
}

resolve_nixpkgs() {
  nix-instantiate --eval -E '(import ./pins.nix).nixpkgs' --raw
}

NIXOS_LABEL="$(compute_label)"
export NIXOS_LABEL
NIXPKGS_PATH="$(resolve_nixpkgs)"

echo "Generation label: $NIXOS_LABEL"
sudo NIXOS_LABEL="$NIXOS_LABEL" nixos-rebuild "$@" \
  -I nixpkgs="$NIXPKGS_PATH" \
  -I nixos-config="$PWD/configuration.nix"

