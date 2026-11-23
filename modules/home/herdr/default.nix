{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.herdr;
  tomlFormat = pkgs.formats.toml { };
in
{
  options.programs.herdr = {
    enable = lib.mkEnableOption "Herdr client configuration";

    theme = lib.mkOption {
      type = lib.types.str;
      default = "catppuccin";
      description = ''
        Built-in Herdr theme.

        Matched to the rest of the desktop (noctalia/opencode use Catppuccin).
      '';
    };

    shell = lib.mkOption {
      type = lib.types.str;
      default = "zsh";
      description = ''
        Default shell for new Herdr panes.

        Mirrors the user's login shell (zsh), as configured in
        configuration.nix.
      '';
    };

    worktreeDirectory = lib.mkOption {
      type = lib.types.str;
      default = "~/.herdr/worktrees";
      description = ''
        Root directory Herdr uses for Git worktree checkouts created from the
        sidebar.
      '';
    };

    resumeAgents = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Resume supported agent sessions after a Herdr server restart.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile."herdr/config.toml".source = tomlFormat.generate "herdr-config.toml" {
      onboarding = false;

      terminal = {
        default_shell = cfg.shell;
        shell_mode = "login";
        new_cwd = "follow";
      };

      theme = {
        name = cfg.theme;
        auto_switch = false;
      };

      session = {
        resume_agents_on_restore = cfg.resumeAgents;
        startup_per_agent_delay_ms = 100;
      };

      remote = {
        manage_ssh_config = true;
      };

      worktrees = {
        directory = cfg.worktreeDirectory;
      };

      ui.toast = {
        delivery = "herdr";
        delay_seconds = 1;
      };
    };
  };
}
