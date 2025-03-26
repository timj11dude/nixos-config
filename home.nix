{
  config,
  pkgs,
  lib,
  ...
}:
{
  home.username = "timj";
  home.homeDirectory = "/home/timj";

  home.stateVersion = "24.11"; # Please read the comment before changing.

  # https://nix-community.github.io/home-manager/index.xhtml#sec-usage-gpu-non-nixos
  #  nixGL.packages = import <nixgl> { inherit pkgs; };
  #  nixGL.defaultWrapper = "mesa";
  #  nixGL.offloadWrapper = "nvidiaPrime";
  #  nixGL.installScripts = [ "mesa" "nvidiaPrime" ];

  home.packages = with pkgs; [
    jetbrains.idea-community # todo investigate best means to customize
    nixpkgs-fmt
    obsidian
    discord
    barrier
    eza
    xclip
    maim
    xdotool
    qalculate-qt
    (lutris-free.override {
      extraLibraries = pkgs: [
        qt5.full
      ];
      extraPkgs = pkgs: [
        jdk
      ];
    })
  ];

  home.preferXdgDirectories = true;

  home.file = {
    #    ".zshenv" = {
    #      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/home-manager/zsh/.zshenv";
    #    };
    ".gradle/gradle.properties".text = ''
      org.gradle.daemon.idletimeout=3600000
      ssh.auth.sock=/run/user/1000/gnupg/S.gpg-agent.ssh
    '';
    "${config.xdg.dataHome}/gnupg/pinentry.sh" = {
      executable = true;
      text = ''
        #!/bin/sh
        "${pkgs.jdk}/lib/openjdk/bin/java" -cp "${pkgs.jetbrains.idea-community}/idea-community/plugins/vcs-git/lib/git4idea-rt.jar:${pkgs.jetbrains.idea-community}/idea-community/lib/externalProcess-rt.jar" git4idea.gpg.PinentryApp
      '';
    };
    ".config/i3/config".source = ./i3/i3_config;
    ".config/i3status/config".source = ./i3/i3status_config;
  };

  # TODO this isn't applied https://github.com/nix-community/home-manager/issues/3417
  home.sessionPath = [ "$HOME/.local/bin" ];

  home.sessionVariables = {
    KUBECONFIG = "${config.xdg.configHome}/kube/config";
    TERMINAL = "ghostty";
  };

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

  # terminal emulator
  programs.ghostty = {
    enable = true;
    #    package = config.lib.nixGL.wrap pkgs.ghostty;
    enableZshIntegration = true;
    settings = {
      theme = "Dracula";
      window-decoration = false; # hide the titlebar
      font-family = "JetBrains Mono"; # probs need to make sure this available on any system
      clipboard-paste-protection = true;
    };
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    dotDir = ".config/zsh"; # todo swap with "${config.xdg.configHome}/zsh"
    history = {
      append = true;
      extended = true;
      path = "${config.xdg.dataHome}/zsh/zsh_history";
      share = true;
    };
    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "docker"
      ];
      theme = "agnoster";
    };
    shellAliases = {
      ls = "exa";
      ll = "ls -la";
      lll = "ls --long --grid --header --group --accessed --modified -Hla";
      td = "cd $(mktemp -d)";
      gw = "./gradlew";
      # only really required whilst we have pacman
      lsi = ''expac -H M "%011m	%-20n	%10d" $(comm -23 <(pacman -Qqen | sort) <({ pacman -Qqg xorg; expac -l n %E base; } | sort -u)) | sort -n'';
    };
  };

  programs.btop = {
    enable = true;
    package = pkgs.btop.override {
      cudaSupport = true;
    };
  };

  #todo need to add configuration to change audio driver used
  programs.spotify-player = {
    enable = true;
    #    package = (pkgs.spotify-player.override { withAudioBackend = "pulseaudio"; });
  };

  programs.vim = {
    enable = true;
    defaultEditor = true;
    settings = {
      backupdir = [
        "${config.xdg.stateHome}/vim"
        "~/"
        "/tmp"
      ];
      directory = [
        "${config.xdg.cacheHome}/vim"
        "~/"
        "/tmp"
      ];
      undodir = [
        "${config.xdg.cacheHome}/vim"
        "~/"
        "/tmp"
      ];
      undofile = true;
      number = true;
    };
    extraConfig = ''
      set viminfo+=n${config.xdg.stateHome}/vim,~/,/tmp
    '';
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
    homedir = "${config.xdg.dataHome}/gnupg";
    settings = {
      personal-digest-preferences = "SHA512 SHA384 SHA256 SHA224";
      default-preference-list = "SHA512 SHA384 SHA256 SHA224 AES256 AES192 AES CAST5 BZIP2 ZLIB ZIP Uncompressed";
      cert-digest-algo = "SHA512";
      pinentry-mode = "loopback";
      log-file = "${config.xdg.stateHome}/gnupg/log";
      log-time = true;
    };
  };

  # disable ssh-agent as we defer all key managmenet to gpg
  services.ssh-agent.enable = false;
  services.gpg-agent = {
    enable = true;
    defaultCacheTtl = 1800;
    enableSshSupport = true;
    enableZshIntegration = true;
    extraConfig = ''
      pinentry-program ${pkgs.pinentry-qt}/bin/pinentry-qt
    '';
    sshKeys = [
      "BF3EDDD040FDF9435FD5F9B24577FB832C6B0E49" # source via `gpg --list-secret-keys --with-keygrip timj91@gmail.com`
    ];
  };

  programs.ssh = {
    enable = true;
    compression = true;
    controlMaster = "auto";
    controlPath = "/tmp/%u:%r@%h:%p";
    controlPersist = "120";
    forwardAgent = false;
    serverAliveCountMax = 6;
    serverAliveInterval = 15;
    extraConfig = ''
      Ciphers aes128-gcm@openssh.com,aes256-gcm@openssh.com,chacha20-poly1305@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
      TCPKeepAlive yes
      SetEnv TERM=vt100
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
    ];
}
