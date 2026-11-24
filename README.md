# nixos-config
Personal NixOS and Home Manager configuration for host `aether`.

## Architecture & Deployment

- **System & User Config:** `configuration.nix` manages system-level NixOS configuration and imports Home Manager as a NixOS module (`<home-manager/nixos>` via `home-manager.users.timj = ./home.nix`), providing a single source of truth for system services, user packages, dotfiles, and user services.
- **Deployment:** Configuration files are synced into `/etc/nixos/` and applied with `./rebuild.sh` (compare live state with `./diff.sh`).
- **Agent & Contributor Docs:** See [`AGENTS.md`](./AGENTS.md) for workflows, conventions, and guardrails, and [`GLOSSARY.md`](./GLOSSARY.md) for hostnames, storage mounts, scripts, and project terminology.

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
- May want to add a local AI engine (i.e. ollama) to have a local/security over my data.
- https://github.com/devoxx/DevoxxGenieIDEAPlugin
