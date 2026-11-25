{
  config,
  lib,
  osConfig ? { },
  pins ? import ../../../pins.nix,
  ...
}:
let
  pkgs = pins.unstablePkgs;

  cfg = config.home.opencode;
  ollamaHost = osConfig.ai.ollama.host or "127.0.0.1";
  ollamaPort = osConfig.ai.ollama.port or 11434;

  # The plugin is published to npm but not packaged in nixpkgs. Build it from
  # the pinned tarball so the whole setup stays reproducible and offline.
  quotaVersion = "6.3.0";
  quotaPackage = pkgs.buildNpmPackage {
    pname = "opencode-quota";
    version = quotaVersion;

    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/@slkiser/opencode-quota/-/opencode-quota-${quotaVersion}.tgz";
      hash = "sha256-jFzIYy7PAqG4GrlR+r0/bGuzKB4/r84ri/RUK2F9S9Y=";
    };

    # The published tarball has no lockfile. The checked-in lockfile pins only
    # the two runtime dependencies; peer dependencies come from OpenCode.
    # The replacement manifest must keep the published `exports`/`main` fields:
    # OpenCode discovers the plugin's parts (server, TUI, GUI) through them.
    postPatch = ''
      cat > package.json <<'EOF'
      {
        "name": "@slkiser/opencode-quota",
        "version": "${quotaVersion}",
        "type": "module",
        "main": "./dist/index.js",
        "types": "./dist/index.d.ts",
        "bin": {
          "opencode-quota": "./dist/bin/opencode-quota.js"
        },
        "exports": {
          ".": {
            "types": "./dist/index.d.ts",
            "default": "./dist/index.js"
          },
          "./server": {
            "types": "./dist/index.d.ts",
            "default": "./dist/index.js"
          },
          "./tui": {
            "types": "./dist/tui.d.ts",
            "default": "./dist/tui.js"
          },
          "./gui-experimental": "./dist/gui-experimental.cjs"
        },
        "files": [
          "dist",
          "README.md",
          "LICENSE"
        ],
        "dependencies": {
          "@opentelemetry/api": "~1.9.1",
          "jsonc-parser": "^3.3.1"
        }
      }
      EOF
      cp ${./opencode-quota-package-lock.json} package-lock.json
    '';

    npmDepsHash = "sha256-mTsf8EA6TNaC0qpqwv37RgH6FN4lVtcCtRUlTMQXj6Y=";
    dontNpmBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/node_modules/@slkiser/opencode-quota
      cp -r . $out/lib/node_modules/@slkiser/opencode-quota/
      cp ${quotaIndexShim} $out/lib/node_modules/@slkiser/opencode-quota/index.js
      cp ${quotaTuiShim} $out/lib/node_modules/@slkiser/opencode-quota/tui.js
      runHook postInstall
    '';

    meta = with lib; {
      description = "Quota, usage and cost in the OpenCode TUI";
      homepage = "https://github.com/slkiser/opencode-quota";
      license = licenses.mit;
      platforms = platforms.all;
    };
  };

  # OpenCode 2.1.x discovers the parts of a local plugin directory only by
  # conventional root file names (server/index, tui, rpc) and does not read
  # package.json exports (newer releases do). Root shims keep the plugin
  # loadable as a bare store path on both.
  quotaIndexShim = pkgs.writeText "opencode-quota-index.js" ''
    export * from "./dist/index.js";
    export { default } from "./dist/index.js";
  '';
  quotaTuiShim = pkgs.writeText "opencode-quota-tui.js" ''
    export { default } from "./dist/tui.js";
  '';

  jsonFormat = pkgs.formats.json { };
in
{
  options.home.opencode = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable OpenCode, defaulting to OpenCode Go models with local Ollama models also configured.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pins.unstablePkgs.opencode;
      defaultText = lib.literalExpression "pins.unstablePkgs.opencode";
      description = "OpenCode package to install.";
    };

    model = lib.mkOption {
      type = lib.types.str;
      default = "opencode-go/kimi-k3.1-pro";
      description = "Primary model, in OpenCode's provider/model form.";
    };

    smallModel = lib.mkOption {
      type = lib.types.str;
      default = "opencode-go/qwen3.8-flash";
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

    # opencode-quota integration lives in this module, alongside OpenCode.
    quota = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable the opencode-quota plugin for quota and usage tracking.";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = quotaPackage;
        defaultText = lib.literalExpression "the pinned @slkiser/opencode-quota npm package";
        description = "The built opencode-quota plugin package.";
      };

      settings = lib.mkOption {
        inherit (jsonFormat) type;
        default = { };
        description = ''
          Settings written to opencode-quota/settings.jsonc in OpenCode's
          config directory. See the plugin's configuration documentation.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.opencode = {
      enable = true;
      inherit (cfg) package extraPackages;
      enableMcpIntegration = true;

      settings = {
        # The package is managed by Nix; update checks would only suggest
        # `opencode upgrade`, which cannot write to the store.
        autoupdate = false;
        inherit (cfg) model;
        small_model = cfg.smallModel;

        plugins = lib.optional cfg.quota.enable "${cfg.quota.package}/lib/node_modules/@slkiser/opencode-quota";

        provider.ollama = {
          npm = "@ai-sdk/openai-compatible";
          name = "Ollama (local)";
          options = {
            baseURL = "http://${ollamaHost}:${toString ollamaPort}/v1";
            chunkTimeout = 60000;
          };
          inherit (config.ai) models;
        };

        permissions = [
          "question"
          "webfetch"
        ];
        lsp = true;
        agents.ask = {
          description = "Read-only research and Q&A. Never modifies files.";
          mode = "primary";
          color = "#51cf66";
          system = ''
            You are in ask mode. Answer questions and research topics using the codebase and the web.
            Never edit, create, or delete files. Cite file paths and line numbers or URLs for your claims.
            If a change is needed, describe it instead of making it.
          '';
          permissions = [
            {
              action = "*";
              resource = "*";
              effect = "deny";
            }
            {
              action = "read";
              resource = "*";
              effect = "allow";
            }
            {
              action = "glob";
              resource = "*";
              effect = "allow";
            }
            {
              action = "grep";
              resource = "*";
              effect = "allow";
            }
            {
              action = "webfetch";
              resource = "*";
              effect = "allow";
            }
            {
              action = "websearch";
              resource = "*";
              effect = "allow";
            }
            {
              action = "shell";
              resource = "*";
              effect = "ask";
            }
          ];
        };
      };

      tui = {
        theme = "system";
      };

      web = {
        enable = cfg.web.enable;
        environmentFile = cfg.web.environmentFile;
      };
    };

    xdg.configFile = lib.mkIf (cfg.quota.enable && cfg.quota.settings != { }) {
      "opencode/opencode-quota/settings.jsonc" = {
        source = jsonFormat.generate "opencode-quota-settings.jsonc" cfg.quota.settings;
      };
    };
  };
}
