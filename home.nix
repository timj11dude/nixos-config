{
  config,
  osConfig,
  pkgs,
  lib,
  ...
}:
let
  unstablePkgs = import <nixos-unstable> { inherit pkgs; };
in {

  imports = [
    ./modules/terminal/terminal.nix
    ./modules/gaming/gaming.nix
  ];

  home.username = "timj";
  home.homeDirectory = "/home/timj";

  home.stateVersion = "24.11"; # do not modify with checking upgrade notes

  # https://nix-community.github.io/home-manager/index.xhtml#sec-usage-gpu-non-nixos
  #  nixGL.packages = import <nixgl> { inherit pkgs; };
  #  nixGL.defaultWrapper = "mesa";
  #  nixGL.offloadWrapper = "nvidiaPrime";
  #  nixGL.installScripts = [ "mesa" "nvidiaPrime" ];

  home.packages = with pkgs; [
    jetbrains.idea-ultimate
    nixpkgs-fmt
    obsidian
    discord
    barrier
    xclip
    maim
    xdotool
    qalculate-qt
    nixfmt-rfc-style
    davinci-resolve
    libreoffice
    digikam
    gimp
    vlc
    unzip
    clockify
  ];

  home.preferXdgDirectories = true;

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
      rofi-emoji
      rofi-calc
    ];
  };

  #todo need to add configuration to change audio driver used
  programs.spotify-player = {
    enable = true;
    #    package = (pkgs.spotify-player.override { withAudioBackend = "pulseaudio"; });
  };

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
        work = {
          name = "Work";
          color = "orange";
          icon = "briefcase";
          id = 2;
        };
      };
      containersForce = true;
      # extensions = []; # todo worth revisiting to always bundle prefered password manager bitwarden
    };
  };

  # not available to configure via home-manager in stable nixpkgs 24.11
  #nixpkgs.config.cudaSupport = true;
  #
  #services.ollama = {
  #  enable = true;
  #  acceleration = "cuda";
  #  environmentVariables = {
  #    OLLAMA_MODELS = "/mnt/corsair_1tb/ollama";
  #  };
  #};

  # todo needs a bit more careful consideration, will consume lots of disk space
  #  services.resilio = {
  #    enable = true;
  #  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
  # explicitly defined list of "unfree" packages to be allowed to be installed
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "obsidian"
      "discord"
      "davinci-resolve"
      "idea-ultimate"
      "wowup-cf"
      "clockify"
    ];
}
