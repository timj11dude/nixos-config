{
  config,
  pkgs,
  lib,
  ...
}:
let
  # room is not packaged in nixpkgs; pin the upstream wasm release.
  # Update with:
  #   nix-prefetch-url https://github.com/rvcas/room/releases/download/v<version>/room.wasm
  roomVersion = "1.2.1";
  roomPlugin = pkgs.stdenvNoCC.mkDerivation {
    pname = "zellij-room";
    version = roomVersion;
    src = pkgs.fetchurl {
      url = "https://github.com/rvcas/room/releases/download/v${roomVersion}/room.wasm";
      hash = "sha256-kLSDpAt2JGj7dYYhYFh6BfvtzVwTrcs+0jHwG/nActE=";
    };
    dontUnpack = true;
    installPhase = ''
      runHook preInstall
      cp $src $out
      runHook postInstall
    '';
  };
in
{
  # provides wl-copy for zellij's copy_command
  home.packages = [ pkgs.wl-clipboard ];

  # Plugin wasms at stable config paths. Can be replaced with
  # `programs.zellij.plugins` once the home-manager pin gains that option.
  xdg.configFile = {
    "zellij/plugins/zjstatus.wasm".source = pkgs.zellijPlugins.zjstatus;
    "zellij/plugins/room.wasm".source = roomPlugin;
  };

  programs.zellij = {
    enable = true;

    # Auto-start a new zellij session in every interactive zsh.
    enableZshIntegration = true;

    settings = {
      theme = "catppuccin-mocha";
      default_shell = "zsh";
      default_layout = "ai";
      mouse_mode = true;
      copy_command = "wl-copy";
      session_serialization = true;

      # Plugin aliases, usable as locations in layouts and keybinds.
      # The wasms are symlinked to stable ~/.config/zellij/plugins/ paths
      # (see xdg.configFile below) so plugin updates don't change the path
      # and re-trigger zellij's permission prompt.
      plugins = {
        zjstatus._props.location = "file:${config.xdg.configHome}/zellij/plugins/zjstatus.wasm";
        room._props.location = "file:${config.xdg.configHome}/zellij/plugins/room.wasm";
      };
    };

    # opencode/AI-centric default layout with a zjstatus top bar
    # (Catppuccin Mocha palette).
    layouts.ai = ''
      layout {
          default_tab_template {
              pane size=1 borderless=true {
                  plugin location="zjstatus" {
                      format_left   "{mode} #[fg=#89B4FA,bold]{session}"
                      format_center "{tabs}"
                      format_right  "#[fg=#A6E3A1]{datetime}"
                      format_space  ""

                      border_enabled "false"
                      hide_frame_for_single_pane "true"

                      mode_normal  "#[bg=#A6E3A1,fg=#1E1E2E,bold] NORMAL"
                      mode_locked  "#[bg=#F38BA8,fg=#1E1E2E,bold] LOCKED"
                      mode_pane    "#[bg=#89B4FA,fg=#1E1E2E,bold] PANE"
                      mode_tab     "#[bg=#CBA6F7,fg=#1E1E2E,bold] TAB"
                      mode_resize  "#[bg=#FAB387,fg=#1E1E2E,bold] RESIZE"
                      mode_scroll  "#[bg=#F9E2AF,fg=#1E1E2E,bold] SCROLL"
                      mode_search  "#[bg=#F9E2AF,fg=#1E1E2E,bold] SEARCH"
                      mode_session "#[bg=#94E2D5,fg=#1E1E2E,bold] SESSION"
                      mode_move    "#[bg=#F5C2E7,fg=#1E1E2E,bold] MOVE"

                      tab_normal    "#[fg=#6C7086] {index} {name} "
                      tab_active    "#[fg=#89B4FA,bold] {index} {name} "
                      tab_separator "#[fg=#45475A] | "

                      datetime          "{format}"
                      datetime_format   "%H:%M"
                      datetime_timezone "Europe/London"
                  }
              }
              children
          }
          tab name="ai" focus=true {
              pane split_direction="vertical" {
                  pane name="opencode" size="65%" {
                      command "opencode"
                  }
                  pane split_direction="horizontal" size="35%" {
                      pane name="shell"
                      pane name="git" size="40%"
                  }
              }
          }
      }
    '';

    # Session picker (room plugin) on Alt r.
    extraConfig = ''
      keybinds {
          shared_except "locked" {
              bind "Alt r" {
                  LaunchOrFocusPlugin "room" {
                      floating true
                  }
              }
          }
      }
    '';
  };
}
