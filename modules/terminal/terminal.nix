{ config, pkgs, ... }:
let
  unstablePkgs = import <nixos-unstable> { inherit pkgs; };
in {

  home.packages = with pkgs; [
    eza
    devenv
  ];

  home.file = {
    "${config.xdg.dataHome}/gnupg/pinentry.sh" = {
      executable = true;
      text = ''
        #!/bin/sh
        "${pkgs.jdk}/lib/openjdk/bin/java" -cp "${pkgs.jetbrains.idea}/idea/plugins/vcs-git/lib/git4idea-rt.jar:${pkgs.jetbrains.idea}/idea/lib/externalProcess-rt.jar" git4idea.gpg.PinentryApp
      '';
    };
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
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
  programs.bash.enable = false;
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    dotDir = config.xdg.configHome;
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
      ls = "eza --icons";
      ll = "ls -la";
      lll = "ls --long --grid --header --group --accessed --modified -Hla";
      tree = "ls --tree";
      td = "cd $(mktemp -d)";
      gw = "./gradlew";
      # only really required whilst we have pacman
      lsi = ''expac -H M "%011m	%-20n	%10d" $(comm -23 <(pacman -Qqen | sort) <({ pacman -Qqg xorg; expac -l n %E base; } | sort -u)) | sort -n'';
    };
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      add_newline = false;
      character.success_symbol = ''[➡](bold green)'';
      direnv = {
        disabled = false;
        symbol = "📂 ";
        allowed_msg = "🟢";
        not_allowed_msg = "🔴";
        denied_msg = "⛔";
        loaded_msg = "✅";
        unloaded_msg = "🟨";
      };
      gradle = {
        symbol = "🐘 ";
      };
      java.disabled = true;
      kotlin.disabled = true;
    };
  };

  programs.fd = {
    enable = true;
    ignores = [
      ".git/"
      "*.bak"
    ];
  };
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
#    defaultCommand = "fd --type f"; # fzf
    defaultOptions = [ "--preview 'head {}'" ];
#    changeDirWidgetCommand = "fd --type d"; # Alt-C
    changeDirWidgetOptions = [ "--preview 'eza --tree {} | head -200'"];
#    fileWidgetCommand = "fd --type f"; # Ctl-T
    fileWidgetOptions = [ "--preview 'head {}'" ];
    historyWidgetOptions = [ "--exact" ]; # Ctl-R
  };

  programs.btop = {
    enable = true;
    package = pkgs.btop.override {
      cudaSupport = true;
    };
  };

  programs.vim = {
    enable = true;
    defaultEditor = true;
  };

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Timothy Jacobson";
        email = "tim@jaconet.uk";
      };
      alias = {
        st = "status";
        ll = "log --decorate --graph";
      };
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
  };

  programs.delta = {
      enable = true;
      enableGitIntegration = true;
      options = {};
  };

  # AKA: jj
  programs.jujutsu = {
    enable = true;
    package = unstablePkgs.jujutsu;
    settings = {
      user.name = "Timothy Jacobson";
      user.email = "tim@jaconet.uk";
      ui = {
        default-command = "log";
        diff.tool = "delta";
      };
      merge-tools.delta.diff-expected-exit-codes = [0 1];
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
    enableDefaultConfig = false;
    settings = {
      "*" = {
        compression = true;
        controlMaster = "auto";
        controlPath = "/tmp/%u:%r@%h:%p";
        controlPersist = "120";
        forwardAgent = false;
        serverAliveCountMax = 6;
        serverAliveInterval = 15;
      };
    };
    extraConfig = ''
      Ciphers aes128-gcm@openssh.com,aes256-gcm@openssh.com,chacha20-poly1305@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
      TCPKeepAlive yes
      SetEnv TERM=vt100
    '';
  };

}
