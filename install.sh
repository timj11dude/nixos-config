#!/usr/bin/env bash
# Interactive NixOS Live ISO installer for this repository.
#
# Target environment: the NixOS Live Installer ISO (pre-first-boot), installing
# to $TARGET_ROOT (default /mnt) with `nixos-install`. Normally started via
# `bootstrap.sh`; see `./install.sh --help`.
set -euo pipefail

# --------------------------------------------------------------------------
# Constants & defaults
# --------------------------------------------------------------------------
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_USER="timj"
TARGET_GROUP="users"
TARGET_REPO_PATH="/home/${TARGET_USER}/Projects/github.com:timj11dude/nixos-config"
DISK_PLACEHOLDER="__DISK_ID__"
HOSTNAME_RE='^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$'

TARGET_ROOT="/mnt"
HOST_NAME=""
FROM_HOST=""
HW_CONFIG_ARG=""
DRY_RUN=false
ASSUME_YES=false

# Directory all scaffolding happens in. Equals REPO_DIR for a real install; a
# throwaway copy for --dry-run so that the repository is never modified.
WORK_DIR="$REPO_DIR"
TMP_FILES=()
SUDO=()

# --------------------------------------------------------------------------
# Output helpers
# --------------------------------------------------------------------------
if [[ -t 2 ]]; then
  C_BOLD=$'\033[1m'
  C_RED=$'\033[31m'
  C_YELLOW=$'\033[33m'
  C_GREEN=$'\033[32m'
  C_RESET=$'\033[0m'
else
  C_BOLD="" C_RED="" C_YELLOW="" C_GREEN="" C_RESET=""
fi

info() { printf '%s==>%s %s\n' "$C_BOLD" "$C_RESET" "$*" >&2; }
ok() { printf '%s  ok%s %s\n' "$C_GREEN" "$C_RESET" "$*" >&2; }
warn() { printf '%sWarning:%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
die() {
  printf '%sError:%s %s\n' "$C_RED" "$C_RESET" "$*" >&2
  exit 1
}
dry() { printf '%s[dry-run]%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }

cleanup() {
  local f
  for f in "${TMP_FILES[@]}"; do
    [[ -n "$f" && -e "$f" ]] && rm -rf "$f"
  done
  return 0
}
trap cleanup EXIT

usage() {
  cat << 'EOF'
Usage: ./install.sh [options]

Interactive NixOS installer for the NixOS Live Installer ISO. Scaffolds (or
reuses) a host under modules/hosts/<name>/, partitions with disko (or uses an
already-mounted /mnt), collects hardware-configuration.nix, and runs
nixos-install.

Options:
  --host <name>               Hostname to install (RFC-1123).
  --from <host|_template>     Scaffold <name> by copying an existing host, or
                              from modules/hosts/_template.
  --hardware-config <path|generate>
                              Use this hardware-configuration.nix, or force
                              `nixos-generate-config`.
  --root <path>               Target root (default: /mnt).
  --dry-run                   Preview scaffolding in a throwaway copy of the
                              repository and run nix-instantiate parse/eval.
                              Never runs disko, nixos-install, passwd or reboot
                              and never writes to the target root.
  -y, --yes                   Skip confirmations (requires --host). Never runs
                              disko: the target root must already be mounted.
  -h, --help                  Show this help.

One-command usage from the live ISO:
  curl -fsSL https://raw.githubusercontent.com/timj11dude/nixos-config/main/bootstrap.sh | bash
EOF
}

# --------------------------------------------------------------------------
# Argument parsing
# --------------------------------------------------------------------------
need_value() {
  [[ $# -ge 2 && -n "$2" ]] || die "$1 requires a value."
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host | --from | --hardware-config | --root)
      need_value "$@"
      opt="$1"
      val="$2"
      shift 2
      ;;
    --host=* | --from=* | --hardware-config=* | --root=*)
      opt="${1%%=*}"
      val="${1#*=}"
      [[ -n "$val" ]] || die "$opt requires a value."
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      continue
      ;;
    -y | --yes)
      ASSUME_YES=true
      shift
      continue
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      die "Unknown option: $1"
      ;;
  esac
  case "$opt" in
    --host) HOST_NAME="$val" ;;
    --from) FROM_HOST="$val" ;;
    --hardware-config) HW_CONFIG_ARG="$val" ;;
    --root) TARGET_ROOT="${val%/}" ;;
  esac
done

[[ -n "$TARGET_ROOT" ]] || TARGET_ROOT="/"
if $ASSUME_YES && [[ -z "$HOST_NAME" ]]; then
  die "--yes requires --host."
fi
if [[ -n "$HOST_NAME" && ! "$HOST_NAME" =~ $HOSTNAME_RE ]]; then
  die "Invalid hostname '$HOST_NAME' (RFC 1123: lowercase letters, digits and '-', max 63 chars)."
fi
if [[ -n "$HW_CONFIG_ARG" && "$HW_CONFIG_ARG" != generate && ! -f "$HW_CONFIG_ARG" ]]; then
  die "--hardware-config: '$HW_CONFIG_ARG' is not a file (use a path or 'generate')."
fi
if [[ -n "$FROM_HOST" && -z "$HOST_NAME" ]]; then
  die "--from requires --host."
fi
if ((EUID != 0)); then
  SUDO=(sudo)
fi

# --------------------------------------------------------------------------
# Prompt helpers
# --------------------------------------------------------------------------
read_line() { # read_line <varname> <prompt>
  local __var="$1" __line
  printf '%s' "$2" >&2
  IFS= read -r __line || die "Unexpected end of input."
  printf -v "$__var" '%s' "$__line"
}

# ask_yn <prompt> <default y|n>: returns the default under --yes.
ask_yn() {
  local prompt="$1" def="${2:-n}" hint ans
  [[ "$def" == y ]] && hint='[Y/n]' || hint='[y/N]'
  if $ASSUME_YES; then
    info "$prompt $hint -> $def (--yes)"
    [[ "$def" == y ]]
    return
  fi
  while true; do
    read_line ans "$prompt $hint "
    ans="${ans,,}"
    [[ -z "$ans" ]] && ans="$def"
    case "$ans" in
      y | yes) return 0 ;;
      n | no) return 1 ;;
      *) warn "Please answer y or n." ;;
    esac
  done
}

# confirm <prompt>: explicit [y/N]; automatically yes under --yes.
confirm() {
  if $ASSUME_YES; then
    info "$1 [y/N] -> y (--yes)"
    return 0
  fi
  ask_yn "$1" n
}

# --------------------------------------------------------------------------
# Nix / file helpers
# --------------------------------------------------------------------------
new_tmp() {
  local t
  t="$(mktemp)"
  TMP_FILES+=("$t")
  printf '%s' "$t"
}

nix_parse_ok() { # nix_parse_ok <file>; prints errors to stderr on failure
  local err
  err="$(new_tmp)"
  if nix-instantiate --parse "$1" > /dev/null 2> "$err"; then
    return 0
  fi
  cat "$err" >&2
  return 1
}

tty_available() { (: < /dev/tty) 2> /dev/null; }

pick_editor() {
  local e
  if [[ -n "${EDITOR:-}" ]]; then
    printf '%s' "$EDITOR"
    return
  fi
  for e in vim nano vi; do
    if command -v "$e" > /dev/null 2>&1; then
      printf '%s' "$e"
      return
    fi
  done
  die "No editor found. Set \$EDITOR."
}

run_editor() { # run_editor <file>
  local -a ed
  read -r -a ed <<< "$(pick_editor)"
  if [[ -t 0 ]] || ! tty_available; then
    "${ed[@]}" "$1"
  else
    "${ed[@]}" "$1" < /dev/tty
  fi
}

# edit_until_valid <file> [check-placeholder]
edit_until_valid() {
  local file="$1" check_placeholder="${2:-}" problem
  while true; do
    run_editor "$file"
    problem=""
    if ! nix_parse_ok "$file"; then
      problem="$file has a syntax error."
    elif [[ -n "$check_placeholder" ]] && grep -q "$DISK_PLACEHOLDER" "$file"; then
      problem="$file still contains the $DISK_PLACEHOLDER placeholder."
    fi
    [[ -z "$problem" ]] && return 0
    warn "$problem"
    ask_yn "Re-open the editor?" y || die "Aborted: $problem"
  done
}

# set_toggle <file> <attr.path>: make sure `<attr.path> = true;` is active.
set_toggle() {
  local file="$1" attr="$2" tmp esc
  esc="${attr//./\\.}"
  if grep -Eq "^[[:space:]]*${esc}[[:space:]]*=[[:space:]]*true;" "$file"; then
    return 0
  fi
  tmp="$(new_tmp)"
  if grep -Eq "^[[:space:]]*#[[:space:]]*${esc}[[:space:]]*=[[:space:]]*true;" "$file"; then
    sed -E "s/^([[:space:]]*)#[[:space:]]*(${esc}[[:space:]]*=[[:space:]]*true;)/\1\2/" "$file" > "$tmp"
  else
    # Insert before the final closing brace of the module.
    awk -v line="  ${attr} = true;" '
      { lines[NR] = $0 }
      END {
        last = 0
        for (i = NR; i >= 1; i--) if (lines[i] ~ /^}[[:space:]]*$/) { last = i; break }
        for (i = 1; i <= NR; i++) {
          if (i == last) print line
          print lines[i]
        }
      }' "$file" > "$tmp"
  fi
  cat "$tmp" > "$file"
}

# ensure_import <file> <path>: add <path> to the module's `imports` list.
ensure_import() {
  local file="$1" path="$2" esc tmp has_imports=0
  esc="${path//./\\.}"
  if grep -Eq "(^|[[:space:]\[])${esc}([[:space:]\];]|$)" "$file"; then
    return 0
  fi
  grep -Eq 'imports[[:space:]]*=[[:space:]]*\[' "$file" && has_imports=1
  tmp="$(new_tmp)"
  awk -v path="$path" -v has_imports="$has_imports" '
    done_ { print; next }
    has_imports && /imports[[:space:]]*=[[:space:]]*\[/ {
      if ($0 ~ /\]/) { sub(/imports[[:space:]]*=[[:space:]]*\[/, "&" " " path); print }
      else { print; print "    " path }
      done_ = 1; next
    }
    !has_imports && /^\{[[:space:]]*$/ && !seen_open { print; print "  imports = [ " path " ];"; seen_open = 1; done_ = 1; next }
    { print }
  ' "$file" > "$tmp"
  cat "$tmp" > "$file"
}

# strip_imports_matching <file> <regex>: delete import lines (bare paths).
strip_import_lines() {
  local file="$1" regex="$2" tmp
  tmp="$(new_tmp)"
  grep -Ev "^[[:space:]]*${regex}[[:space:]]*$" "$file" > "$tmp" || true
  cat "$tmp" > "$file"
}

# strip_stmt <file> <start-regex> [body-regex] [yes]
# Remove the attribute statement `<start> = ...;` (bracket/let-balanced). With
# a body regex only statements whose text matches it are removed; with `yes`
# the comment lines directly above a removed statement are removed as well.
strip_stmt() {
  local file="$1" start="$2" body="${3:-}" comments="${4:-no}" tmp
  tmp="$(new_tmp)"
  # Regexes go through ENVIRON so awk does not re-interpret backslash escapes.
  STRIP_START="^[[:space:]]*(${start})[[:space:]]*=" STRIP_BODY="$body" STRIP_COMMENTS="$comments" awk '
    BEGIN { start = ENVIRON["STRIP_START"]; body = ENVIRON["STRIP_BODY"]; comments = ENVIRON["STRIP_COMMENTS"] }
    function cnt(s, re,   n) {
      n = 0
      while (match(s, re)) { n++; s = substr(s, RSTART + RLENGTH) }
      return n
    }
    function delta(s,   t, o, c) {
      t = s
      gsub(/"[^"]*"/, "", t)
      sub(/#.*/, "", t)
      o = gsub(/[{[(]/, "", t)
      c = gsub(/[])}]/, "", t)
      return o - c + cnt(s, "(^|[^A-Za-z0-9_\047-])let([^A-Za-z0-9_\047-]|$)") \
                   - cnt(s, "(^|[^A-Za-z0-9_\047-])in([^A-Za-z0-9_\047-]|$)")
    }
    function flush_pending(   i) { for (i = 1; i <= np; i++) print pend[i]; np = 0 }
    function finish(   i, drop) {
      drop = (body == "")
      for (i = 1; i <= sn; i++) if (body != "" && stmt[i] ~ body) drop = 1
      if (drop) np = 0
      else { flush_pending(); for (i = 1; i <= sn; i++) print stmt[i] }
      in_stmt = 0
    }
    {
      if (!in_stmt) {
        if ($0 ~ start) {
          in_stmt = 1; sn = 1; stmt[1] = $0; depth = delta($0)
          if (depth <= 0 && $0 ~ /;[[:space:]]*$/) finish()
          next
        }
        if (comments == "yes" && $0 ~ /^[[:space:]]*#/) { pend[++np] = $0; next }
        flush_pending(); print; next
      }
      stmt[++sn] = $0; depth += delta($0)
      if (depth <= 0 && $0 ~ /;[[:space:]]*$/) finish()
    }
    END {
      flush_pending()
      if (in_stmt) for (i = 1; i <= sn; i++) print stmt[i]
    }' "$file" > "$tmp"
  cat "$tmp" > "$file"
}

has_pattern() { grep -Eq "$2" "$1"; }

# host_cfg_file <host-dir>: the tracked host module (multi-host layout:
# configuration.nix; legacy layout: default.nix).
host_cfg_file() {
  if [[ -f "$1/configuration.nix" ]]; then
    printf '%s/configuration.nix' "$1"
  else
    printf '%s/default.nix' "$1"
  fi
}

host_imports_disko() { grep -Eq '^[[:space:]]*[^#[:space:]]*disko\.nix' "$1"; }

is_mounted() { mountpoint -q "$TARGET_ROOT" 2> /dev/null; }

has_nvidia_gpu() { command -v lspci > /dev/null 2>&1 && lspci 2> /dev/null | grep -qi nvidia; }

resolve_nixpkgs() {
  nix-instantiate --eval -E "(import ${WORK_DIR}/pins.nix).nixpkgs" --raw
}

# --------------------------------------------------------------------------
# 1. Preflight
# --------------------------------------------------------------------------
HOSTS=()
HOST_DIR=""
HOST_CFG=""
SCAFFOLD_KIND="existing" # existing | template | copy
USE_DISKO=false
HW_SOURCE=""
SECRETS_STATE=""

preflight() {
  info "Preflight checks"
  [[ -f "$REPO_DIR/pins.nix" && -d "$REPO_DIR/modules/hosts" ]] ||
    die "Run this from a checkout of nixos-config (pins.nix / modules/hosts not found)."

  local cmd net_failed=false missing=()
  for cmd in nix-instantiate awk sed mountpoint; do
    command -v "$cmd" > /dev/null 2>&1 || missing+=("$cmd")
  done
  if ! $DRY_RUN; then
    for cmd in nixos-install nixos-enter nixos-generate-config; do
      command -v "$cmd" > /dev/null 2>&1 || missing+=("$cmd")
    done
  fi
  ((${#missing[@]} == 0)) || die "Missing required commands: ${missing[*]} (are you on the NixOS live ISO?)"

  if ! $DRY_RUN && ! findmnt /iso > /dev/null 2>&1 && [[ ! -d /iso ]]; then
    warn "This does not look like the NixOS live installer ISO."
    confirm "Continue anyway?" || die "Aborted."
  fi

  if command -v curl > /dev/null 2>&1; then
    curl -fsS --max-time 10 -o /dev/null https://github.com 2> /dev/null || net_failed=true
  elif ! getent hosts github.com > /dev/null 2>&1; then
    net_failed=true
  fi
  if ! $net_failed; then
    ok "network reachable"
  else
    if $DRY_RUN; then
      warn "No network connectivity (github.com unreachable); evaluation may fail."
    else
      die "No network connectivity. Connect (e.g. nmtui / wpa_supplicant) and retry."
    fi
  fi

  if is_mounted; then
    ok "$TARGET_ROOT is already mounted"
  else
    info "$TARGET_ROOT is not mounted"
  fi

  if $DRY_RUN; then
    WORK_DIR="$(mktemp -d)"
    TMP_FILES+=("$WORK_DIR")
    cp -a "$REPO_DIR/." "$WORK_DIR/"
    dry "Working in throwaway copy $WORK_DIR; nothing is written to $TARGET_ROOT."
  fi
}

# --------------------------------------------------------------------------
# 2-4. Discover hosts, choose action, hostname
# --------------------------------------------------------------------------
discover_hosts() {
  local d name
  HOSTS=()
  for d in "$WORK_DIR"/modules/hosts/*/; do
    [[ -d "$d" ]] || continue
    name="$(basename "$d")"
    [[ "$name" == _* ]] && continue
    HOSTS+=("$name")
  done
}

choose_from_list() { # prints the chosen host name
  local i choice
  for i in "${!HOSTS[@]}"; do
    printf '  %d) %s\n' "$((i + 1))" "${HOSTS[$i]}" >&2
  done
  while true; do
    read_line choice "Select host [1-${#HOSTS[@]}] (or type a name): "
    if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#HOSTS[@]})); then
      printf '%s' "${HOSTS[$((choice - 1))]}"
      return
    fi
    for i in "${HOSTS[@]}"; do
      if [[ "$i" == "$choice" ]]; then
        printf '%s' "$i"
        return
      fi
    done
    warn "Invalid selection."
  done
}

host_exists() { [[ -d "$WORK_DIR/modules/hosts/$1" ]]; }

select_host() {
  discover_hosts
  info "Existing hosts: ${HOSTS[*]:-(none)}"

  # Non-interactive resolution when --host was given.
  if [[ -n "$HOST_NAME" ]]; then
    if [[ -z "$FROM_HOST" ]]; then
      if host_exists "$HOST_NAME"; then
        SCAFFOLD_KIND="existing"
      else
        FROM_HOST="_template"
      fi
    fi
    if [[ -n "$FROM_HOST" ]]; then
      if [[ "$FROM_HOST" == _template ]]; then
        SCAFFOLD_KIND="template"
      else
        host_exists "$FROM_HOST" || die "--from: no such host '$FROM_HOST'."
        [[ "$FROM_HOST" != _* ]] || die "--from: '$FROM_HOST' is not a valid source."
        SCAFFOLD_KIND="copy"
      fi
    fi
  else
    local action
    echo "" >&2
    echo "Select host action:" >&2
    echo "  1) Use an existing host" >&2
    echo "  2) Copy an existing host as a template" >&2
    echo "  3) Create a new minimal host from modules/hosts/_template" >&2
    while true; do
      read_line action "Choice [1-3]: "
      case "$action" in
        1 | 2)
          if ((${#HOSTS[@]} == 0)); then
            warn "No existing hosts found; choose 3."
            continue
          fi
          break
          ;;
        3) break ;;
        *) warn "Please enter 1, 2 or 3." ;;
      esac
    done
    case "$action" in
      1)
        SCAFFOLD_KIND="existing"
        HOST_NAME="$(choose_from_list)"
        ;;
      2)
        SCAFFOLD_KIND="copy"
        FROM_HOST="$(choose_from_list)"
        ;;
      3)
        SCAFFOLD_KIND="template"
        FROM_HOST="_template"
        ;;
    esac
  fi

  # Query + validate hostname for scaffolded hosts.
  if [[ -z "$HOST_NAME" ]]; then
    while true; do
      read_line HOST_NAME "New hostname: "
      if [[ "$HOST_NAME" =~ $HOSTNAME_RE ]]; then
        break
      fi
      warn "Invalid hostname (RFC 1123: lowercase letters, digits, '-'; no leading/trailing '-'; max 63)."
    done
  fi

  HOST_DIR="$WORK_DIR/modules/hosts/$HOST_NAME"
  if [[ "$SCAFFOLD_KIND" != existing ]] && [[ -e "$HOST_DIR" ]]; then
    warn "modules/hosts/$HOST_NAME already exists."
    if $ASSUME_YES; then
      die "Refusing to overwrite modules/hosts/$HOST_NAME under --yes."
    fi
    ask_yn "Replace modules/hosts/$HOST_NAME entirely?" n || die "Aborted: not overwriting an existing host."
    rm -rf "$HOST_DIR"
  fi
  if [[ "$SCAFFOLD_KIND" == existing ]]; then
    host_exists "$HOST_NAME" || die "Host '$HOST_NAME' not found under modules/hosts/."
    [[ "$HOST_NAME" != _* ]] || die "'$HOST_NAME' is not a real host."
  fi
}

# --------------------------------------------------------------------------
# 5. Scaffold & sanitise host config
# --------------------------------------------------------------------------
write_thin_default() {
  sed "s/__HOSTNAME__/${HOST_NAME}/g" "$WORK_DIR/modules/hosts/_template/default.nix" > "$HOST_DIR/default.nix"
}

scaffold_from_template() {
  local tpl="$WORK_DIR/modules/hosts/_template"
  [[ -f "$tpl/configuration.nix" && -f "$tpl/default.nix" ]] ||
    die "modules/hosts/_template/{configuration.nix,default.nix} are missing."
  info "Creating host '$HOST_NAME' from modules/hosts/_template"
  mkdir -p "$HOST_DIR"
  sed "s/__HOSTNAME__/${HOST_NAME}/g" "$tpl/configuration.nix" > "$HOST_DIR/configuration.nix"
  write_thin_default
  HOST_CFG="$HOST_DIR/configuration.nix"

  local entry label attr
  local -a toggles=(
    "Gaming (Steam, Lutris, ...)|gaming.enable"
    "Local AI tooling (Ollama, OpenCode)|ai.enable"
    "Noctalia desktop shell|programs.noctalia.enable"
    "Restic backups|backups.restic.enable"
    "Orca IDE|services.orca-ide.enable"
    "Orca server|services.orca-server.enable"
  )
  for entry in "${toggles[@]}"; do
    label="${entry%%|*}"
    attr="${entry#*|}"
    if ask_yn "Enable ${label} (${attr})?" n; then
      set_toggle "$HOST_CFG" "$attr"
    fi
  done
}

scaffold_from_host() {
  local src="$WORK_DIR/modules/hosts/$FROM_HOST" src_cfg
  info "Copying host '$FROM_HOST' -> '$HOST_NAME' (without disko.nix / hardware-configuration.nix)"
  src_cfg="$(host_cfg_file "$src")"
  [[ -f "$src_cfg" ]] || die "Host '$FROM_HOST' has no configuration.nix or default.nix."
  mkdir -p "$HOST_DIR"
  # Copy tracked helper files (e.g. compositor configs) but never machine- or
  # disk-specific ones.
  cp -a "$src/." "$HOST_DIR/"
  rm -f "$HOST_DIR/disko.nix" "$HOST_DIR/hardware-configuration.nix"
  if [[ "$src_cfg" != "$src/configuration.nix" ]]; then
    # Legacy layout: the single default.nix becomes configuration.nix.
    cp "$src_cfg" "$HOST_DIR/configuration.nix"
  fi
  write_thin_default
  HOST_CFG="$HOST_DIR/configuration.nix"

  # Rewrite identity.
  sed -E -i "s/(hostName[[:space:]]*=[[:space:]]*)\"[^\"]*\"/\1\"${HOST_NAME}\"/" "$HOST_CFG"
  awk -v old="$FROM_HOST" -v new="$HOST_NAME" '
    /"127\.0\.0\.1"[[:space:]]*=[[:space:]]*\[/ { in_loop = 1 }
    in_loop {
      gsub("\"" old "\"", "\"" new "\"")
      if ($0 ~ /\];/) in_loop = 0
    }
    { print }' "$HOST_CFG" > "$HOST_CFG.new" && mv "$HOST_CFG.new" "$HOST_CFG"

  # Imports: disko / hardware are re-wired by the installer; make sure the
  # shared system module is imported.
  strip_import_lines "$HOST_CFG" '[./]*[^[:space:]]*disko\.nix'
  strip_import_lines "$HOST_CFG" '[./]*[^[:space:]]*hardware-configuration\.nix'
  ensure_import "$HOST_CFG" "../../../configuration.nix"

  sanitize_copied_host

  # Cosmetics: refresh the header comment and collapse blank-line runs left
  # behind by removed statements.
  sed -i "1,3s/\`${FROM_HOST}\`/\`${HOST_NAME}\`/" "$HOST_CFG"
  cat -s "$HOST_CFG" > "$HOST_CFG.new" && mv "$HOST_CFG.new" "$HOST_CFG"
}

sanitize_copied_host() {
  local default_nvidia=n
  has_nvidia_gpu && default_nvidia=y

  if has_pattern "$HOST_CFG" 'nvidia'; then
    if ! ask_yn "Keep NVIDIA configuration (hardware.nvidia, videoDrivers)?" "$default_nvidia"; then
      strip_stmt "$HOST_CFG" '(hardware\.)?nvidia'
      strip_stmt "$HOST_CFG" '(services\.)?(xserver\.)?videoDrivers' 'nvidia'
      sed -E -i '/^[[:space:]]*"nvidia[^"]*"[[:space:]]*$/d' "$HOST_CFG"
    fi
  fi

  if has_pattern "$HOST_CFG" 'truenas|cifs'; then
    if ! ask_yn "Keep TrueNAS CIFS mounts and sops.secrets.\"truenas/login\"?" n; then
      strip_stmt "$HOST_CFG" '(sops\.)?secrets\."truenas/login"' '' yes
      strip_stmt "$HOST_CFG" 'fileSystems' 'cifs|truenas' yes
    fi
  fi

  if has_pattern "$HOST_CFG" 'sane|epkowa|iscan|ckb-next'; then
    if ! ask_yn "Keep scanner (sane/epkowa/iscan) and Corsair ckb-next support?" n; then
      strip_stmt "$HOST_CFG" '(hardware\.)?sane'
      strip_stmt "$HOST_CFG" '(hardware\.)?ckb-next(\.enable)?'
      sed -E -i '/^[[:space:]]*"iscan[^"]*"[[:space:]]*$/d' "$HOST_CFG"
    fi
  fi

  if has_pattern "$HOST_CFG" 'backups\.restic'; then
    if ! ask_yn "Keep Restic backups enabled?" n; then
      strip_stmt "$HOST_CFG" 'backups\.restic'
      strip_stmt "$HOST_CFG" 'restic' '(enable|googleDrive)'
    fi
  fi
}

validate_host_files() {
  local f
  for f in "$HOST_DIR"/*.nix; do
    [[ "$(basename "$f")" == hardware-configuration.nix ]] && continue
    nix_parse_ok "$f" || die "Syntax error in $f"
  done
}

scaffold_host() {
  case "$SCAFFOLD_KIND" in
    template) scaffold_from_template ;;
    copy) scaffold_from_host ;;
    existing)
      HOST_CFG="$(host_cfg_file "$HOST_DIR")"
      [[ -f "$HOST_CFG" ]] || die "Host '$HOST_NAME' has no configuration.nix or default.nix."
      info "Using existing host '$HOST_NAME'"
      ;;
  esac
  validate_host_files
  ok "host configuration parses"
}

# --------------------------------------------------------------------------
# 6. Disk partitioning
# --------------------------------------------------------------------------
build_disko() {
  local np disko_src
  np="$(resolve_nixpkgs)"
  disko_src="$(nix-instantiate --eval -E "(import ${WORK_DIR}/pins.nix).disko" --raw)"
  nix-build -I "nixpkgs=$np" --no-out-link -E \
    "(import <nixpkgs> {}).callPackage ${disko_src}/package.nix { diskoVersion = (import ${disko_src}/version.nix).version; }"
}

show_disks() {
  echo "" >&2
  info "Block devices (lsblk -d -o NAME,SIZE,MODEL,TRAN):"
  lsblk -d -o NAME,SIZE,MODEL,TRAN >&2 2> /dev/null || warn "lsblk unavailable"
  echo "" >&2
  info "Stable names (/dev/disk/by-id/, whole disks):"
  if [[ -d /dev/disk/by-id ]]; then
    local link
    for link in /dev/disk/by-id/*; do
      [[ -e "$link" && "$link" != *-part[0-9]* ]] || continue
      printf '  %s -> %s\n' "${link##*/}" "$(readlink "$link")" >&2
    done
  else
    warn "/dev/disk/by-id not present"
  fi
  echo "" >&2
}

partition_with_disko() {
  local disko_file="$HOST_DIR/disko.nix" typed disko_pkg
  show_disks
  if $DRY_RUN; then
    dry "would open $disko_file in an editor (placeholder $DISK_PLACEHOLDER must be replaced)"
  else
    info "Opening $disko_file; replace $DISK_PLACEHOLDER with your disk's by-id name."
    edit_until_valid "$disko_file" check-placeholder
  fi
  nix_parse_ok "$disko_file" || die "Syntax error in $disko_file"

  if $DRY_RUN; then
    dry "would require typing DESTROY, then run:"
    dry "  disko --mode destroy,format,mount --root-mountpoint $TARGET_ROOT --yes-wipe-all-disks $disko_file"
    return 0
  fi

  echo "" >&2
  warn "disko will ERASE every disk referenced in $disko_file and mount it at $TARGET_ROOT."
  grep -E 'device[[:space:]]*=' "$disko_file" >&2 || true
  read_line typed "Type DESTROY to continue: "
  [[ "$typed" == DESTROY ]] || die "Aborted: destructive confirmation not given."

  info "Building disko (pinned in pins.nix)"
  disko_pkg="$(build_disko)"
  info "Running disko"
  "${SUDO[@]}" "$disko_pkg/bin/disko" --mode destroy,format,mount \
    --root-mountpoint "$TARGET_ROOT" --yes-wipe-all-disks "$disko_file"
  is_mounted || die "$TARGET_ROOT is not mounted after disko."
}

step_disk() {
  local mounted=false use_existing=false
  is_mounted && mounted=true

  if $mounted; then
    if ask_yn "$TARGET_ROOT is already mounted. Use the existing mount (no repartitioning)?" y; then
      use_existing=true
    fi
  elif $ASSUME_YES && ! $DRY_RUN; then
    die "$TARGET_ROOT is not mounted and --yes never runs disko. Partition and mount it first."
  fi

  if $use_existing; then
    USE_DISKO=false
    info "Using the existing mount at $TARGET_ROOT"
    return 0
  fi

  USE_DISKO=true
  if [[ -f "$HOST_DIR/disko.nix" ]]; then
    info "Using host's own disko.nix"
  else
    cp "$WORK_DIR/modules/hosts/_template/disko.nix" "$HOST_DIR/disko.nix"
    info "Copied modules/hosts/_template/disko.nix -> modules/hosts/$HOST_NAME/disko.nix"
  fi
  ensure_import "$HOST_CFG" "./disko.nix"
  nix_parse_ok "$HOST_CFG" || die "Syntax error in $HOST_CFG after wiring ./disko.nix"
  partition_with_disko
}

# --------------------------------------------------------------------------
# 7. Review host config
# --------------------------------------------------------------------------
step_review() {
  local rel
  rel="modules/hosts/$HOST_NAME/$(basename "$HOST_CFG")"
  if $DRY_RUN || $ASSUME_YES; then
    return 0
  fi
  if ask_yn "Open $rel in editor to review/tweak before installing?" n; then
    edit_until_valid "$HOST_CFG"
  fi
}

# --------------------------------------------------------------------------
# 8. hardware-configuration.nix
# --------------------------------------------------------------------------
write_hardware_stub() {
  cat > "$1" << 'EOF'
# Dry-run stub (not a real hardware scan).
{ lib, ... }:
{
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
}
EOF
}

step_hardware() {
  local dest="$HOST_DIR/hardware-configuration.nix"
  local existing="$TARGET_ROOT/etc/nixos/hardware-configuration.nix"
  local -a gen_args=(--show-hardware-config --root "$TARGET_ROOT")

  if ! $DRY_RUN; then
    is_mounted || die "$TARGET_ROOT is not mounted; cannot collect hardware configuration."
  fi
  if host_imports_disko "$HOST_CFG"; then
    gen_args+=(--no-filesystems)
  fi

  if [[ -n "$HW_CONFIG_ARG" && "$HW_CONFIG_ARG" != generate ]]; then
    cp "$HW_CONFIG_ARG" "$dest"
    HW_SOURCE="provided file $HW_CONFIG_ARG"
  elif [[ -z "$HW_CONFIG_ARG" && -f "$existing" ]]; then
    cp "$existing" "$dest"
    HW_SOURCE="existing $existing"
  else
    if command -v nixos-generate-config > /dev/null 2>&1 &&
      nixos-generate-config "${gen_args[@]}" > "$dest" 2> /dev/null; then
      HW_SOURCE="nixos-generate-config ${gen_args[*]}"
    elif $DRY_RUN; then
      warn "nixos-generate-config unavailable/failed; using a dry-run stub."
      write_hardware_stub "$dest"
      HW_SOURCE="dry-run stub"
    else
      die "nixos-generate-config failed."
    fi
  fi

  [[ -s "$dest" ]] || die "hardware-configuration.nix is empty."
  nix_parse_ok "$dest" || die "hardware-configuration.nix does not parse."
  ok "hardware-configuration.nix collected (${HW_SOURCE})"
}

# --------------------------------------------------------------------------
# 9. Secrets
# --------------------------------------------------------------------------
step_secrets() {
  local keys_dir="$TARGET_ROOT/home/$TARGET_USER/.config/sops/age"
  local keys="$keys_dir/keys.txt" choice src

  if ! has_pattern "$HOST_CFG" 'sops\.secrets|secrets\.'; then
    SECRETS_STATE="not required (host declares no sops.secrets)"
    info "Host declares no sops.secrets; run ./bootstrap-secrets.sh after first login."
    return 0
  fi
  if [[ -f "$keys" ]]; then
    SECRETS_STATE="age key present"
    ok "sops age key found at $keys"
    return 0
  fi

  warn "Host declares sops.secrets but $keys does not exist."
  if $ASSUME_YES; then
    SECRETS_STATE="DEFERRED (run ./bootstrap-secrets.sh after first login)"
    warn "Deferring secrets (--yes)."
    return 0
  fi
  echo "  1) Run ./bootstrap-secrets.sh now (via nix-shell -p secretspec)" >&2
  echo "  2) Import an existing age keys.txt" >&2
  echo "  3) Defer (run ./bootstrap-secrets.sh after first login)" >&2
  echo "  4) Abort" >&2
  while true; do
    read_line choice "Choice [1-4]: "
    case "$choice" in
      1)
        if $DRY_RUN; then
          dry "would run bootstrap-secrets.sh with HOME=$TARGET_ROOT/home/$TARGET_USER"
          SECRETS_STATE="would run bootstrap-secrets.sh"
        else
          local np home_dir="$TARGET_ROOT/home/$TARGET_USER"
          np="$(resolve_nixpkgs)"
          mkdir -p "$home_dir"
          if nix-shell -I "nixpkgs=$np" -p secretspec --run \
            "HOME=$(printf '%q' "$home_dir") $(printf '%q' "$WORK_DIR/bootstrap-secrets.sh")" && [[ -f "$keys" ]]; then
            SECRETS_STATE="age key written by bootstrap-secrets.sh"
          else
            warn "bootstrap-secrets.sh failed or did not write $keys."
            continue
          fi
        fi
        return 0
        ;;
      2)
        read_line src "Path to keys.txt: "
        [[ -f "$src" ]] || {
          warn "'$src' is not a file."
          continue
        }
        if $DRY_RUN; then
          dry "would install $src -> $keys (umask 077, chmod 600)"
        else
          (
            umask 077
            mkdir -p "$keys_dir"
            install -m 600 "$src" "$keys"
          )
          chmod 700 "$keys_dir"
        fi
        SECRETS_STATE="age key imported from $src"
        return 0
        ;;
      3)
        SECRETS_STATE="DEFERRED (run ./bootstrap-secrets.sh after first login)"
        return 0
        ;;
      4) die "Aborted by user (secrets)." ;;
      *) warn "Please enter 1-4." ;;
    esac
  done
}

# --------------------------------------------------------------------------
# 10. Deploy & finalise
# --------------------------------------------------------------------------
print_summary() {
  local disk_note="existing mount at $TARGET_ROOT"
  $USE_DISKO && disk_note="partitioned by disko (modules/hosts/$HOST_NAME/disko.nix)"
  echo "" >&2
  info "Installation summary"
  cat >&2 << EOF
  Host:             $HOST_NAME ($SCAFFOLD_KIND${FROM_HOST:+ from $FROM_HOST})
  Target root:      $TARGET_ROOT
  Disk:             $disk_note
  Hardware config:  $HW_SOURCE
  Secrets:          $SECRETS_STATE
  Repo location:    $TARGET_ROOT$TARGET_REPO_PATH
  /etc/nixos link:  configuration.nix -> $TARGET_REPO_PATH/modules/hosts/$HOST_NAME/default.nix
EOF
  echo "" >&2
}

dry_run_eval() {
  local np
  np="$(resolve_nixpkgs)"
  info "Evaluating the system configuration for '$HOST_NAME' (nix-instantiate)"
  if nix-instantiate '<nixpkgs/nixos>' -A system -I "nixpkgs=$np" \
    --arg configuration "$HOST_DIR/default.nix" > /dev/null; then
    ok "system configuration evaluates"
  else
    die "Evaluation of modules/hosts/$HOST_NAME/default.nix failed."
  fi
}

dry_run_report() {
  echo "" >&2
  info "Scaffolded modules/hosts/$HOST_NAME:"
  (cd "$HOST_DIR" && ls -1 >&2)
  echo "" >&2
  info "$(basename "$HOST_CFG") (preview):"
  cat "$HOST_CFG" >&2
  echo "" >&2
  dry "would copy repo to $TARGET_ROOT$TARGET_REPO_PATH"
  dry "would symlink $TARGET_ROOT/etc/nixos/configuration.nix -> $TARGET_REPO_PATH/modules/hosts/$HOST_NAME/default.nix"
  dry "would run: nixos-install --root $TARGET_ROOT --no-root-passwd -I nixos-config=$TARGET_ROOT$TARGET_REPO_PATH/modules/hosts/$HOST_NAME/default.nix -I nixpkgs=<pinned>"
  dry "would chown the repo to $TARGET_USER:$TARGET_GROUP, prompt for $TARGET_USER's password and offer a reboot"
  dry "Dry run complete; the repository and $TARGET_ROOT were not modified."
}

deploy() {
  local repo_dest="$TARGET_ROOT$TARGET_REPO_PATH" np config_path
  np="$(resolve_nixpkgs)"

  info "Copying repository to $repo_dest"
  mkdir -p "$repo_dest"
  cp -a "$WORK_DIR/." "$repo_dest/"
  rm -rf "$repo_dest/result"

  info "Linking /etc/nixos/configuration.nix"
  mkdir -p "$TARGET_ROOT/etc/nixos"
  ln -sfn "$TARGET_REPO_PATH/modules/hosts/$HOST_NAME/default.nix" "$TARGET_ROOT/etc/nixos/configuration.nix"

  config_path="$repo_dest/modules/hosts/$HOST_NAME/default.nix"
  info "Running nixos-install (this takes a while)"
  "${SUDO[@]}" nixos-install --root "$TARGET_ROOT" --no-root-passwd \
    -I "nixos-config=$config_path" \
    -I "nixpkgs=$np"

  info "Fixing ownership of /home/$TARGET_USER"
  "${SUDO[@]}" nixos-enter --root "$TARGET_ROOT" -c \
    "chown $TARGET_USER:$TARGET_GROUP /home/$TARGET_USER && chown -R $TARGET_USER:$TARGET_GROUP /home/$TARGET_USER/Projects && { [ ! -e /home/$TARGET_USER/.config ] || chown -R $TARGET_USER:$TARGET_GROUP /home/$TARGET_USER/.config; }"
}

finalize() {
  if ! $ASSUME_YES; then
    if ask_yn "Set the password for $TARGET_USER now?" y; then
      "${SUDO[@]}" nixos-enter --root "$TARGET_ROOT" -c "passwd $TARGET_USER" ||
        warn "passwd failed; run: nixos-enter --root $TARGET_ROOT -c 'passwd $TARGET_USER'"
    fi
  else
    info "Skipping password prompt (--yes). Run: nixos-enter --root $TARGET_ROOT -c 'passwd $TARGET_USER'"
  fi

  cat >&2 << EOF

${C_BOLD}Post-install checklist${C_RESET}
  1. Log in as $TARGET_USER and run ./bootstrap-secrets.sh from $TARGET_REPO_PATH
     (materialises the sops age key and restic password).
  2. Once the machine works, commit modules/hosts/$HOST_NAME/ in
     $TARGET_REPO_PATH.
  3. Rebuild with ./rebuild.sh --host $HOST_NAME <switch|test|boot> when changing config.

EOF
  if ! $ASSUME_YES && ask_yn "Installation complete! Reboot now?" n; then
    "${SUDO[@]}" umount -R "$TARGET_ROOT" || warn "Could not unmount $TARGET_ROOT cleanly."
    "${SUDO[@]}" reboot
  fi
}

# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------
main() {
  preflight
  select_host
  scaffold_host
  step_disk
  step_review
  step_hardware
  step_secrets
  print_summary

  if $DRY_RUN; then
    dry_run_eval
    dry_run_report
    return 0
  fi

  confirm "Proceed with the installation to $TARGET_ROOT?" || die "Aborted before deployment."
  deploy
  finalize
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main
fi
