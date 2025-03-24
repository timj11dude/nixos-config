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

### Packages
User specific services I could have installed via nix instead of the system's default package manager.
These should be anything I don't have need to be specifically configured.

- [x] Shell Editor - Vim
- [ ] direnv
- [x] btop
- [x] IntelliJ
- [x] Obsidian
- [x] Discord
- [ ] Screen grabber / recorder
- [x] Steam/Lutris
  - [x] multimc
    - [ ] configure the install location under .local/share
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
  - [ ] Starship (custom prompt)
- [x] git
- [x] GPG
- [x] SSH
- [x] Firefox
- [ ] i3 power management (migrate from manjaro script)

### Services
These will have to be internal services, ought not rely on having root privilages to start systemd level services

- [x] GPG Agent
- [ ] IPFS
- [ ] Resilio Sync (consider Syncthing alternative)
- [ ] Tailscale
- ~~Docker~~ (Needs to be enabled at system level)

## Additional Notes

- I think I would prefer to return to LVM away from ZFS, and abstract away the HDD management from the quota and redundancy level configuration.
  This time bring the whole system with me, and properly set up caching on LVM this time.
- May want to add a local AI engine (i.e. ollama) to have a local/security over my data.
- https://github.com/devoxx/DevoxxGenieIDEAPlugin
