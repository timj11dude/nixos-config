{
  config,
  pkgs,
  lib,
  osConfig ? { },
  ...
}:
{
  imports = [
    ./modules/home/ai
    ./modules/home/gaming
    ./modules/home/herdr
    ./modules/home/music
    ./modules/home/niri
    ./modules/home/noctalia
    ./modules/home/opencode
    ./modules/home/orca
    ./modules/home/super-productivity
    ./modules/home/terminal
    ./modules/home/work
    ./modules/home/zellij
  ];

  home = {
    username = "timj";
    homeDirectory = "/home/timj";
    stateVersion = lib.mkDefault "24.11"; # Do not modify without checking upgrade notes.
    preferXdgDirectories = true;

    packages = with pkgs; [
      digikam
      feh
      fuzzel
      gcr_4
      gimp
      jetbrains.idea
      libreoffice
      maim
      mono
      nemo
      obsidian
      qalculate-qt
      swaybg
      vlc
      xclip
      xdotool
    ];

    file.".gradle/gradle.properties".text = ''
      org.gradle.daemon.idletimeout=3600000
      ssh.auth.sock=/run/user/1000/gnupg/S.gpg-agent.ssh
    '';

    # TODO: verify whether this is applied (https://github.com/nix-community/home-manager/issues/3417)
    sessionPath = [ "$HOME/.local/bin" ];

    sessionVariables = {
      KUBECONFIG = "${config.xdg.configHome}/kube/config";
      TERMINAL = "ghostty";
    };
  };

  xdg.configFile = {
    "i3/config".source = ./i3/i3_config;
    "i3status/config".source = ./i3/i3status_config;
  };

  # Opt-in Home Manager feature modules
  my = {
    gaming.enable = lib.mkDefault (osConfig.gaming.enable or false);
    music.enable = lib.mkDefault true;
    niri.enable = lib.mkDefault (osConfig.programs.niri.enable or false);
    terminal.enable = lib.mkDefault true;
    zellij.enable = lib.mkDefault true;
  };

  programs = {
    home-manager.enable = lib.mkDefault true;
    herdr.enable = lib.mkDefault false;
    noctalia.enable = lib.mkDefault (osConfig.programs.noctalia.enable or false);
    orca.enable = lib.mkDefault true;
    thunderbird.enable = lib.mkDefault true;

    super-productivity = {
      enable = lib.mkDefault true;
      mcp.enable = lib.mkDefault true;
    };

    rofi = {
      enable = lib.mkDefault true;
      extraConfig = {
        modi = "drun,emoji,ssh";
      };
      plugins = with pkgs; [
        rofi-calc
        rofi-emoji
      ];
      theme = "arthur";
    };

    firefox = {
      enable = lib.mkDefault true;
      languagePacks = [ "en-GB" ];
      profiles.timj = {
        containers = {
          personal = {
            name = "Personal";
            color = "blue";
            icon = "fingerprint";
            id = 1;
          };
        };
        containersForce = true;
      };
      configPath = "${config.xdg.configHome}/mozilla/firefox";
    };
  };

  services = {
    trayscale.enable = lib.mkDefault true;
    gnome-keyring.enable = lib.mkDefault true;
  };
}
