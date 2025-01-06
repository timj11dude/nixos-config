{ config, pkgs, ... }:

{
  home.username = "timj";
  home.homeDirectory = "/home/timj";

  home.stateVersion = "24.11"; # Please read the comment before changing.

  home.packages = with pkgs; [
    jetbrains.idea-community
  ];

  home.file = {
    ".zshenv" = {
        source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/home-manager/zsh/.zshenv";
    };
     ".gradle/gradle.properties".text = ''
       org.gradle.daemon.idletimeout=3600000
     '';
  };

  home.sessionVariables = {
  };

  services.gpg-agent = {
    enable = true;
    enableExtraSocket = true;
    defaultCacheTtl = 1800;
    maxCacheTtl = 7200;
    enableSshSupport = true;
    enableZshIntegration = true;
    grabKeyboardAndMouse = true;
    sshKeys = [
        "E47EDB26E9735B2ED80FBF11B440016A5D6130C0" # Personal
    ];
  };

  programs.firefox = {
    enable = true;
    profiles.timj = {

    };
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
