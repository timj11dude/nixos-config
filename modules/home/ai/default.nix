{
  config,
  lib,
  osConfig,
  ...
}:
let
  pins = import ../../../pins.nix;

  cfg = config.ai;
in
{
  options.ai = {
    ollama = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Ollama AI provider.";
    };

    models = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "ollama/gemma4:latest"
        "ollama/llama3.2:latest"
      ];
      description = "Available Ollama models.";
    };

    smallModel = lib.mkOption {
      type = lib.types.str;
      default = "ollama/llama3.2:latest";
      description = "Model used for lightweight tasks such as title generation.";
    };

    web = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Run AI web service.";
      };

      environmentFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        example = "/run/secrets/ai-web";
        description = ''
          Environment file for the web service.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # AI-specific configuration goes here
  };
}
