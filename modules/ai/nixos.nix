{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.ai;
  ollama = cfg.ollama;
in
{
  options.ai = {
    enable = lib.mkEnableOption "local AI tooling";

    ollama = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable the system-wide Ollama server.";
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = ''
          Address the Ollama API listens on.

          Keep this on loopback unless the port is protected by something else:
          Ollama has no built-in authentication.
        '';
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 11434;
        description = "Port the Ollama API listens on.";
      };

      models = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "gemma4:latest"
          "llama3.2:latest"
          "qwen2.5-coder:7b"
          "devstral:latest"
          "JetBrains/Mellum-4b-base:latest"
        ];
        description = ''
          Models pulled automatically after the server starts.

          Omitting a model here does not remove it from disk (unless
          `services.ollama.syncModels` is enabled); use `ollama rm` for that.
        '';
      };

      keepAlive = lib.mkOption {
        type = lib.types.str;
        default = "5m";
        description = ''
          How long a model stays loaded after its last request
          (`OLLAMA_KEEP_ALIVE`). Stops idle models from holding VRAM forever.
        '';
      };

      contextLength = lib.mkOption {
        type = lib.types.ints.positive;
        default = 32768;
        description = ''
          Default context window, in tokens, for every loaded model
          (`OLLAMA_CONTEXT_LENGTH`).

          Ollama otherwise auto-picks a tiny window (as low as 4096 tokens
          below 23 GiB of VRAM), which OpenCode's system prompt and tool
          definitions can fill on their own, causing the model to echo them
          back instead of answering. OpenCode's own docs recommend 64k+.
          Larger values need more VRAM for the KV cache, so lower this if a
          model starts spilling onto CPU or failing to load.
        '';
      };

      maxLoadedModels = lib.mkOption {
        type = lib.types.ints.positive;
        default = 1;
        description = ''
          Number of models kept in memory at once (`OLLAMA_MAX_LOADED_MODELS`).

          On a 10 GB GPU a single large model can already fill VRAM, so keeping
          more than one resident causes CPU/GPU split inference.
        '';
      };

      legacyModelDir = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "/home/timj/.ollama/models";
        description = ''
          One-time migration source for models previously stored by the
          Home Manager Ollama service.

          If set and the directory exists, it is moved to the system model
          store (`/var/lib/ollama/models`) before Ollama starts. Remove this
          option once the migration has happened.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.ollama = lib.mkIf ollama.enable {
      enable = true;
      package = pkgs.ollama-cuda;
      user = "ollama";
      group = "ollama";
      home = "/var/lib/ollama";
      host = ollama.host;
      port = ollama.port;
      openFirewall = ollama.host != "127.0.0.1" && ollama.host != "::1";
      loadModels = ollama.models;
      environmentVariables = {
        OLLAMA_KEEP_ALIVE = ollama.keepAlive;
        OLLAMA_MAX_LOADED_MODELS = toString ollama.maxLoadedModels;
        OLLAMA_NUM_PARALLEL = "1";
        OLLAMA_CONTEXT_LENGTH = toString ollama.contextLength;
      };
    };

    # The module only adds a restart policy to the model loader, not the
    # server itself; a crash currently leaves Ollama down until the next boot.
    systemd.services.ollama.serviceConfig = lib.mkIf ollama.enable {
      Restart = "on-failure";
      RestartSec = "5s";
    };

    # The old Home Manager module ran Ollama as a user service and kept its
    # models in ~/.ollama. Move that store instead of re-downloading it.
    systemd.services.ollama-migrate-models = lib.mkIf (ollama.enable && ollama.legacyModelDir != null) {
      description = "Move the legacy per-user Ollama model store";
      wantedBy = [ "multi-user.target" ];
      before = [ "ollama.service" ];
      unitConfig.ConditionPathExists = ollama.legacyModelDir;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "ollama-migrate-models" ''
          set -eu
          legacy=${lib.escapeShellArg ollama.legacyModelDir}
          legacyHome=$(dirname "$legacy")

          install -d -o ollama -g ollama /var/lib/ollama
          if [ ! -e /var/lib/ollama/models ]; then
            mv "$legacy" /var/lib/ollama/models
          fi
          if [ -f "$legacyHome/id_ed25519" ] && [ ! -e /var/lib/ollama/.ollama/id_ed25519 ]; then
            install -D -o ollama -g ollama "$legacyHome/id_ed25519" /var/lib/ollama/.ollama/id_ed25519
          fi
          chown -R ollama:ollama /var/lib/ollama
        '';
      };
    };
  };
}
