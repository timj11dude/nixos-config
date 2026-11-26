# Hosts

Per-host NixOS configurations live under `modules/hosts/<hostname>/`.

> See the root [`Onboarding`](../../README.md#onboarding) guide for the full repository overview.

## Directory Layout

```text
modules/hosts/
├── _template/                     # Starter template (leading `_` excludes it from ./check.sh)
│   ├── configuration.nix          # Minimal host config with `__HOSTNAME__` placeholder
│   └── default.nix                # Thin entrypoint importing ./configuration.nix + ./hardware-configuration.nix
└── <hostname>/
    ├── configuration.nix          # Tracked host config (imports ../../../configuration.nix)
    ├── default.nix                # Tracked entrypoint (imports ./configuration.nix + ./hardware-configuration.nix)
    ├── hardware-configuration.nix # Gitignored, machine-local (generated on the target host)
    └── ...                        # Optional host-specific assets (e.g. niri.kdl, local disko.nix)
```

### Why `default.nix` and `configuration.nix` are split

- **`./rebuild.sh`** always evaluates `modules/hosts/<hostname>/default.nix` and fails fast if `hardware-configuration.nix` is missing, preventing accidental builds without machine hardware/filesystem modules.
- **`./check.sh`** loops over every `modules/hosts/*/` (skipping `_*`). When `hardware-configuration.nix` exists locally it evaluates `default.nix`; otherwise it evaluates `configuration.nix` together with [`modules/system/hardware-stub.nix`](../system/hardware-stub.nix).

## Onboarding a New Host

1. **Copy `_template/`:**
   ```sh
   cp -r modules/hosts/_template modules/hosts/<hostname>
   ```
   Replace `__HOSTNAME__` in `modules/hosts/<hostname>/configuration.nix` with `<hostname>`. Ensure `networking.hostName` matches the directory name so `./rebuild.sh` auto-detects the host via `$(hostname -s)`.

2. **Generate `hardware-configuration.nix` on the target machine** (this file is gitignored and must stay untracked):
   ```sh
   nixos-generate-config --show-hardware-config > modules/hosts/<hostname>/hardware-configuration.nix
   ```
   - Pass `--no-filesystems` if the host defines its own `disko.nix`.
   - When cloning this repo onto an existing host (e.g. `aether`), run the same command on that host to populate its local `hardware-configuration.nix`.

3. **Customize `modules/hosts/<hostname>/configuration.nix`:**
   - **System toggles:** Enable host features as needed (`ai.enable`, `gaming.enable`, `programs.noctalia.enable`, `backups.restic.enable`, `services.orca-ide.enable` / `services.orca-server.enable`, `services.herdr.enable`). Home Manager modules (`my.gaming.enable`, `my.niri.enable`, `programs.noctalia.enable`, `my.terminal.cudaSupport`) derive defaults from `osConfig`.
   - **Override shared defaults:** Base options in `configuration.nix` and `home.nix` use `lib.mkDefault`, so you can override them directly (including under `home-manager.users.timj = { ... };`).
   - **GPU & unfree packages:** Set `services.xserver.videoDrivers` and host-specific `nixpkgs.config.allowUnfreePackages` if required.
   - **Disks:** Never import root `../../../disko.nix` for a new host unless it shares `aether`'s exact disk IDs and LVM layout.
   - **Niri overrides:** Use `home-manager.users.timj.my.niri.extraConfig` (e.g. `builtins.readFile ./niri.kdl`) for `environment`, `output`, and `spawn-sh-at-startup`, and `home-manager.users.timj.my.niri.extraInputConfig` for entries inside the shared `input { ... }` block (such as `touchpad { off }`; `niri validate` rejects duplicate top-level `input` nodes).
   - **Secrets (`sops-nix`):** If the host declares `sops.secrets.*`, ensure `/home/timj/.config/sops/age/keys.txt` (`chmod 600`) exists on the machine before activation.

4. **Check, rebuild, and symlink for `autoUpgrade`:**
   ```sh
   ./check.sh
   ./rebuild.sh --host <hostname> dry-build
   ./rebuild.sh --host <hostname> switch
   sudo ln -sfn "$PWD/modules/hosts/$(hostname -s)/default.nix" /etc/nixos/configuration.nix
   ```
   If you customised Niri config (`extraConfig` or `extraInputConfig`), you can also verify `niri validate` directly before rebuilding:
   ```sh
   nix-build '<nixpkgs/nixos>' --no-out-link \
     --arg configuration ./modules/hosts/<hostname>/default.nix \
     -A 'config.home-manager.users.timj.xdg.configFile."niri/config.kdl".source'
   ```

5. **Commit tracked files:** Commit `default.nix`, `configuration.nix`, and any host assets (`niri.kdl`, etc.); keep `hardware-configuration.nix` untracked.
