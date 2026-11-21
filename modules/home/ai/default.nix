{
  config,
  lib,
  osConfig,
  ...
}:
let
  cfg = config.ai.opencode;
  pins = import ../../../pins.nix;

  # Only models that the local Ollama server actually serves. Keep this in
  # sync with ai.ollama.models in the system module.
  models = {
    "gemma4:latest" = {
      name = "Gemma 4";
    };
    "llama3.2:latest" = {
      name = "Llama 3.2 (3.2B)";
    };
    "qwen2.5-coder:7b" = {
      name = "Qwen 2.5 Coder (7B)";
    };
    "devstral:latest" = {
      name = "Devstral (23.6B, coding)";
    };
    "JetBrains/Mellum-4b-base:latest" = {
      name = "Mellum 4B (base)";
      tool_call = false;
    };
  };
in
{
  options.ai.opencode = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable OpenCode configured against the local Ollama server.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pins.unstablePkgs.opencode;
      defaultText = lib.literalExpression "pins.unstablePkgs.opencode";
      description = "OpenCode package to install.";
    };

    model = lib.mkOption {
      type = lib.types.str;
      default = "ollama/gemma4:latest";
      description = "Primary model, in OpenCode's provider/model form.";
    };

    smallModel = lib.mkOption {
      type = lib.types.str;
      default = "ollama/llama3.2:latest";
      description = "Model used for lightweight tasks such as title generation.";
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Extra packages made available to OpenCode.";
    };

    web = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Run OpenCode's web/server service.";
      };

      environmentFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        example = "/run/secrets/opencode-web";
        description = ''
          Environment file for the web service, for example a sops secret
          containing `OPENCODE_SERVER_PASSWORD`. Do not put the password in
          the Nix store.
        '';
      };
    };
  };

  config = lib.mkIf (cfg.enable && (osConfig.ai.enable or true)) {
    programs.opencode = {
      enable = true;
      inherit (cfg) package extraPackages;
      enableMcpIntegration = true;

      settings = {
        # The package is managed by Nix; update checks would only suggest
        # `opencode upgrade`, which cannot write to the store.
        autoupdate = false;
        model = cfg.model;
        small_model = cfg.smallModel;
        provider.ollama = {
          npm = "@ai-sdk/openai-compatible";
          name = "Ollama (local)";
          options = {
            baseURL = "http://127.0.0.1:11434/v1";
            chunkTimeout = 60000;
          };
          inherit models;
        };
        permissions = [
          "question"
          "webfetch"
        ];
        lsp = true;
      };

      tui = {
        theme = "system";
      };

      web = {
        enable = cfg.web.enable;
        environmentFile = cfg.web.environmentFile;
      };
    };
  };
}
