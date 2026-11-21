{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  pins = import ../../../pins.nix;

  cfg = config.home.opencode;
in
{
  options.home.opencode = lib.mkIf cfg.enable {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable OpenCode.";
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
      default = [];
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

    # opencode-quota plugin configuration
    quota = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable OpenCode opencode-quota plugin for quota/usage tracking.";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pins.unstablePkgs["@slkiser/opencode-quota"];
        defaultText = lib.literalExpression "pins.unstablePkgs['@slkiser/opencode-quota']";
        description = "OpenCode opencode-quota plugin package.";
      };

      settings = lib.mkOption {
        type = lib.types.attrs;
        default = {};
        description = "OpenCode opencode-quota plugin settings.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.opencode = {
      enable = true;
      inherit (cfg) package extraPackages;

      # Configure opencode-quota plugin if enabled
      settings = let
        baseSettings = {
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
            inherit cfg.models;
          };
          permissions = [
            "question"
            "webfetch"
          ];
          lsp = true;
        };

        quotaSettings = if cfg.quota.enable && cfg.quota.package then
          # Merge quota plugin settings
          {
            # The @slkiser/opencode-quota plugin is auto-loaded when installed
            # Plugin discovers itself via the package installation
          }
        else
          {};

        merged = lib.mkMerge baseSettings quotaSettings;
      in
      merged;

      tui = {
        theme = "system";
      };

      web = {
        enable = cfg.web.enable;
        environmentFile = cfg.web.environmentFile;
      };
    };
  };
