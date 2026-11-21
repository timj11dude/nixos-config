# AI

Local LLM tooling: a system-wide [Ollama](https://ollama.com) server and
[OpenCode](https://opencode.ai) configured to use it.

The module is split in two, because Ollama is a shared daemon while OpenCode is
a per-user program:

| File | Loaded by | Manages |
| --- | --- | --- |
| `nixos.nix` | `configuration.nix` | `services.ollama`, model pulling, model-store migration |
| `default.nix` | `home.nix` | `programs.opencode`, provider and model config |

## Enable it

The options live in the host configuration:

```nix
ai = {
  enable = true;
  ollama.legacyModelDir = "/home/<user>/.ollama/models";
};
```

`ai.ollama.enable` and `ai.opencode.enable` both default to `true` when
`ai.enable` is set, so they only need overriding to turn one half off.

## Ollama

The server listens on `127.0.0.1:11434` and runs as the `ollama` system user
with `pkgs.ollama-cuda`. CUDA components are unfree, so `configuration.nix`
allows them through `allowUnfreePredicate`.

Useful commands:

```console
$ ollama list                 # installed models
$ ollama ps                   # loaded models and GPU/CPU split
$ ollama pull <model>         # add a model ad hoc
$ ollama rm <model>           # reclaim disk space
$ systemctl status ollama
$ journalctl -u ollama -f
```

### Model store

Models live in `/var/lib/ollama/models` and are large (roughly 2-14 GB each).
`ai.ollama.models` is pulled by `services.ollama.loadModels` after the server
starts; deleting a model from that list does **not** delete it from disk.
`services.ollama.syncModels` would, which is why it is left off.

A fresh install of the current list downloads around 35 GB on first boot.

### One-time migration

`ai.ollama.legacyModelDir` points at the store used by the old Home Manager
service. When set, `ollama-migrate-models.service` moves it to
`/var/lib/ollama/models` (and copies the registry key) before Ollama starts, so
the existing models do not need re-downloading. Once that has happened, remove
the option from the host config.

Models left in the migrated store that are no longer in `ai.ollama.models` stay
on disk. Remove them with `ollama rm <model>` to reclaim space, or add them back
to `ai.ollama.models` and the provider list.

### VRAM

By default Ollama keeps multiple models resident. On a GPU with limited VRAM
this makes models fall back to CPU. The module sets:

- `OLLAMA_MAX_LOADED_MODELS=1`
- `OLLAMA_KEEP_ALIVE=5m`
- `OLLAMA_NUM_PARALLEL=1`

Raise `ai.ollama.maxLoadedModels` only for models that fit together.

## OpenCode

`programs.opencode.settings` is written to
`~/.config/opencode/opencode.json`. The Ollama provider is registered as an
OpenAI-compatible endpoint, with the primary model set by
`ai.opencode.model` (default `ollama/gemma4:latest`) and
`ai.opencode.smallModel` (default `ollama/llama3.2:latest`).

`autoupdate` is disabled: OpenCode is installed from Nix, so upgrading it in
place would only try to write to the Nix store.

### Secrets

If `ai.opencode.web.enable` is turned on, point `ai.opencode.web.environmentFile`
at an environment file containing `OPENCODE_SERVER_PASSWORD`, for example a
sops-nix secret:

```nix
ai.opencode.web = {
  enable = true;
  environmentFile = config.sops.secrets."opencode/server-password".path;
};
```

Add the secret to `secrets/secrets.yaml` with `sops` first. Do not commit the
password or reuse the generated `~/.config/opencode/service.json` value.

### Model capabilities

Models that do not support tool calls must set `tool_call = false` in the
provider entry (Mellum is configured that way). Otherwise OpenCode will send
tool definitions the model cannot handle.

## Packages

Packages come from the pinned nixpkgs in `pins.nix`, not the local
`<nixos-unstable>` channel, so a channel update cannot silently change the
OpenCode/Ollama/Jujutsu versions. Update the pin with:

```console
$ nix-prefetch-url --unpack https://github.com/NixOS/nixpkgs/archive/<rev>.tar.gz
```

then update `rev` and `sha256` in `pins.nix`.

## Checking changes

```console
$ ./check.sh
```

parses every Nix file, evaluates the complete system configuration (which
catches renamed or removed options), and formatting-checks this module.
