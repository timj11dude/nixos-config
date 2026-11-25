# AI

Local LLM tooling: a system-wide [Ollama](https://ollama.com) server and
[OpenCode](https://opencode.ai) configured to use it.

The module is split in two, because Ollama is a shared daemon while OpenCode is
a per-user program:

| File | Loaded by | Manages |
| --- | --- | --- |
| `modules/system/ai/default.nix` | `configuration.nix` | `services.ollama`, model pulling |
| `default.nix` | `home.nix` | `programs.opencode`, provider and model config |

## Enable it

The options live in the host configuration:

```nix
ai.enable = true;
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

### State directory fixup

`ollama-fixup-state-dir.service` repairs the state directory left behind by
nixpkgs' `DynamicUser` setup: `/var/lib/ollama` used to be a symlink into the
root-only `/var/lib/private`, which the static `ollama` user cannot traverse
("permission denied: ensure path elements are traversable"). The module pins
`DynamicUser=false`; the fixup moves the real directory back to
`/var/lib/ollama` once and is a no-op afterwards.

### VRAM

The GPU is a 10 GB RTX 3080 that also drives the desktop (~2.5 GiB already in
use), so the server is tuned for a single model at a time with a predictable
context window:

- `OLLAMA_MAX_LOADED_MODELS=1`
- `OLLAMA_KEEP_ALIVE=2m`
- `OLLAMA_NUM_PARALLEL=1`
- `OLLAMA_CONTEXT_LENGTH=16384` (`ai.ollama.contextLength`) — Ollama would
  otherwise pick 4k/32k/256k by itself, and 4k silently truncates prompts
- `OLLAMA_FLASH_ATTENTION=true` (`ai.ollama.flashAttention`)
- `OLLAMA_KV_CACHE_TYPE=q8_0` (`ai.ollama.kvCacheType`) — halves context
  memory versus f16
- `OLLAMA_GPU_OVERHEAD=1GiB` (`ai.ollama.gpuOverheadBytes`) — VRAM reserved
  for the desktop

Raise `ai.ollama.maxLoadedModels` only for models that fit together. OpenCode
is told the same context window through the `limit` field of each model entry,
so its compaction logic works against the real limit.

## OpenCode

`programs.opencode.settings` is written to
`~/.config/opencode/opencode.json`. OpenCode defaults to OpenCode Go
subscription models (`home.opencode.model`, default `opencode-go/kimi-k3.1-pro`,
and `home.opencode.smallModel`, default `opencode-go/qwen3.8-flash`), while the
local Ollama provider remains registered as an OpenAI-compatible endpoint so
local models can be selected on demand.

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
