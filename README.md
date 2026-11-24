# nixos-config
Personal NixOS and Home Manager configuration for host `aether`.

## Architecture & Deployment

- **System & User Config:** `configuration.nix` manages system-level NixOS configuration and imports Home Manager as a NixOS module (`<home-manager/nixos>` via `home-manager.users.timj = ./home.nix`), providing a single source of truth for system services, user packages, dotfiles, and user services.
- **Deployment:** Configuration files are synced into `/etc/nixos/` and applied with `./rebuild.sh` (compare live state with `./diff.sh`).
- **Agent & Contributor Docs:** See [`AGENTS.md`](./AGENTS.md) for workflows, conventions, and guardrails, and [`GLOSSARY.md`](./GLOSSARY.md) for hostnames, storage mounts, scripts, and project terminology.

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
