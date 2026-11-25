#!/usr/bin/env bash
# One-command entrypoint for the NixOS Live ISO installer.
#
#   curl -fsSL https://raw.githubusercontent.com/timj11dude/nixos-config/main/bootstrap.sh | bash
#
# Extra arguments are forwarded to ./install.sh:
#
#   curl -fsSL .../bootstrap.sh | bash -s -- --host myhost --from _template
#
# This only clones/updates the repository under /tmp (safe before /mnt is
# formatted or mounted) and then hands over to ./install.sh with the terminal
# re-attached, so prompts and $EDITOR sessions work even when piped from curl.
set -euo pipefail

REPO_URL="${NIXOS_CONFIG_REPO:-https://github.com/timj11dude/nixos-config.git}"
REPO_BRANCH="${NIXOS_CONFIG_BRANCH:-main}"
CLONE_DIR="${NIXOS_CONFIG_DIR:-/tmp/nixos-config}"

log() { printf '==> %s\n' "$*" >&2; }
die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

# Run git, falling back to a throwaway nix-shell on the Minimal ISO.
git_cmd() {
  if command -v git > /dev/null 2>&1; then
    git "$@"
  elif command -v nix-shell > /dev/null 2>&1; then
    local quoted
    printf -v quoted '%q ' git "$@"
    nix-shell -p git --run "$quoted"
  else
    die "git is not installed and nix-shell is unavailable."
  fi
}

if [[ -d "$CLONE_DIR/.git" ]]; then
  log "Updating existing checkout in $CLONE_DIR"
  git_cmd -C "$CLONE_DIR" remote set-url origin "$REPO_URL"
  if git_cmd -C "$CLONE_DIR" fetch --depth 1 origin "$REPO_BRANCH"; then
    if [[ -z "$(git_cmd -C "$CLONE_DIR" status --porcelain --untracked-files=no)" ]]; then
      git_cmd -C "$CLONE_DIR" checkout --quiet "$REPO_BRANCH" 2> /dev/null ||
        git_cmd -C "$CLONE_DIR" checkout --quiet -B "$REPO_BRANCH" FETCH_HEAD
      git_cmd -C "$CLONE_DIR" reset --hard --quiet FETCH_HEAD
    else
      log "Local modifications present in $CLONE_DIR; keeping the existing checkout."
    fi
  else
    log "Fetch failed; continuing with the existing checkout."
  fi
elif [[ -e "$CLONE_DIR" ]] && [[ -n "$(ls -A "$CLONE_DIR" 2> /dev/null)" ]]; then
  die "$CLONE_DIR exists but is not a git checkout. Remove it or set NIXOS_CONFIG_DIR."
else
  log "Cloning $REPO_URL ($REPO_BRANCH) into $CLONE_DIR"
  git_cmd clone --branch "$REPO_BRANCH" "$REPO_URL" "$CLONE_DIR"
fi

cd "$CLONE_DIR"
[[ -x ./install.sh ]] || die "install.sh not found (or not executable) in $CLONE_DIR."

# When piped from curl, stdin is the script itself; re-attach the terminal so
# prompts and editors work. Without a controlling terminal, keep stdin as-is
# (install.sh then requires --yes).
if (: < /dev/tty) 2> /dev/null; then
  exec ./install.sh "$@" < /dev/tty
fi
exec ./install.sh "$@"
