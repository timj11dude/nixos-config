# Terminal Configuration Module

Set of configurations for the terminal, including an emulator, and commonly used tools within the terminal.

## Secrets & Ephemeral GPG (`secretspec` + `bws`)

`secretspec` and Bitwarden Secrets Manager (`bws`) are installed via `modules/home/terminal/default.nix`, with required secrets declared in `../../../secretspec.toml`:

- `GPG_PRIVATE_KEY` / `GPG_OWNERTRUST`: Loaded only into an ephemeral RAM-backed `GNUPGHOME` via `with-gpg` (nothing is persisted to `~/.local/share/gnupg`).
  - Run a single command: `with-gpg git commit -S -m "..."` or `with-gpg git push`
  - Start an interactive shell with GPG & SSH agent active: `with-gpg`
- `SOPS_AGE_KEY` / `RESTIC_PASSWORD`: Materialized on a fresh machine with `../../../bootstrap-secrets.sh` (requires `BWS_ACCESS_TOKEN` and `~/.config/secretspec/config.toml`).