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

HOST="${NIXOS_HOST:-}"
ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      if [[ $# -lt 2 ]]; then
        echo "Error: --host requires a hostname argument." >&2
        exit 1
      fi
      HOST="$2"
      shift 2
      ;;
    --host=*)
      HOST="${1#--host=}"
      shift
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done

if [[ -z "$HOST" ]]; then
  HOST="$(hostname -s)"
fi

HOST_DIR="$PWD/modules/hosts/$HOST"
HOST_ENTRYPOINT="$HOST_DIR/default.nix"
HOST_HARDWARE="$HOST_DIR/hardware-configuration.nix"

if [[ ! -f "$HOST_ENTRYPOINT" ]]; then
  echo "Error: host entrypoint not found: $HOST_ENTRYPOINT" >&2
  echo "Create modules/hosts/$HOST/ from modules/hosts/_template/ or pass --host <name>." >&2
  exit 1
fi

if [[ ! -f "$HOST_HARDWARE" ]]; then
  echo "Error: machine-generated hardware config not found: $HOST_HARDWARE" >&2
  echo "Generate it on this machine with: nixos-generate-config --show-hardware-config > $HOST_HARDWARE" >&2
  exit 1
fi

NIXOS_LABEL="$(compute_label)"
export NIXOS_LABEL
NIXPKGS_PATH="$(resolve_nixpkgs)"

echo "Host: $HOST"
echo "Generation label: $NIXOS_LABEL"
sudo NIXOS_LABEL="$NIXOS_LABEL" nixos-rebuild "${ARGS[@]}" \
  -I nixpkgs="$NIXPKGS_PATH" \
  -I nixos-config="$HOST_ENTRYPOINT"
