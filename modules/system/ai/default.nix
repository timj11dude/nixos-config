{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.ai;
  inherit (cfg) ollama;
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
        default = "2m";
        description = ''
          How long a model stays loaded after its last request
          (`OLLAMA_KEEP_ALIVE`). Stops idle models from holding VRAM forever.
          Reduced to 2m to free up VRAM faster for the next task.
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

      contextLength = lib.mkOption {
        type = lib.types.ints.positive;
        default = 16384;
        description = ''
          Default context window in tokens (`OLLAMA_CONTEXT_LENGTH`), used
          whenever a request does not specify one. Left unset, Ollama picks
          4k/32k/256k based on detected VRAM, which is unpredictable on a GPU
          shared with the desktop — and 4k silently truncates coding prompts.

          16k fits a 7B Q4 model plus its q8_0 KV cache in the ~7 GiB of VRAM
          the desktop leaves free. Raise towards 32768 only if nothing else is
          using the GPU.
        '';
      };

      flashAttention = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Enable flash attention (`OLLAMA_FLASH_ATTENTION`). Cuts KV-cache
          VRAM use and speeds up long prompts on RTX-class GPUs; KV-cache
          quantization is only effective together with it.
        '';
      };

      kvCacheType = lib.mkOption {
        type = lib.types.enum [
          "f16"
          "q8_0"
          "q4_0"
        ];
        default = "q8_0";
        description = ''
          KV-cache quantization (`OLLAMA_KV_CACHE_TYPE`). q8_0 halves context
          memory versus f16 with negligible quality loss; q4_0 saves more but
          can degrade quality on long contexts.
        '';
      };

      gpuOverheadBytes = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 1024 * 1024 * 1024;
        description = ''
          VRAM Ollama leaves untouched when scheduling models
          (`OLLAMA_GPU_OVERHEAD`, bytes; 0 disables).

          The desktop (niri, Firefox, Steam) already holds ~2.5 GiB of the
          10 GiB card; reserving 1 GiB keeps model loads from fighting it for
          the last free megabytes.
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
      inherit (ollama) host port;
      openFirewall = ollama.host != "127.0.0.1" && ollama.host != "::1";
      loadModels = ollama.models;
      environmentVariables = {
        OLLAMA_KEEP_ALIVE = ollama.keepAlive;
        OLLAMA_MAX_LOADED_MODELS = toString ollama.maxLoadedModels;
        # One request at a time: parallelism splits the context window and
        # multiplies KV-cache memory, neither of which this GPU can spare.
        OLLAMA_NUM_PARALLEL = "1";
        OLLAMA_CONTEXT_LENGTH = toString ollama.contextLength;
        OLLAMA_FLASH_ATTENTION = lib.boolToString ollama.flashAttention;
        OLLAMA_KV_CACHE_TYPE = ollama.kvCacheType;
      }
      // lib.optionalAttrs (ollama.gpuOverheadBytes > 0) {
        OLLAMA_GPU_OVERHEAD = toString ollama.gpuOverheadBytes;
      };
    };

    systemd.services = {
      ollama.serviceConfig = lib.mkIf ollama.enable {
        # The nixpkgs module runs the service with systemd DynamicUser, which
        # stores the state directory under /var/lib/private (0700, root-owned).
        # Combined with the static `ollama` user that path is not traversable
        # and the server refuses to start ("mkdir /var/lib/ollama/models/blobs:
        # permission denied: ensure path elements are traversable").
        DynamicUser = lib.mkForce false;

        # The module only adds a restart policy to the model loader, not the
        # server itself; a crash currently leaves Ollama down until the next
        # boot.
        Restart = "on-failure";
        RestartSec = "5s";
      };

      # One-time relocation of the state directory created while the service
      # ran with DynamicUser: /var/lib/ollama is a symlink into the
      # root-only /var/lib/private. Runs as root before Ollama starts; the
      # condition makes it a no-op once the directory has been relocated.
      ollama-fixup-state-dir = lib.mkIf ollama.enable {
        description = "Relocate the Ollama state directory out of /var/lib/private";
        wantedBy = [ "multi-user.target" ];
        before = [ "ollama.service" ];
        unitConfig.ConditionPathIsSymbolicLink = "/var/lib/ollama";
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "ollama-fixup-state-dir" ''
            set -eu
            target=$(readlink /var/lib/ollama)
            case "$target" in
              private/ollama | /var/lib/private/ollama)
                rm /var/lib/ollama
                mv /var/lib/private/ollama /var/lib/ollama
                chown -R ollama:ollama /var/lib/ollama
                ;;
              *)
                echo "/var/lib/ollama points at $target, leaving it alone"
                ;;
            esac
          '';
        };
      };
    };
  };
}
