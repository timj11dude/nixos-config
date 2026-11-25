{
  config,
  pkgs,
  lib,
  pins ? import ../../../pins.nix,
  ...
}:
let
  cfg = config.my.terminal;
  withGpg = import ./gnupg/with-gpg.nix {
    inherit pkgs;
    inherit (pins) unstablePkgs;
    secretspecFile = ../../../secretspec.toml;
  };
in
{
  options.my.terminal = {
    enable = lib.mkEnableOption "terminal emulator, shell, git, jujutsu, gpg, and ssh configuration";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      deadnix
      devenv
      eza
      nixfmt
      pins.unstablePkgs.bws
      secretspec
      statix
      unzip
      withGpg
    ];

    home.file."${config.xdg.dataHome}/gnupg/pinentry.sh" = {
      executable = true;
      text = ''
        #!/bin/sh
        "${pkgs.jdk}/lib/openjdk/bin/java" -cp "${pkgs.jetbrains.idea}/idea/plugins/vcs-git/lib/git4idea-rt.jar:${pkgs.jetbrains.idea}/idea/lib/externalProcess-rt.jar" git4idea.gpg.PinentryApp
      '';
    };

    programs = {
      direnv = {
        enable = true;
        enableZshIntegration = true;
        nix-direnv.enable = true;
      };

      # Terminal emulator
      ghostty = {
        enable = true;
        enableZshIntegration = true;
        settings = {
          theme = "Dracula";
          window-decoration = false; # hide the titlebar
          font-family = "JetBrains Mono";
          clipboard-paste-protection = true;
        };
      };

      bash.enable = false;

      zsh = {
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
          # Prompt rendering is handled by Starship.
          theme = "";
        };
        shellAliases = {
          ls = "eza --icons";
          ll = "ls -la";
          lll = "ls --long --grid --header --group --accessed --modified -Hla";
          tree = "ls --tree";
          td = "cd $(mktemp -d)";
          gw = "./gradlew";
          nixos-rebuild-here = "/home/timj/Projects/github.com:timj11dude/nixos-config/rebuild.sh switch";
        };
        initContent = lib.mkOrder 1000 ''eval "$(devenv hook zsh)"'';
      };

      starship = {
        enable = true;
        enableZshIntegration = true;
        settings = {
          add_newline = false;
          character.success_symbol = "[➡](bold green)";
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

      fd = {
        enable = true;
        ignores = [
          ".git/"
          "*.bak"
        ];
      };

      ripgrep.enable = true;

      fzf = {
        enable = true;
        enableZshIntegration = true;
        defaultOptions = [ "--preview 'head {}'" ];
        changeDirWidgetOptions = [ "--preview 'eza --tree {} | head -200'" ];
        fileWidgetOptions = [ "--preview 'head {}'" ];
        historyWidgetOptions = [ "--exact" ]; # Ctrl-R
      };

      btop = {
        enable = true;
        package = pkgs.btop.override {
          cudaSupport = true;
        };
      };

      vim = {
        enable = true;
        defaultEditor = true;
      };

      git = {
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
          "devenv.lock binary"
        ];
        signing = {
          key = "5CCFF11F4D012DE2";
          signByDefault = true;
        };
      };

      delta = {
        enable = true;
        enableGitIntegration = true;
        options = { };
      };

      # AKA: jj
      jujutsu = {
        enable = true;
        package = pins.unstablePkgs.jujutsu;
        settings = {
          user = {
            name = "Timothy Jacobson";
            email = "tim@jaconet.uk";
          };
          ui = {
            default-command = "log";
            diff.tool = "delta";
          };
          merge-tools.delta.diff-expected-exit-codes = [
            0
            1
          ];
        };
      };

      gpg = {
        enable = true;
        homedir = "${config.xdg.dataHome}/gnupg";
        settings = {
          personal-digest-preferences = "SHA512 SHA384 SHA256 SHA224";
          default-preference-list = "SHA512 SHA384 SHA256 SHA224 AES256 AES192 AES CAST5 BZIP2 ZLIB ZIP Uncompressed";
          cert-digest-algo = "SHA512";
          log-file = "${config.xdg.stateHome}/gnupg/log";
          log-time = true;
        };
      };

      ssh = {
        enable = true;
        enableDefaultConfig = false;
        settings = {
          "*" = {
            compression = true;
            controlMaster = "auto";
            controlPath = "~/.ssh/cm-%C";
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
    };

    # Disable ssh-agent as we defer all key management to gpg-agent.
    services.ssh-agent.enable = false;
    services.gpg-agent = {
      enable = true;
      defaultCacheTtl = 1800;
      enableSshSupport = true;
      enableZshIntegration = true;
      pinentry.package = pkgs.pinentry-qt;
    };
  };
}
