# Shared NixOS system configuration.
#
# Host-specific hardware, disk layout, mounts, and feature toggles live under
# `modules/hosts/<hostname>/default.nix`.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  pins = import ./pins.nix;

  gib = 1024 * 1024 * 1024;
in
{
  imports = [
    ./modules/hosts/aether
    ./modules/system/ai
    ./modules/system/backups/restic
    ./modules/system/gaming
    ./modules/system/herdr
    ./modules/system/noctalia
    ./modules/system/orca
    ./modules/system/orca-server
    "${pins.disko}/module.nix"
    "${pins.sops-nix}/modules/sops"
    "${pins.home-manager}/nixos"
    "${pins.noctalia.src}/nix/nixos-module.nix"
  ];

  # Share the single evaluated `pins` set with all NixOS modules.
  _module.args = {
    inherit pins;
  };

  # Secrets (sops-nix)
  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    # TODO: move the age key to a root-owned path (e.g. /var/lib/sops-nix/key.txt)
    # or derive it from /etc/ssh/ssh_host_ed25519_key to avoid depending on /home.
    age.keyFile = "/home/timj/.config/sops/age/keys.txt";
  };

  # Explicitly allowlisted unfree packages shared across system and Home Manager
  # (since `home-manager.useGlobalPkgs = true`). Host- and feature-specific
  # unfree packages are declared in their respective modules.
  nixpkgs.config = {
    allowUnfreePackages = [
      "intellij-idea"
      "obsidian"
      "rider"
      "terraform"
      "textual-speedups"
    ];

    # pkgs.ollama-cuda (and CUDA-enabled tools like btop) pull in unfree CUDA
    # toolkit components.
    allowUnfreePredicate =
      pkg:
      let
        name = lib.getName pkg;
      in
      lib.hasPrefix "cuda" name
      || lib.hasPrefix "libcu" name
      || lib.hasPrefix "libnpp" name
      || name == "cccl"
      || name == "libnvjitlink"
      || name == "libnvvm";
  };

  # Bootloader
  boot.loader = {
    systemd-boot = {
      enable = true;
      # Keep the 500 MiB ESP from filling up with old generations.
      configurationLimit = 10;
    };
    efi.canTouchEfiVariables = true;
  };

  # Nix daemon settings
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    # Free up to 10 GiB when less than 1 GiB remains.
    min-free = 1 * gib;
    max-free = 10 * gib;
    # "root" is already included by NixOS by default.
    trusted-users = [ "timj" ];
    extra-substituters = [ "https://cache.nixos-cuda.org" ];
    extra-trusted-public-keys = [
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
    ];
  };

  # Networking
  networking.networkmanager = {
    enable = true;
    insertNameservers = [ "1.1.1.1" ];
  };

  # Time zone & localisation
  time.timeZone = "Europe/London";

  i18n = {
    defaultLocale = "en_GB.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "en_GB.UTF-8";
      LC_IDENTIFICATION = "en_GB.UTF-8";
      LC_MEASUREMENT = "en_GB.UTF-8";
      LC_MONETARY = "en_GB.UTF-8";
      LC_NAME = "en_GB.UTF-8";
      LC_NUMERIC = "en_GB.UTF-8";
      LC_PAPER = "en_GB.UTF-8";
      LC_TELEPHONE = "en_GB.UTF-8";
      LC_TIME = "en_GB.UTF-8";
    };
  };

  console.keyMap = "uk";

  # Audio realtime scheduling (https://wiki.nixos.org/wiki/PipeWire)
  security.rtkit.enable = true;

  # System programs
  programs = {
    # Nix Helper (nh): human-friendly CLI and scheduled store cleanup that
    # preserves recent generations for safe rollbacks.
    nh = {
      enable = true;
      clean = {
        enable = true;
        extraArgs = "--keep 5 --keep-since 7d";
      };
    };

    hyprland = {
      enable = true;
      withUWSM = true;
      xwayland.enable = true;
    };

    niri.enable = true;
    zsh.enable = true;
  };

  systemd.user.services.niri.enableDefaultPath = false;

  # System services
  services = {
    tailscale.enable = true;

    greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${config.programs.niri.package}/bin/niri-session";
          user = "timj";
        };
      };
    };

    xserver = {
      enable = false;
      xkb = {
        layout = "gb";
        variant = "";
      };
    };

    pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
    };

    printing.enable = true;
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };

    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
        AllowUsers = [ "timj" ];
      };
    };
  };

  # User account & Home Manager
  users.users.timj = {
    isNormalUser = true;
    description = "Timothy Jacobson";
    shell = pkgs.zsh;
    extraGroups = [
      "networkmanager"
      "wheel"
      "audio"
      "video"
      "scanner"
      "lp"
    ];
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "bak";
    extraSpecialArgs = {
      inherit pins;
    };
    users.timj = ./home.nix;
  };

  environment = {
    pathsToLink = [ "/share/zsh" ];
    systemPackages = with pkgs; [
      comma
      git
      hyprlauncher
      nvd
      vim
      xwayland-satellite # xwayland support
    ];
  };

  # Do not change without reading the NixOS release notes.
  system.stateVersion = "24.11";

  # Garbage collection is handled by `programs.nh.clean` so recent generations
  # are retained for rollback.
  system.autoUpgrade = {
    enable = true;
    allowReboot = false;
    runGarbageCollection = false;
  };
}
