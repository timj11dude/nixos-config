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

  programs.vim = {
    enable = true;
    defaultEditor = true;
  };

  programs.git = {
    enable = true;
    userName = "Timothy Jacobson";
    userEmail = "tim@jaconet.uk";
    aliases = {
      st = "status";
      ll = "log --decorate --graph";
    };
    attributes = [
      "package-lock.json binary"
      "yarn.lock binary"
      "pnpm-lock.yaml binary"
      "gradle.lockfile binary"
    ];
    signing = {
      key = "5CCFF11F4D012DE2";
      signByDefault = true;
    };
    extraConfig = {
      format = {
        pretty = "format:%C(auto,yellow)%h%C(auto,magenta)% G? %C(auto,blue)%>(12,trunc)%ad %C(auto,green)%<(7,trunc)%aN%C(auto,reset)%s%C(auto,red)% gD% D";
      };
      core = {
        autocrlf = "input";
        editor = "vim";
        excludesfile = "${./git/excludesFile}";
      };
      diff = {
        submodule = "log";
      };
      status = {
        submoduleSummary = true;
      };
      init = {
        defaultBranch = "main";
      };
    };
  };

  programs.gpg = {
    enable = true;
    homedir = "${config.xdg.dataHome}/gnupg"; # instead of default ~/.gnupg
    settings = {
      personal-digest-preferences = "SHA512 SHA384 SHA256 SHA224";
      default-preference-list = "SHA512 SHA384 SHA256 SHA224 AES256 AES192 AES CAST5 BZIP2 ZLIB ZIP Uncompressed";
      cert-digest-algo = "SHA512";
    };
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
