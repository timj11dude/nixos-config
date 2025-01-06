# Nix Home Manager

A utility for adopting Nix onto an existing non-NixOS system.

Provide functionality for being able to reproduce entire home user setup from a single source of truth.

Combines the installation and management of any user request packages, with setup and configuration.
Covering all types of programs 

## TODO
Tracking what parts of my existing setup I would like to manage with `home-manager`,
and still needs migrating.

### Packages
User specific services I could have installed via nix instead of the system's default package manager.
These should be anything I don't have need to be specifically configured.

- [ ] Shell Editor - Vim
- [x] btop
- [ ] IntelliJ
- [ ] Obsidian

### Packages + Configurations
Programs that I have personal configurations for.

- [ ] Shell - ZSH
- [ ] GPG
- [ ] SSH
- [ ] ZSH
    - [ ] Aliases
- [x] Firefox

### Services
These will have to be internal services, ought not rely on having root privilages to start systemd level services

- [x] GPG Agent
- [ ] Resilio Sync
- ~~Docker~~ (Needs to be enabled at system level)