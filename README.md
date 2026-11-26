# nixos-config
Multi-host personal NixOS and Home Manager configuration (starting with host `aether`).

## Onboarding

> [!IMPORTANT]
> For a quick reminder when working directly inside the hosts directory, see [`modules/hosts/README.md`](./modules/hosts/README.md).

Follow these steps to add a new NixOS machine to this repository (or to bootstrap an existing host from a fresh clone):

1. **Create the host directory from the template:**
   ```sh
   cp -r modules/hosts/_template modules/hosts/<hostname>
   ```
   Edit `modules/hosts/<hostname>/configuration.nix` and replace `__HOSTNAME__` with `<hostname>` (matching the directory name so `./rebuild.sh` auto-detects it via `$(hostname -s)`). Directories starting with `_` (such as `_template`) are ignored by `./check.sh`; any other directory under `modules/hosts/` is automatically evaluated.

2. **Generate `hardware-configuration.nix` on the target machine:**
   `modules/hosts/<hostname>/default.nix` imports `./hardware-configuration.nix`, which is gitignored and machine-local:
   ```sh
   nixos-generate-config --show-hardware-config > modules/hosts/<hostname>/hardware-configuration.nix
   ```
   - If the host uses a host-local `disko.nix`, pass `--no-filesystems` to `nixos-generate-config` so `fileSystems` definitions do not conflict.
   - If setting up an existing host (such as `aether`) from a fresh clone, run this same command on that machine to populate its gitignored `hardware-configuration.nix` before rebuilding.

3. **Configure host options, hardware, and overrides** in `modules/hosts/<hostname>/configuration.nix`:
   - **Feature toggles:** Enable host-level options as needed (`ai.enable`, `gaming.enable`, `programs.noctalia.enable`, `backups.restic.enable`, `services.orca-ide.enable` / `services.orca-server.enable`, `services.herdr.enable`). Coupled Home Manager options in `home.nix` (`my.gaming.enable`, `my.niri.enable`, `programs.noctalia.enable`, and `my.terminal.cudaSupport`) follow `osConfig` automatically.
   - **Shared defaults (`lib.mkDefault`):** Base system (`configuration.nix`) and Home Manager (`home.nix`) options use `lib.mkDefault`, so hosts can override defaults cleanly (for example `services.greetd.enable = false;` or `home-manager.users.timj.my.music.enable = false;`).
   - **GPU & unfree packages:** Set `services.xserver.videoDrivers` (e.g. `[ "nvidia" ]`) and add any host-specific unfree packages to `nixpkgs.config.allowUnfreePackages`.
   - **Disks:** Do **not** import the root `../../../disko.nix` unless the machine matches `aether`'s exact disk layout; keep any host-specific `disko.nix` inside `modules/hosts/<hostname>/`.
   - **Niri overrides:** Use `home-manager.users.timj.my.niri.extraConfig` (for example `builtins.readFile ./niri.kdl`) for `environment`, `output`, and `spawn-sh-at-startup` blocks, and `home-manager.users.timj.my.niri.extraInputConfig` for nodes inside the shared `input { ... }` block (such as `touchpad { off }`, because `niri validate` rejects duplicate top-level `input` blocks).
   - **Secrets (`sops-nix`):** Only hosts that declare `sops.secrets.*` require the `age` private key at `/home/timj/.config/sops/age/keys.txt` (`chmod 600`) at activation time.

4. **Verify, build, and enable `autoUpgrade`:**
   ```sh
   # Parse, multi-host eval, nixfmt, statix, and deadnix checks
   ./check.sh

   # Build and activate on the target machine
   ./rebuild.sh --host <hostname> dry-build
   ./rebuild.sh --host <hostname> switch

   # Point /etc/nixos/configuration.nix at the host entrypoint for system.autoUpgrade
   sudo ln -sfn "$PWD/modules/hosts/$(hostname -s)/default.nix" /etc/nixos/configuration.nix
   ```
   - `./check.sh` evaluates hosts without a local `hardware-configuration.nix` using `modules/system/hardware-stub.nix`, whereas `./rebuild.sh` requires the real machine-generated `hardware-configuration.nix`.
   - If you modified Niri config (`extraConfig` / `extraInputConfig`), you can also run the build-time `niri validate` check directly before rebuilding:
     ```sh
     nix-build '<nixpkgs/nixos>' --no-out-link \
       --arg configuration ./modules/hosts/<hostname>/default.nix \
       -A 'config.home-manager.users.timj.xdg.configFile."niri/config.kdl".source'
     ```

5. **Commit the tracked host files:**
   Commit `modules/hosts/<hostname>/default.nix`, `modules/hosts/<hostname>/configuration.nix`, and any host assets (such as `niri.kdl`). Leave `hardware-configuration.nix` untracked/gitignored.

## Architecture & Deployment

- **Shared Base & Per-Host Entrypoints:** Top-level `configuration.nix` defines shared system defaults (with `lib.mkDefault` for host-overridable options) and imports Home Manager (`home-manager.users.timj = { imports = [ ./home.nix ]; };`). Each machine lives under `modules/hosts/<hostname>/` with `default.nix` (importing `./configuration.nix` and gitignored `./hardware-configuration.nix`). See [Onboarding](#onboarding) and [`modules/hosts/README.md`](./modules/hosts/README.md) when adding a machine.
- **Deployment:** Run `./rebuild.sh [--host <name>] <switch|boot|test|dry-build>`. The host defaults to `$NIXOS_HOST` or `$(hostname -s)` and evaluates `modules/hosts/<host>/default.nix` directly via `-I nixos-config=...`.
- **Auto-Upgrade Symlink:** For `system.autoUpgrade` to evaluate the right host automatically, symlink `/etc/nixos/configuration.nix` to this checkout's `modules/hosts/<hostname>/default.nix` (e.g. `sudo ln -sfn "$PWD/modules/hosts/$(hostname -s)/default.nix" /etc/nixos/configuration.nix`).
- **Agent & Contributor Docs:** See [`AGENTS.md`](./AGENTS.md) for workflows, conventions, and guardrails, and [`GLOSSARY.md`](./GLOSSARY.md) for hostnames, storage mounts, scripts, and project terminology.

## Installing from the NixOS Live ISO

Boot the NixOS installer ISO (graphical or minimal), connect to the network, then run:

```sh
curl -fsSL https://raw.githubusercontent.com/timj11dude/nixos-config/main/bootstrap.sh | bash
```

`bootstrap.sh` clones this repository to `/tmp/nixos-config` (using `nix-shell -p git` if `git` is missing) and hands over to the interactive `./install.sh`, which:

1. Lets you use an existing host, copy one as a template (dropping `disko.nix`, `hardware-configuration.nix`, and optionally NVIDIA / TrueNAS / scanner / ckb-next / Restic config), or create a minimal host from `modules/hosts/_template`.
2. Partitions the target disk with [disko](https://github.com/nix-community/disko) from `modules/hosts/_template/disko.nix` (you edit the `__DISK_ID__` placeholder; a typed `DESTROY` confirmation is required), or uses an already-mounted `/mnt`.
3. Collects `hardware-configuration.nix`, checks for the sops age key (offering `./bootstrap-secrets.sh` or a `keys.txt` import), copies the repo to `/home/timj/Projects/github.com:timj11dude/nixos-config`, links `/etc/nixos/configuration.nix` to the host's `default.nix`, and runs `nixos-install`.

Pass flags through with `bash -s --`, for example `... | bash -s -- --host myhost --from _template`. Run `./install.sh --help` for all options (`--host`, `--from`, `--hardware-config`, `--root`, `--dry-run`, `--yes`). To preview safely anywhere, use `./install.sh --dry-run --root /tmp/fake-mnt`: it scaffolds in a throwaway copy of the repo and only parses/evaluates; it never partitions, installs, or writes to the target root. After the first boot, run `./bootstrap-secrets.sh` and commit `modules/hosts/<name>/`.

## Standalone Install (non-NixOS systems)

This configuration can be used with [home-manager](https://github.com/nix-community/home-manager) on non-NixOS systems like macOS, without needing root permissions to install Nix.

Install Nix as a single user (no root):

```sh
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

On macOS this creates a user-local Nix store under `~/.nix` (or `~/nix`) instead of `/nix`, so no `sudo` is required.

Then install home-manager standalone:

```sh
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update
nix-shell '<home-manager>' -A install
```

Clone this repo into `~/.config/home-manager` and build:

```sh
git clone <this-repo> ~/.config/home-manager
cd ~/.config/home-manager
home-manager switch
```

On first run you may need to point home-manager at this checkout:

```sh
home-manager switch -f ~/.config/home-manager/home.nix
```

Note: some modules in this config reference Linux-specific paths (e.g. `/home/timj`, systemd services). On macOS you may need to adjust `home.homeDirectory` and disable any Linux-only modules in `home.nix`.

## Checks

Run `./check.sh` before rebuilding. It parses every Nix file, evaluates the
full system configuration, checks `nixfmt` formatting across the repository,
and runs `statix` and `deadnix` lint checks. Run `./nixfmt.sh` to auto-format
all Nix files.

## TODO
Tracking what parts of my existing setup I would like to manage with `home-manager`,
and still needs migrating.

### Idea Inbox
List of software or sources to consider for additional installation that have not yet been categorised.

- https://karakeep.app/
- https://www.youtube.com/watch?v=rWMQ-g2QDsI
- https://github.com/ankitpokhrel/jira-cli
- https://youtu.be/79rmEOrd5u8?si=AMH1itAA0Tq2mG84

### Packages
User-specific services I could have installed via nix instead of the system's default package manager.
These should be anything I don't have a need to be specifically configured.

- [x] Shell Editor - Vim
- [x] direnv
- [x] btop
- fun things
  - [ ] install-nothing
  - [ ] cmatrix
- [x] IntelliJ
- [x] Obsidian
- [x] Discord
- [x] Screen grabber / recorder (added to printscreen keypress)
- [x] Steam/Lutris
  - [x] multimc
    - [ ] configure the install location under .local/share
  - [x] (❗) Battle.Net required [weird installation hack](https://www.youtube.com/watch?v=PRY56C9Jce0).
    - [x] World of Warcraft
      - [ ] ❗ Some graphical issues
      - [x] Settings & Addons part of Restic backed up
- [ ] VPN Unlimited
- [ ] AWS CLI (maybe only for work-specific deployment?) (may want to pre-configure too)

### Packages + Configurations
Programs that I have personal configurations for.

- [x] Ghostty (terminal emulator)
- [x] ZSH
  - [x] Aliases
  - [ ] Custom Scripts (i.e. `get-lab`)
  - [x] Rofi
    - [x] Rofi-emoji
    - [x] Rofi-calc
  - [x] Starship (custom prompt)
  - [x] eza (aka exa)
  - [ ] mc
- [x] git
- [x] GPG
- [x] SSH
- [x] Firefox
- [ ] i3 power management (migrate from Manjaro script)

### Services
These will have to be internal services, ought not rely on having root privileges to start systemd level services

- [x] GPG Agent
- [x] Restic Backup
- [ ] IPFS
- [ ] Resilio Sync (consider Syncthing alternative)
- [x] Tailscale
- ~~Docker~~ (Needs to be enabled at system level)

## Additional Notes

- I think I would prefer to return to LVM away from ZFS, and abstract away the HDD management from the quota and redundancy level configuration.
  This time bring the whole system with me, and properly set up caching on LVM this time.
- [x] Local AI engine (Ollama + OpenCode) — see [modules/home/ai](modules/home/ai/README.md).
- https://github.com/devoxx/DevoxxGenieIDEAPlugin
