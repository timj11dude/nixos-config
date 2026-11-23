# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{
  config,
  pkgs,
  lib,
  ...
}:
let
  asBytes = let
    pow = i: n: if (n>0) then (pow i (n - 1)) * i else 1;
    m = {
      "KB"=1;
      "MB"=2;
      "GB"=3;
      "TB"=4;
    };
   in size: (unit: size * (pow 1024 m."${unit}"));
   home-manager = builtins.fetchTarball {
     url = "https://github.com/nix-community/home-manager/archive/release-26.05.tar.gz";
     sha256 = "0x0dcasjli38yabl1dpq4ymg7ixv02hd825676irw5cir8z0r2jx";
   };
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./modules/system/backups/restic
    ./modules/system/gaming
    ./modules/system/ai
    ./modules/system/herdr
    ./modules/system/orca
    ./modules/system/orca-server
    ./modules/system/noctalia
    ./modules/hosts/aether
    "${builtins.fetchTarball {
      url = "https://github.com/nix-community/disko/archive/master.tar.gz";
      sha256 = "1f2wsz31rf4sqg7spsjnq82c97gicn8zxlnj2zjsmm5g1pcnfzhg";
    }}/module.nix"
    ./disko.nix
    "${builtins.fetchTarball {
      url = "https://github.com/Mic92/sops-nix/archive/cff8437c5fe8c68fc3a840a21bf1f4dc801da40d.tar.gz";
      sha256 = "1ddxjbwlygzcylvmj1vbgwv2hl0vwh911wsxk21qmwmlhq8pbgfr";
    }}/modules/sops"
    "${home-manager}/nixos"
  ];

  sops.defaultSopsFile = ./secrets/secrets.yaml;
  sops.defaultSopsFormat = "yaml";

  sops.age.keyFile = "/home/timj/.config/sops/age/keys.txt"; # todo move this somewhere secured. circular dependency here

  sops.secrets."truenas/login" = {};

  nixpkgs.config.allowUnfreePackages = [
    "nvidia-settings"
    "nvidia-x11"
    "nvidia-persistenced"
    "iscan"
    "iscan-ds"
    "iscan-gt-f720-bundle"
    "iscan-gt-s650-bundle"
    "iscan-gt-s600-bundle"
    "iscan-gt-s80-bundle"
    "iscan-v370-bundle"
    "iscan-v330-bundle"
    "iscan-perfection-v550-bundle"
    "iscan-gt-x750-bundle"
    "iscan-gt-x820-bundle"
    "iscan-gt-x770-bundle"
    "iscan-data"
    "iscan-gt"
    "iscan-nt-bundle"
  ];

  # pkgs.ollama-cuda pulls in unfree CUDA toolkit components.
  nixpkgs.config.allowUnfreePredicate = pkg:
    let
      name = lib.getName pkg;
    in
    lib.hasPrefix "cuda" name
    || lib.hasPrefix "libcu" name
    || lib.hasPrefix "libnpp" name
    || name == "libnvjitlink";

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [
    "nvidia-drm.modeset=1"
#    "mem_sleep_default=s2idle"
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
#    "nvidia.NVreg_TemporaryFilePath=/var/tmp"
  ];


  # clear up 10GB space when less than 1GB left
  nix.extraOptions = ''
    min-free = ${toString (asBytes 1 "GB")}
    max-free = ${toString (asBytes 10 "GB")}
  '';


  networking = {
    hostName = "aether";
    hosts = {
      "127.0.0.1" = [ "localhost" "aether"];
      "192.168.0.178" = [ "kube_control_plane" "cluster" ];
    };
  };
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager = {
    enable = true;
    insertNameservers = [
        "1.1.1.1"
    ];
  };
  services.tailscale.enable = true;

  fileSystems = let
    credentials = config.sops.secrets."truenas/login".path;
    options = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s,uid=1000,gid=${toString config.users.groups.wheel.gid}";
    truenas = "192.168.1.178";
  in {
    "/mnt/jacoserver/timj" = {
      device = "//${truenas}/private";
      fsType = "cifs";
      options = [
        options
        "credentials=${credentials}"
      ];
    };
    "/mnt/jacoserver/photos" = {
      device = "//${truenas}/Photos";
      fsType = "cifs";
      options = [
        options
        "credentials=${credentials}"
      ];
    };
    "/mnt/jacoserver/media" = {
      device = "//${truenas}/Media";
      fsType = "cifs";
      options = [
        options
        "credentials=${credentials}"
      ];
    };
  };

  # Set your time zone.
  time.timeZone = "Europe/London";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";

  i18n.extraLocaleSettings = {
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

  programs.hyprland = {
    enable = true;
    withUWSM = true; # recommended for most users
    xwayland.enable = true; # Xwayland can be disabled.
  };

  programs.niri.enable = true;
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${config.programs.niri.package}/bin/niri-session";
        user = "timj";
      };
    };
  };
  systemd.user.services.niri.enableDefaultPath = false;

#  # Configure keymap in X11
  services.xserver = {
    enable = false;
    xkb = {
      layout = "gb";
      variant = "";
    };
    xrandrHeads = [
      {
        output = "DP-2";
        primary = true;
        monitorConfig = "DisplaySize 5120 1440";
      }
    ];
    windowManager.i3.enable = false;
    videoDrivers = [ "nvidia" ];
  };

#  services.displayManager.defaultSession = "none+i3";
  services.displayManager.autoLogin = {
    enable = false; #todo make dynamic on LUKS
    user = "timj";
  };

  # Configure console keymap
  console.keyMap = "uk";

  # todo move this to Aether specific configuration
  hardware.ckb-next.enable = true;

  # Video
  hardware.graphics = {
    enable = true;
  };
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true; # Saves/restores VRAM on sleep/resume
    open = true;
  };

  # Audio https://wiki.nixos.org/wiki/PipeWire
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # Print https://wiki.nixos.org/wiki/Printing
  services.printing.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # home-manager configuration
  home-manager = {
    backupFileExtension = "bak";
  };

  programs.zsh.enable = true;
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
    #    packages = with pkgs; [ ];
  };
  home-manager.users.timj = ./home.nix;
  nix.settings.trusted-users = [ "root" "timj" ];

  environment = {
    pathsToLink = [ "/share/zsh" ];
    systemPackages = with pkgs; [
      comma
      git
      hyprlauncher
      vim
      xwayland-satellite # xwayland support
    ];
  };

#  programs.waybar.enable = true;

#  programs.nix-index.enable = true;
#  programs.nix-index-database.comma.enable = true;

  backups.restic.enable = true;

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false; # todo want to change this to false
      AllowUsers = [ "timj" ];
    };
  };

  # Open ports in the firewall. TODO debug this isn't working:
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 24800 ];
    allowedUDPPortRanges = [
      {
        from = 24800;
        to = 24800;
      }
    ];
  };

  # Print/Scanner support (ideally)
  hardware.sane = {
    enable = true;
    extraBackends = [ pkgs.epkowa ];
  };

  nix.settings = {
    substituters = [ "https://cache.nixos-cuda.org" ];
    trusted-public-keys = [ "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M=" ];
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
  system.autoUpgrade = {
    enable = true;
    allowReboot = false;
    runGarbageCollection = true;
  };
}
