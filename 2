{ config, pkgs, lib, ... }:

let
  rev = "v5.4.1";
  noctalia-src = builtins.fetchTarball {
    url = "https://github.com/noctalia-dev/noctalia/archive/refs/tags/${rev}.tar.gz";
    sha256 = "0ih3aizacgi1v5b5qq907p3j6vsx0wjvnf9hc9gqwasb1dqir8cg";
  };
in
{
  imports = [
    # Noctalia's own Home Manager module (disables home-manager's builtin one).
    (noctalia-src + "/nix/home-module.nix")
  ];

  programs.noctalia = {
    enable = true;
    # The package is installed system-wide by the NixOS module, so it is left
    # null here to avoid duplicating it in home.packages.
    settings = {
      shell = {
        font = "JetBrainsMono Nerd Font";
        settings_show_advanced = true;
      };
      theme = {
        mode = "dark";
        source = "builtin";
        builtin = "Catppuccin";
      };
      # Keep apps launched by Noctalia alive when the systemd user service
      # restarts (recommended when programs.noctalia.systemd.enable is true).
      launch_apps_as_systemd_services = true;
    };
  };
}
