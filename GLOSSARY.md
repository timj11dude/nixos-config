# GLOSSARY.md

Project-specific vocabulary, infrastructure identifiers, storage paths, scripts, modules, and NixOS concepts as used in `nixos-config`.
Keep entries concise, factual, alphabetically ordered within each section, and free of secret values.

## 1. Hosts, Servers & Network Entities

| Term | Meaning / Role in This Repo | Where Referenced |
| --- | --- | --- |
| `aether` | Primary NixOS workstation configured by this repository (`networking.hostName`, mapped to `127.0.0.1`). | `configuration.nix` |
| `cluster` / `kube_control_plane` | Local host aliases mapped to `192.168.0.178` in `/etc/hosts` for a local Kubernetes control plane. | `configuration.nix` |
| `jacoserver` / `truenas` | Local TrueNAS server at `192.168.1.177` providing CIFS shares (`private`, `Photos`, `Media`) mounted under `/mnt/jacoserver/*`, plus the Restic backup repository target. | `configuration.nix` |
| `Tailscale` / `trayscale` | Mesh VPN daemon enabled at system level (`services.tailscale`) paired with the `trayscale` user tray service (`services.trayscale`). | `configuration.nix`, `home.nix` |

## 2. Users, Identities & Key Roles

| Term | Meaning / Role in This Repo | Where Referenced |
| --- | --- | --- |
| `age` key (`&primary`) | Public `age` key in `.sops.yaml` paired with host-local private key `/home/timj/.config/sops/age/keys.txt` used by `sops-nix` to decrypt `secrets/secrets.yaml` at activation. | `.sops.yaml`, `configuration.nix` |
| GPG Agent (SSH support) | User service (`services.gpg-agent` with `enableSshSupport = true` and `pinentry-qt`) that handles both Git commit signing and SSH authentication via `/run/user/1000/gnupg/S.gpg-agent.ssh`. Standard `ssh-agent` is disabled. | `modules/terminal/terminal.nix`, `home.nix` |
| `Personal` / `Work` | Declarative Firefox Multi-Account Containers (`containersForce = true`) under Firefox profile `timj`. | `home.nix` |
| `timj` | Primary non-root user ("Timothy Jacobson", `tim@jaconet.uk`), Zsh login shell, member of `networkmanager`, `wheel`, `audio`, `video`, allowed SSH user, and Home Manager target user. | `configuration.nix`, `home.nix`, `modules/terminal/terminal.nix` |

## 3. Storage, Disks, Mounts & Backups

| Term | Meaning / Role in This Repo | Where Referenced |
| --- | --- | --- |
| `ESP` (`/boot`) | 500M EFI System Partition (`EF00`, `vfat`, `umask=0077`) on `nvme_samsung_1`, used by `systemd-boot`. | `modules/hosts/aether/disko.nix`, `configuration.nix` |
| `homeBackup` | Hourly (`*:02`, `Persistent = true`) Restic backup of `/home/timj` excluding patterns in `restic/excludesFile`, stored at `/mnt/jacoserver/timj/restic_backups`. | `configuration.nix`, `restic/excludesFile` |
| `homeBackupIncludes` | Companion Restic backup job targeting specific paths in `restic/includesFile` (World of Warcraft `_retail_/Interface/AddOns` and `_retail_/WTF` under Steam compatdata). | `configuration.nix`, `restic/includesFile` |
| `/mnt/jacoserver/{timj,photos,media}` | Systemd-automounted (`noauto`, 60s idle timeout) CIFS mounts from `//192.168.1.177/{private,Photos,Media}`, authenticated via `sops.secrets."truenas/login"`. | `configuration.nix` |
| `pool` (LVM VG) | Primary LVM volume group spanning 6 physical disks (`nvme_samsung_1`, `nvme_ct_1`, `ssd_samsung_1`, `ssd_samsung_2`, `hdd_wdc_1`, `hdd_st_1`), sliced into 3 LVs: `root` (`100%`, ext4 at `/`), `nix` (`400G`, ext4 `noatime` at `/nix`), and `swap` (`64G`). | `modules/hosts/aether/disko.nix` |

## 4. Repository Modules, Scripts & Legacy Files

| Term | Meaning / Role in This Repo | Where Referenced |
| --- | --- | --- |
| `diff.sh` | Stages `$(fd .nix)` and `$(fd --type d)` into a temp directory and runs `diff -qr /etc/nixos/ $TEMP`. Read-only; shares the `fd` flattening quirk with `rebuild.sh`. | `diff.sh` |
| `modules/gaming` | Home Manager module configuring Lutris (wired to `osConfig.programs.steam.package`, `proton-ge-bin`, `wineWow64Packages.full`, `winetricks`), `prismlauncher`, and `wowup-cf`. | `modules/gaming/gaming.nix`, `home.nix` |
| `modules/terminal` | Home Manager module configuring Ghostty, Zsh (`oh-my-zsh`), Starship, `direnv`, `devenv`, `eza`, `fd`, `fzf`, `btop` (CUDA), Vim, Git (`delta`, GPG signing), Jujutsu (`jj`), GPG + GPG-agent, SSH, and IDEA pinentry script generation. | `modules/terminal/terminal.nix`, `modules/terminal/README.md`, `home.nix` |
| `modules/terminal/gnupg/pinentry-ide.sh` | **Deprecated unreferenced legacy file** (pending removal in a follow-up cleanup PR) with hardcoded `/nix/store/...` paths; superseded by `home.file."${config.xdg.dataHome}/gnupg/pinentry.sh"` in `modules/terminal/terminal.nix`. | `modules/terminal/gnupg/pinentry-ide.sh` |
| `modules/terminal/zsh/.{zlogin,zshenv,zshrc}` | **Deprecated unreferenced legacy dotfiles** (pending removal in a follow-up cleanup PR) from a pre-Nix setup (references `~/.oh-my-zsh`, `sdkman`, `~/.zsh_aliases`); active Zsh config is declared in `modules/terminal/terminal.nix`. | `modules/terminal/zsh/` |
| `nixfmt.sh` | `nix-shell` script (`nixfmt-rfc-style`) running `nixfmt *.nix`. Only covers top-level `.nix` files, not `modules/**/*.nix`. | `nixfmt.sh` |
| `rebuild.sh` | Copies `$(fd .nix)` and `$(fd --type d)` to `/etc/nixos/` via `sudo cp` and runs `sudo nixos-rebuild $@`. Mutates `/etc/nixos/` and the live host. | `rebuild.sh` |

## 5. NixOS & Toolchain Concepts (Project-Specific Usage)

- **`allowUnfreePredicate`**: Explicit package-name allowlist used instead of `allowUnfree = true`. Maintained separately in `configuration.nix` (system packages) and `home.nix` (Home Manager packages, including packages from `modules/*`).
- **`asBytes`**: Helper `let`-binding in `configuration.nix` converting `KB`/`MB`/`GB`/`TB` into bytes for `nix.extraOptions` (`min-free` 1 GB, `max-free` 10 GB auto-GC).
- **`Disko`**: Declarative disk-partitioning NixOS module imported via `builtins.fetchTarball` from `nix-community/disko` `master.tar.gz` (unpinned) and configured in `modules/hosts/aether/disko.nix`.
- **`Home Manager` (`<home-manager/nixos>`)**: Integrated as a NixOS module rather than standalone activation; sets `backupFileExtension = "bak"` and loads `./home.nix` for `timj`.
- **`<nixos-unstable>`**: Secondary Nix channel imported via `import <nixos-unstable> { inherit pkgs; }` for packages needing newer versions than stable (currently `programs.jujutsu.package`).
- **`sops-nix`**: Secret management module imported from a pinned GitHub tarball (`sha256` verified) in `configuration.nix`; decrypts `secrets/secrets.yaml` into runtime paths (`config.sops.secrets.<name>.path`).
- **`stateVersion`**: Pinned at `"24.11"` in both `configuration.nix` (`system.stateVersion`) and `home.nix` (`home.stateVersion`) to preserve stateful defaults across NixOS channel upgrades.
- **`XDG Base Directories`**: Enforced via `home.preferXdgDirectories = true`; configs/data/state (Zsh, GPG, Firefox, `KUBECONFIG`) target `config.xdg.{configHome,dataHome,stateHome}`.

## 6. Hardware, Display & Desktop Terms

| Term | Meaning / Role in This Repo | Where Referenced |
| --- | --- | --- |
| `ckb-next` | Corsair peripheral driver (`hardware.ckb-next.enable = false`, disabled for debugging; workspace 8 window assignment still present in `i3/i3_config`). | `configuration.nix`, `i3/i3_config` |
| `Ghostty` | Default terminal emulator (`TERMINAL=ghostty`, bound to `$mod+Return` in i3; Dracula theme, JetBrains Mono, no titlebar). | `home.nix`, `modules/terminal/terminal.nix`, `i3/i3_config` |
| `HDMI-0`, `DP-4`, `DP-2` | Physical NVIDIA X11 monitor outputs in `xrandrHeads` (order-sensitive): `HDMI-0` left of `DP-4`, `DP-4` center (i3 workspaces 1 & 2), `DP-2` right of `DP-4` rotated right. | `configuration.nix`, `i3/i3_config` |
| `i3` / `i3status` | Tiling window manager (`defaultSession = "none+i3"`) and status bar configured via `i3/i3_config` and `i3/i3status_config` (linked via `home.file`). Screenshots use `maim` + `xclip` + `xdotool`. | `configuration.nix`, `home.nix`, `i3/` |
| `NVIDIA` (`open = true`) | System GPU driver (`videoDrivers = [ "nvidia" ]`, `modesetting.enable = true`, `open = true`); CUDA is enabled for `btop`, currently disabled (`acceleration = false`) for user `ollama`. | `configuration.nix`, `home.nix`, `modules/terminal/terminal.nix` |
| Port `24800` | TCP and UDP port opened in `networking.firewall` (default Synergy/Barrier/Deskflow port; marked with `# TODO debug this isn't working`). | `configuration.nix` |

## 7. Acronyms & Short Names

- **`CIFS`**: Common Internet File System (SMB mount protocol used for `/mnt/jacoserver/*`).
- **`ESP`**: EFI System Partition (`/boot`).
- **`HM`**: Home Manager.
- **`jj`**: Jujutsu VCS (`programs.jujutsu`), configured with `delta` as diff tool.
- **`LV` / `PV` / `VG`**: Logical Volume / Physical Volume / Volume Group (Linux LVM terms in `modules/hosts/aether/disko.nix`).
- **`SOPS`**: Secrets OPerationS (`sops-nix` encrypted YAML store).
