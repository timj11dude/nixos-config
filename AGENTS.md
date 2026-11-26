# AGENTS.md

Operating guide for AI coding agents working in `nixos-config`.
For hostnames, mounts, hardware identifiers, scripts, and project terminology, see [`GLOSSARY.md`](./GLOSSARY.md).

## 1. Project Overview

- **Purpose:** Multi-host personal NixOS + Home Manager configuration (primary user `timj`, locale `en_GB.UTF-8`, timezone `Europe/London`), with per-host entrypoints under `modules/hosts/<hostname>/` (currently `aether`, plus `_template` for new machines).
- **Evaluation Model:** Non-flake NixOS channels (`<nixpkgs>`, `<nixos-unstable>`) with pinned module sources in `pins.nix`. There is no `flake.nix` or `flake.lock`.
- **Home Manager Integration:** Managed as a NixOS module (`"${pins.home-manager}/nixos"` in `configuration.nix` via `home-manager.users.timj = { imports = [ ./home.nix ]; };`), allowing host modules to cleanly merge per-host HM overrides. `home-manager.useGlobalPkgs = true` is enabled.
- **Deployment Model:** `./rebuild.sh [--host <name>] <action>` selects `modules/hosts/<host>/default.nix` (via `--host`, `$NIXOS_HOST`, or `$(hostname -s)`) and passes `-I nixos-config="$PWD/modules/hosts/$HOST/default.nix"` to `sudo nixos-rebuild`. For `system.autoUpgrade`, symlink `/etc/nixos/configuration.nix` to the checkout's `modules/hosts/<hostname>/default.nix`.

## 2. Repository Structure & Ownership Boundaries

| Path | Responsibility | Status / Notes |
| --- | --- | --- |
| `configuration.nix` | Shared base system-level NixOS config: boot (`systemd-boot`), networking, PipeWire, printing/Avahi, SSH, `sops-nix`, `autoUpgrade`, Home Manager base. | Host-overridable defaults use `lib.mkDefault`. Imported by each `modules/hosts/<hostname>/configuration.nix`. |
| `modules/hosts/<hostname>/` | Per-host NixOS entrypoint (`default.nix` importing `./configuration.nix` + `./hardware-configuration.nix`), host config (`configuration.nix`), and host-specific assets (e.g. `aether/niri.kdl`). | `_template/` is a starter template excluded from host discovery and `./check.sh`. |
| `modules/home/niri/` | Niri HM module (`default.nix`) plus shared `config.kdl`, validated with `niri validate`. Hosts customise it via `my.niri.extraConfig` (KDL appended to the end) and `my.niri.extraInputConfig` (KDL spliced into the shared `input` block at the `// @EXTRA_INPUT_CONFIG@` placeholder). | Put per-host `input` settings in `extraInputConfig`, **not** `extraConfig`: niri rejects a repeated top-level `input` node. Keep the placeholder comment in `config.kdl`. |
| `home.nix` | User-level Home Manager config for `timj`: GUI/CLI packages, Firefox, Thunderbird, Rofi, `spotify-player`, `trayscale`, `ollama`, Gradle properties, XDG settings, `i3` config symlinks. | Imports `modules/terminal/terminal.nix` and `modules/gaming/gaming.nix`. |
| `modules/hosts/aether/disko.nix` | Declarative GPT partitioning and LVM layout (6 physical disks -> `pool` VG -> `root`, `nix`, `swap` LVs; 500M ESP on `nvme_samsung_1`). | **High-risk.** Do not modify unless explicitly requested. |
| `modules/terminal/` | Terminal & dev environment HM module (`terminal.nix`): Ghostty, Zsh (`oh-my-zsh`), Starship, `direnv`, `devenv`, `eza`, `fd`, `fzf`, `btop` (CUDA), Vim, Git (`delta`, GPG signing), Jujutsu (`jj` from unstable), GPG + GPG-agent (SSH support), SSH, IDE pinentry generator. | `git/excludesFile` is active. **`zsh/.zlogin`, `zsh/.zshenv`, `zsh/.zshrc`, and `gnupg/pinentry-ide.sh` are unreferenced legacy files** (see §6). |
| `modules/gaming/` | Gaming HM module (`gaming.nix`): Lutris (Proton-GE, Wine, Winetricks, linked to system Steam), PrismLauncher, `wowup-cf`. | Unfree package `wowup-cf` is allowlisted in `home.nix`. |
| `i3/` | `i3_config` and `i3status_config`, linked to `~/.config/i3/config` and `~/.config/i3status/config` via `home.file` in `home.nix`. | Migrated from Manjaro; contains some legacy Manjaro autostart/keybind entries. |
| `restic/` | `excludesFile` and `includesFile` read directly by `services.restic` in `configuration.nix`. | `includesFile` targets WoW `AddOns` and `WTF` paths. |
| `secrets/` & `.sops.yaml` | SOPS-encrypted `secrets/secrets.yaml` and `age` creation rules. | **Sensitive.** Never decrypt, log, or commit plaintext secrets. |
| `rebuild.sh`, `diff.sh`, `nixfmt.sh` | Repo-to-`/etc/nixos/` deployment, diffing, and formatting scripts. | See §3 and §6 for script scope and quirks. |
| `check.sh` | Tiered verification script (`lint`, `eval`/`validate`, `build`, `all`; default runs `lint` + `eval`). Uses pinned `pins.nix` tools when missing from `PATH`. | Shared by local workflows and `.github/workflows/ci.yml`. |
| `.github/workflows/ci.yml`, `.github/actions/setup-nix/`, `.github/dependabot.yml` | GitHub Actions PR CI running tiered checks (`Tier 1: Lint & Format` -> `Tier 2: Evaluate Configurations` -> `Tier 3: Targeted Build Validation` -> `CI Gate`) against the PR merge commit, with SHA-pinned actions kept fresh by Dependabot. | Skips full `nixos-rebuild build` (~31.5 GiB closure with unfree packages exceeds GitHub runner disk). |
| `bootstrap.sh`, `install.sh`, `modules/hosts/_template/` | Live ISO installer: `bootstrap.sh` clones the repo to `/tmp/nixos-config` and `exec`s `install.sh`, which scaffolds `modules/hosts/<name>/` (from `_template/{configuration,default,disko}.nix` or by copying a host), partitions via disko, and runs `nixos-install`. | **Live ISO only; never run on the live host.** Test with `./install.sh --dry-run --root /tmp/fake-mnt`. |
| `modules/hosts/aether/hardware-configuration.nix` | Tracked hardware scan generated by `nixos-generate-config` (excluded from `nixfmt`/`statix`/`deadnix`). | Regenerate on the target host rather than hand-editing. |

### Where New Configuration Belongs

- **Hardware, boot, kernel, mounts, firewall, root daemons, system users, system-wide services:** `configuration.nix`.
- **User packages, desktop apps, dotfiles, user services:** `home.nix`, or a domain module under `modules/<domain>/<domain>.nix` imported by `home.nix`.
- **Static non-Nix configs (WM, ignore lists, backup lists):** Alongside their owning directory (`i3/`, `restic/`, `modules/<domain>/`) and referenced via relative Nix paths (`./...`).

## 3. Commands & Verification Workflows

### Safe / Read-Only Checks

```bash
# Default pre-merge verification gate (Tier 1 lint + Tier 2 multi-host eval)
./check.sh

# Run all tiers locally including Tier 3 targeted builds (niri validate, opencode-quota, zellij-room)
./check.sh all

# Or run individual tiers (matching GitHub Actions CI)
./check.sh lint
./check.sh eval
./check.sh build

# Full NixOS build verification (required alongside ./check.sh on a real host; does not mutate the live system)
./rebuild.sh build

# Parse-check all Nix files in the repo (fast, no host dependencies)
for f in $(fd -e nix); do nix-instantiate --parse "$f" > /dev/null && echo "OK: $f"; done

# Check formatting of specific edited file(s) without modifying them
nixfmt --check <file.nix>

# Compare repo files against live /etc/nixos/ (read-only; see §6 for fd quirk)
./diff.sh
```

> **CI build caveat:** Full `./rebuild.sh build` produces a ~31.5 GiB closure with unfree packages (CUDA/Ollama, IntelliJ IDEA, NVIDIA kernel modules, Steam/Lutris), which exceeds GitHub-hosted runner disk budgets, so GitHub Actions runs `./check.sh` tiers (lint, multi-host eval against each host's real `default.nix`, and targeted build-time validators) rather than a full `nixos-rebuild build`.

### Formatting

```bash
# Format specific edited file(s)
nixfmt <file.nix>

# Or format all .nix files across the repository (excluding hardware-configuration.nix)
./nixfmt.sh
```

> **Formatting rule:** `./check.sh lint` enforces `nixfmt --check` across the entire repository, so format any `.nix` file you edit with `nixfmt <file.nix>` (or `./nixfmt.sh`) before finishing.

### System Mutation & Secrets (Require Explicit Owner Approval)

```bash
# Live ISO installer (partitions disks with disko and runs nixos-install). Only ever
# run on the NixOS live installer; `--dry-run` is the only mode safe elsewhere.
./install.sh [--dry-run] [--host <name>] [--from <host|_template>] [--root <path>]

# Mutate live system (requires explicit owner approval; `./rebuild.sh build` / `dry-build` / `build-vm` are safe for verification)
./rebuild.sh <test|boot|switch>

# Edit SOPS secrets (sops is not globally installed; run via nix-shell)
nix-shell -p sops --run "sops secrets/secrets.yaml"
```

## 4. Conventions & Coding Standards

- **Unfree Packages (Strict Allowlist):** Never set `nixpkgs.config.allowUnfree = true`. Add package names explicitly (sorted alphabetically) to `nixpkgs.config.allowUnfreePredicate`:
  - System packages -> `configuration.nix` (currently: `nvidia-settings`, `nvidia-x11`, `steam`, `steam-unwrapped`).
  - Home Manager packages (including from `modules/*`) -> `home.nix` (currently: `clockify`, `davinci-resolve`, `discord`, `idea`, `obsidian`, `rider`, `terraform`, `wowup-cf`).
- **Package List Sorting:** Keep `home.packages` and `allowUnfreePredicate` lists sorted alphabetically.
- **Unstable Channel:** Import `<nixos-unstable>` selectively via `unstablePkgs = import <nixos-unstable> { inherit pkgs; };` only when stable lacks a package or required version (currently used for `jujutsu`).
- **XDG Compliance:** Respect `home.preferXdgDirectories = true` and use `config.xdg.configHome`, `config.xdg.dataHome`, and `config.xdg.stateHome` where supported.
- **State Versions:** Never change `system.stateVersion = "24.11"` or `home.stateVersion = "24.11"` unless explicitly requested after reviewing NixOS / Home Manager release notes (system upgrades have progressed past 24.11 while keeping `stateVersion` pinned).
- **Git & VCS Workflow:** Default branch is `main`. Use short-lived worktrees; once verified with `./check.sh` (and `./rebuild.sh build` on a real host), sign off the branch and merge into `main` (or open a PR validated by GitHub Actions). Commits are GPG-signed by default (`programs.git.signing.signByDefault = true`); Jujutsu (`jj`) is also configured alongside Git.

## 5. Safety Guardrails (Hard Rules)

1. **No live system mutations without approval:** Never run `./rebuild.sh switch|boot|test`, `nixos-rebuild switch|boot|test`, `disko`, or modify/delete anything under `/etc/nixos/`. (`./rebuild.sh build`, `dry-build`, and `build-vm` do not mutate the live system and are allowed for verification.)
2. **No disk layout edits without explicit request:** Do not edit `modules/hosts/aether/disko.nix` unless the task explicitly asks for disk/LVM changes.
3. **Zero secret exposure:** Never decrypt, read plaintext, print, log, or commit secrets from `secrets/secrets.yaml`, `/home/timj/.config/sops/age/keys.txt`, `/home/timj/.config/restic/password`, or GPG/SSH keys.
4. **No generated/local artifacts in Git:** Never hand-edit `hardware-configuration.nix` (regenerate via `nixos-generate-config` on the target host when needed) and never stage `result` or `result/`.
5. **Preserve comments and TODOs:** Do not delete commented-out config blocks (e.g., `ollama` CUDA block, `nixGL`, `resilio`, `nix-index`) or `# todo` notes without confirming—they track active workarounds and planned migrations.

## 6. Known Quirks & Sharp Edges

- **`rebuild.sh` and `diff.sh` `fd` flattening quirk:** Both scripts run `DIRECTORIES=$(fd --type d)` and `FILES=$(fd .nix)` and copy them flat into `/etc/nixos/` (or temp dir). Because `fd` searches recursively and treats `.nix` as a regex, nested `.nix` files and subdirectories are copied both inside `modules/` and flattened at top level, and stale files in `/etc/nixos/` are never cleaned up.
- **Unreferenced legacy files in `modules/terminal/`:** `modules/terminal/zsh/.zlogin`, `.zshenv`, `.zshrc`, and `modules/terminal/gnupg/pinentry-ide.sh` are **not imported or sourced** anywhere and are deprecated/pending removal in a follow-up cleanup PR. Zsh is configured declaratively in `modules/terminal/terminal.nix`, and IDEA pinentry is generated via `home.file."${config.xdg.dataHome}/gnupg/pinentry.sh"`.
- **Unpinned `disko` tarball vs pinned `sops-nix`:** `configuration.nix` fetches `disko` from `master.tar.gz` (no `sha256`) and `sops-nix` from a pinned commit with `sha256`. Updating `sops-nix` requires updating its `sha256`.
- **Dual `allowUnfreePredicate` limitation:** Unfree packages added in `modules/gaming/gaming.nix` or `modules/terminal/terminal.nix` must currently be allowlisted in `home.nix` (see TODO in `modules/gaming/gaming.nix`).
- **Order-sensitive display config:** `services.xserver.xrandrHeads` in `configuration.nix` (`HDMI-0`, `DP-4`, `DP-2`) is output-order-sensitive; do not reorder casually.
- **GPG manages SSH keys:** `services.ssh-agent.enable = false`; `services.gpg-agent.enableSshSupport = true` provides `/run/user/1000/gnupg/S.gpg-agent.ssh` (also referenced in `.gradle/gradle.properties`).
- **Known active TODOs in config:** `sops.age.keyFile` under `/home/timj/.config/...` (circular dependency note), Restic `passwordFile` outside SOPS, Restic migration to Home Manager (upstream PR #6729), `home.sessionPath` (HM issue #3417), firewall port `24800` debugging, SSH `PasswordAuthentication = true`, `hardware.ckb-next.enable = false`, and `i3/i3_config` class typo `obisidian`.

## 7. Verification Checklist Before Finishing

1. Changes live in the right layer (`configuration.nix` vs `home.nix` vs `modules/<domain>/`) and do not edit dead/unreferenced files.
2. Any newly added unfree packages are explicitly allowlisted in the correct `allowUnfreePredicate` (`configuration.nix` vs `home.nix`).
3. Run **both** `./check.sh` and `./rebuild.sh build` to verify that the full system configuration evaluates and builds cleanly (not just `./check.sh`, which can miss build-time failures that break `switch`). If `./rebuild.sh build` cannot run (e.g., on a non-NixOS machine), explicitly report that. Format only edited `.nix` files with `nixfmt <file.nix>`.
4. `git status` / `git diff` shows no plaintext secrets, local keys, `result`, or unintended formatting churn.
5. `AGENTS.md` and `GLOSSARY.md` are updated if new modules, hosts, mounts, scripts, or conventions were introduced.
6. Clearly report any host-level checks not run (e.g., `./rebuild.sh build` if blocked, or `./rebuild.sh test` / `switch`).

## 8. Related Documentation

- [`GLOSSARY.md`](./GLOSSARY.md) — Hostnames, storage/mounts, scripts, modules, hardware, and NixOS terminology as used in this repo.
- [`README.md`](./README.md) — Personal NixOS/Home Manager overview, host onboarding guide, migration checklist, and software idea inbox.
- [`modules/hosts/README.md`](./modules/hosts/README.md) — Host directory layout and new-host onboarding checklist.
- [`modules/terminal/README.md`](./modules/terminal/README.md) — Brief overview of the terminal module.
