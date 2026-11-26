# Terminal Configuration Module

Set of configurations for the terminal, including an emulator, and commonly used tools within the terminal.

## GPG & SSH

`services.gpg-agent` is enabled with SSH support (`enableSshSupport = true`) using the persistent GnuPG home at `~/.local/share/gnupg`, with the SSH authentication subkey keygrip declared via `services.gpg-agent.sshKeys`.

## Secrets Bootstrapping (`secretspec` + `bws`)

Bitwarden Secrets Manager (`bws`) is installed via `modules/home/terminal/default.nix`, with host bootstrap secrets (`SOPS_AGE_KEY`, `RESTIC_PASSWORD`) declared in `../../../secretspec.toml` and materialized on a fresh machine via `../../../bootstrap-secrets.sh` (requires `BWS_ACCESS_TOKEN` and `~/.config/secretspec/config.toml`).