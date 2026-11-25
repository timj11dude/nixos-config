{
  config,
  pkgs,
  lib,
  pins ? import ../../../pins.nix,
  ...
}:
let
  cfg = config.programs.orca;

  # Append the configured agent CLIs to the wrapper PATH so the desktop app and
  # CLI can spawn them regardless of how they are launched.
  package = cfg.package.override { agentTools = cfg.agents; };
in
{
  options.programs.orca = {
    enable = lib.mkEnableOption "Orca agentic development environment (desktop app and CLI)";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ./package.nix { };
      defaultText = lib.literalExpression "pkgs.callPackage ./package.nix { }";
      description = "Orca package providing the `orca-ide` desktop app and the `orca` CLI.";
    };

    agents = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pins.unstablePkgs; [
        claude-code
        antigravity-cli
        opencode
      ];
      defaultText = lib.literalExpression "with (import ../../../pins.nix).unstablePkgs; [ claude-code antigravity-cli opencode ]";
      description = ''
        Agent CLIs Orca can drive, such as Claude Code (`claude`, via
        stream-json), Antigravity CLI (`agy` >= 1.5.2, via ACP), and OpenCode
        (`opencode`). These power both terminal sessions and Orca's native
        chat/orchestration UI.

        Installed into the user profile for interactive use (sign-in) and
        appended to the Orca wrapper's PATH so the desktop app and CLI can
        spawn them from any environment.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Install `gh` into the user profile alongside the agent CLIs so interactive
    # `gh auth login` works from any shell; it is also in Orca's wrapper PATH.
    home.packages = [
      package
      pkgs.gh
    ]
    ++ cfg.agents;
  };
}
