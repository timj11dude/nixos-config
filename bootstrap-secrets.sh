#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SECRETSPEC_FILE="${SECRETSPEC_FILE:-${SCRIPT_DIR}/secretspec.toml}"
export SECRETSPEC_PROFILE="${SECRETSPEC_PROFILE:-default}"

if ! command -v secretspec >/dev/null 2>&1; then
  echo "Error: secretspec is not installed or not in PATH." >&2
  exit 1
fi

echo "Checking required secrets in configured provider..."
secretspec check

echo "Materializing sops age key and restic password..."
secretspec run -- bash -euo pipefail -c '
  umask 077
  mkdir -p "${HOME}/.config/sops/age" "${HOME}/.config/restic"
  chmod 700 "${HOME}/.config/sops/age" "${HOME}/.config/restic"
  printf "%s\n" "$SOPS_AGE_KEY" > "${HOME}/.config/sops/age/keys.txt"
  printf "%s\n" "$RESTIC_PASSWORD" > "${HOME}/.config/restic/password"
  chmod 600 "${HOME}/.config/sops/age/keys.txt" "${HOME}/.config/restic/password"
'

echo "Done. Materialized sops age key and restic password."
