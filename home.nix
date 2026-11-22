{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./modules/home/terminal/terminal.nix
    ./modules/home/gaming/gaming.nix
    ./modules/home/music/music.nix
    ./modules/home/opencode
    ./modules/home/ai
    ./modules/home/herdr
    ./modules/home/noctalia/home.nix
    ./modules/home/super-productivity
  ];

  home.username = "timj";
  home.homeDirectory = "/home/timj";

  home.stateVersion = "24.11"; # do not modify with checking upgrade notes

  programs.herdr.enable = true;

  programs.super-productivity = {
    enable = true;
    mcp.enable = true;
  };

  # https://nix-community.github.io/home-manager/index.xhtml#sec-usage-gpu-non-nixos
  #  nixGL.packages = import <nixgl> { inherit pkgs; };
  #  nixGL.defaultWrapper = "mesa";
  #  nixGL.offloadWrapper = "nvidiaPrime";
  #  nixGL.installScripts = [ "mesa" "nvidiaPrime" ];

  home.packages = with pkgs; [
    digikam
    feh
    gcr
    gimp
    jetbrains.idea
    jetbrains.rider
    fuzzel
    libreoffice
    maim
    nemo
    mistral-vibe
    mono
    nixfmt
    nixpkgs-fmt
    obsidian
    qalculate-qt
    secretspec
    swaybg
    unzip
    vlc
    xclip
    xdotool
  ];

  home.preferXdgDirectories = true;

  programs.thunderbird.enable = true;

  home.file = {
    ".gradle/gradle.properties".text = ''
      org.gradle.daemon.idletimeout=3600000
      ssh.auth.sock=/run/user/1000/gnupg/S.gpg-agent.ssh
    '';
    ".config/i3/config".source = ./i3/i3_config;
    ".config/i3status/config".source = ./i3/i3status_config;
  };

  # TODO this isn't applied https://github.com/nix-community/home-manager/issues/3417
  home.sessionPath = [ "$HOME/.local/bin" ];

  home.sessionVariables = {
    KUBECONFIG = "${config.xdg.configHome}/kube/config";
    TERMINAL = "ghostty";
  };

  services.trayscale.enable = true;

  programs.rofi = {
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

  services.gnome-keyring.enable = true;

  programs.firefox = {
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
      # extensions = []; # todo worth revisiting to always bundle prefered password manager bitwarden
    };
    configPath = "${config.xdg.configHome}/mozilla/firefox";
  };

  # todo needs a bit more careful consideration, will consume lots of disk space
  #  services.resilio = {
  #    enable = true;
  #  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
  # explicitly defined list of "unfree" packages to be allowed to be installed

  services.swayidle =
    let
      lock = "${pkgs.swaylock}/bin/swaylock -c 000000 --daemonize";
      display = status: "${pkgs.niri}/bin/niri msg action power-${status}-monitors";
    in
    {
      enable = true;
      timeouts = [
        {
          timeout = 270;
          command = "${pkgs.libnotify}/bin/notify-send 'Locking in 30 seconds' -t 5000";
        }
        {
          timeout = 300;
          command = lock;
        }
      ];
      events = [
        {
          event = "before-sleep";
          command = lock;
        }
        {
          event = "after-resume";
          command = display "on";
        }
        {
          event = "unlock";
          command = display "on";
        }
      ];
    };

  nixpkgs.config.allowUnfreePackages = [
    "obsidian"
    "idea"
    "rider"
    "cuda_cudart"
    "cuda_nvcc"
    "cuda_cccl"
    "libcublas"
    "textual-speedups"
  ];
}
