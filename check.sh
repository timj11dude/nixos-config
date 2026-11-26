#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

usage() {
  cat << 'EOF'
Usage: ./check.sh [tier]

Tiers:
  lint       Tier 1: shell syntax/shellcheck, actionlint, Nix parse, nixfmt, statix, deadnix
  eval       Tier 2: evaluate all host configurations (alias: validate)
  build      Tier 3: build repo config validators & custom lightweight derivations
  all        Run all three tiers in order (lint -> eval -> build)
  (default)  Run lint + eval
EOF
}

NIXPKGS_PATH=""
resolve_nixpkgs() {
  if [[ -z "$NIXPKGS_PATH" ]]; then
    NIXPKGS_PATH="$(nix-instantiate --eval -E '(import ./pins.nix).nixpkgs' --raw)"
  fi
}

mapfile -d '' all_nix_files < <(
  find . -name '*.nix' \
    -not -path './.git/*' \
    -not -path './.jj/*' \
    -not -path './.opencode/*' \
    -print0
)

mapfile -d '' nix_files < <(
  find . -name '*.nix' \
    -not -path './.git/*' \
    -not -path './.jj/*' \
    -not -path './.opencode/*' \
    -not -path '*/hardware-configuration.nix' \
    -print0
)

mapfile -d '' sh_files < <(
  find . -maxdepth 2 -name '*.sh' \
    -not -path './.git/*' \
    -not -path './.jj/*' \
    -not -path './.opencode/*' \
    -print0
)

mapfile -d '' shellcheck_files < <(
  find . -maxdepth 2 -name '*.sh' \
    -not -path './.git/*' \
    -not -path './.jj/*' \
    -not -path './.opencode/*' \
    -not -path './diff.sh' \
    -print0
)

ensure_lint_tools() {
  local -a missing=()
  local tool
  for tool in nixfmt statix deadnix shellcheck actionlint; do
    if ! command -v "$tool" > /dev/null 2>&1; then
      missing+=("$tool")
    fi
  done

  if ((${#missing[@]} > 0)); then
    resolve_nixpkgs
    local -a attrs=()
    for tool in "${missing[@]}"; do
      attrs+=(-A "$tool")
    done
    local out
    while IFS= read -r out; do
      PATH="${out}/bin:${PATH}"
    done < <(nix-build -I nixpkgs="$NIXPKGS_PATH" '<nixpkgs>' "${attrs[@]}" --no-out-link)
    export PATH
  fi
}

run_lint() {
  echo "==> Checking shell script syntax (bash -n)"
  for file in "${sh_files[@]}"; do
    bash -n "$file"
  done

  echo "==> Parsing Nix files"
  for file in "${all_nix_files[@]}"; do
    nix-instantiate --parse "$file" > /dev/null
  done

  ensure_lint_tools

  echo "==> Linting shell scripts (shellcheck)"
  shellcheck --severity=warning "${shellcheck_files[@]}"

  if [[ -d .github/workflows ]]; then
    echo "==> Linting GitHub Actions workflows (actionlint)"
    actionlint
  fi

  echo "==> Checking formatting (nixfmt)"
  nixfmt --check "${nix_files[@]}"

  echo "==> Linting Nix files (statix & deadnix)"
  statix check --ignore hardware-configuration.nix --ignore .opencode .
  deadnix --fail "${nix_files[@]}"
}

run_eval() {
  echo "==> Evaluating host configurations"
  resolve_nixpkgs
  local host_dir host
  for host_dir in ./modules/hosts/*/; do
    host_dir="${host_dir%/}"
    host="$(basename "$host_dir")"
    [[ "$host" == _* ]] && continue
    echo "    Evaluating host: $host"
    nix-instantiate --no-gc-warning -I nixpkgs="$NIXPKGS_PATH" '<nixpkgs/nixos>' -A system --arg configuration "$host_dir/default.nix" > /dev/null
  done
}

run_build() {
  echo "==> Building targeted config validators & custom derivations"
  resolve_nixpkgs
  local host_dir host
  for host_dir in ./modules/hosts/*/; do
    host_dir="${host_dir%/}"
    host="$(basename "$host_dir")"
    [[ "$host" == _* ]] && continue
    echo "    Building targeted derivations for host: $host"
    nix-build -I nixpkgs="$NIXPKGS_PATH" --no-out-link \
      --arg hostConfig "$host_dir/default.nix" \
      -E '
        { hostConfig }:
        let
          nixos = import <nixpkgs/nixos> { configuration = hostConfig; };
          hm = nixos.config.home-manager.users.timj or null;
          inherit (nixos.pkgs) lib;
        in
        lib.optionals (hm != null && (hm.my.niri.enable or false)) [
          hm.xdg.configFile."niri/config.kdl".source
        ]
        ++ lib.optionals (hm != null && (hm.home.opencode.enable or false) && (hm.home.opencode.quota.enable or false)) [
          hm.home.opencode.quota.package
        ]
        ++ lib.optionals (hm != null && (hm.my.zellij.enable or false)) [
          hm.xdg.configFile."zellij/plugins/room.wasm".source
        ]
      '
  done
}

case "${1:-default}" in
  lint)
    run_lint
    ;;
  eval | validate)
    run_eval
    ;;
  build)
    run_build
    ;;
  all)
    run_lint
    run_eval
    run_build
    ;;
  default)
    run_lint
    run_eval
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "Error: unknown tier '${1}'" >&2
    usage >&2
    exit 1
    ;;
esac

echo "OK"
