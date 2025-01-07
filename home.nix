{ config, pkgs, lib, ... }:
{
  home.username = "timj";
  home.homeDirectory = "/home/timj";

  home.stateVersion = "24.11"; # Please read the comment before changing.

  home.packages = with pkgs; [
    jetbrains.idea-community # todo investigate best means to customize
    nixpkgs-fmt
    btop
    obsidian
  ];

  home.file = {
    ".zshenv" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/home-manager/zsh/.zshenv";
    };
    ".gradle/gradle.properties".text = ''
      org.gradle.daemon.idletimeout=3600000
    '';
  };

  home.sessionVariables = { };

  services.gpg-agent = {
    enable = true;
    enableExtraSocket = true;
    defaultCacheTtl = 1800;
    maxCacheTtl = 7200;
    enableSshSupport = true;
    enableZshIntegration = true;
    grabKeyboardAndMouse = true;
    sshKeys = [
      "BF3EDDD040FDF9435FD5F9B24577FB832C6B0E49" # source via `gpg --list-secret-keys --with-keygrip timj91@gmail.com`
    ];
  };

  programs.ssh = {
    enable = true;
    compression = true;
    controlMaster = "auto";
    controlPath = "/tmp/%u:%r@%h:%p";
    controlPersist = "2m";
    forwardAgent = true;
    serverAliveCountMax = 6;
    serverAliveInterval = 15;
    extraConfig = ''
        Ciphers aes128-gcm@openssh.com,aes256-gcm@openssh.com,chacha20-poly1305@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
        TCPKeepAlive yes
    '';
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

  # todo needs a bit more careful consideration, will consume lots of disk space
  #  services.resilio = {
  #    enable = true;
  #  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
  # explicitly defined list of "unfree" packages to be allowed to be installed
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "obsidian"
  ];
}
