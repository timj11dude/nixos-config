# nixos-config
Personal NixOS and Nix home-manager configuration

## Nix Home Manager

A utility for adopting Nix onto an existing non-NixOS system.

Provide functionality for being able to reproduce entire home user setup from a single source of truth.

Combines the installation and management of any user request packages, with setup and configuration.
Covering all types of programs, configurations and user services.

This project should be clone into `~/.config/home-manager`

## TODO
Tracking what parts of my existing setup I would like to manage with `home-manager`,
and still needs migrating.

### Idea Inbox
List of software or sources to consider for additional installation, that have not yet been categorised.

- https://karakeep.app/
- https://www.youtube.com/watch?v=rWMQ-g2QDsI
- https://github.com/ankitpokhrel/jira-cli
- https://youtu.be/79rmEOrd5u8?si=AMH1itAA0Tq2mG84

### Packages
User specific services I could have installed via nix instead of the system's default package manager.
These should be anything I don't have need to be specifically configured.

- [x] Shell Editor - Vim
- [x] direnv
- [x] btop
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
      - [x] Settings & Addons part of restic backed up
- [ ] VPN Unlimited
- [ ] AWS CLI (maybe only for work specific deployment?) (may want to pre-configure too)

### Packages + Configurations
Programs that I have personal configurations for.

- [x] Ghostty (terminal emulator)
- [x] ZSH
  - [x] Aliases
  - [ ] Custom Scripts (i.e. `get-lab`)
  - [x] rofi
    - [x] rofi-emoji
    - [x] rofi-calc
  - [x] Starship (custom prompt)
  - [x] eza (aka exa)
  - [ ] mc
- [x] git
- [x] GPG
- [x] SSH
- [x] Firefox
- [ ] i3 power management (migrate from manjaro script)

### Services
These will have to be internal services, ought not rely on having root privilages to start systemd level services

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
