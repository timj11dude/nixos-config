{
  config,
  pkgs,
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
    stateVersion = "24.11"; # Do not modify without checking upgrade notes.
    preferXdgDirectories = true;

    packages = with pkgs; [
      deadnix
      digikam
      feh
      fuzzel
      gcr
      gimp
      jetbrains.idea
      libreoffice
      maim
      mistral-vibe
      mono
      nemo
      nixfmt
      obsidian
      qalculate-qt
      secretspec
      statix
      swaybg
      unzip
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
    gaming.enable = true;
    music.enable = true;
    niri.enable = true;
    terminal.enable = true;
    zellij.enable = true;
  };

  programs = {
    home-manager.enable = true;
    herdr.enable = false;
    noctalia.enable = true;
    orca.enable = true;
    thunderbird.enable = true;

    super-productivity = {
      enable = true;
      mcp.enable = true;
    };

    rofi = {
      enable = true;
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
      enable = true;
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
    trayscale.enable = true;
    gnome-keyring.enable = true;
  };
}
