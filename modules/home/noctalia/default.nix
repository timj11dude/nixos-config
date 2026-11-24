{
  config,
  pkgs,
  lib,
  pins ? import ../../../pins.nix,
  ...
}:
{
  imports = [
    # Noctalia's own Home Manager module (disables home-manager's builtin one).
    (pins.noctalia.src + "/nix/home-module.nix")
  ];

  config = lib.mkIf config.programs.noctalia.enable {
    # The package is installed system-wide by the NixOS module, so it is left
    # null here to avoid duplicating it in home.packages.
    programs.noctalia.settings = {
      shell = {
        font_family = lib.mkDefault "JetBrainsMono Nerd Font";
        settings_show_advanced = lib.mkDefault true;
        # Keep apps launched by Noctalia alive when the systemd user service
        # restarts (recommended when programs.noctalia.systemd.enable is true).
        launch_apps_as_systemd_services = lib.mkDefault true;
      };
      theme = {
        mode = lib.mkDefault "dark";
        source = lib.mkDefault "builtin";
        builtin = lib.mkDefault "Catppuccin";
      };
      lockscreen = {
        enabled = lib.mkDefault true;
        lock_before_suspend = lib.mkDefault true;
      };
      idle = {
        # Disable the pre-action fullscreen dim overlay so the 30-second
        # warning notification does not dim the screen before locking.
        pre_action_fade_seconds = lib.mkDefault 0;
        behavior_order = lib.mkDefault [
          "lock-warning"
          "lock"
          "screen-off"
        ];
        behavior = {
          lock-warning = {
            enabled = lib.mkDefault true;
            timeout = lib.mkDefault 270;
            action = lib.mkDefault "command";
            command = lib.mkDefault "${pkgs.libnotify}/bin/notify-send 'Locking in 30 seconds' -t 5000";
          };
          lock = {
            enabled = lib.mkDefault true;
            timeout = lib.mkDefault 300;
            action = lib.mkDefault "lock";
          };
          screen-off = {
            enabled = lib.mkDefault true;
            timeout = lib.mkDefault 330;
            locked_timeout = lib.mkDefault 30;
            action = lib.mkDefault "screen_off";
          };
        };
      };
    };
  };
}
