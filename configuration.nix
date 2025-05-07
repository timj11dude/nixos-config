# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    <home-manager/nixos>
    "${builtins.fetchTarball "https://github.com/nix-community/disko/archive/master.tar.gz"}/module.nix"
    ./disko.nix
    "${builtins.fetchTarball {
      url = "https://github.com/Mic92/sops-nix/archive/cff8437c5fe8c68fc3a840a21bf1f4dc801da40d.tar.gz";
      # replace this with an actual hash
      sha256 = "1ddxjbwlygzcylvmj1vbgwv2hl0vwh911wsxk21qmwmlhq8pbgfr";
    }}/modules/sops"
  ];

  sops.defaultSopsFile = ./secrets/secrets.yaml;
  sops.defaultSopsFormat = "yaml";

  sops.age.keyFile = "/home/timj/.config/sops/age/keys.txt"; # todo move this somewhere secured. circular dependency here

  sops.secrets."truenas/login" = {};

  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "nvidia-x11"
      "nvidia-settings"
      "cuda_cudart"
      "libcublas"
      "cuda_cccl"
      "cuda_nvcc"
      "steam"
      "steam-original"
      "steam-unwrapped"
      "steam-run"
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # clear up 10GB space when less than 1GB left
  nix.extraOptions = ''
    min-free = ${toString (1 * 1024 * 1024 * 1024)}
    max-free = ${toString (10 * 1024 * 1024 * 1024)}
  '';

  networking.hostName = "aether"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager = {
    enable = true;
    insertNameservers = [
        "1.1.1.1"
        "10.0.0.1"
    ];
  };
  services.tailscale.enable = true;

  fileSystems = let
    credentials = config.sops.secrets."truenas/login".path;
    options = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s,uid=${toString config.users.users.timj.uid},gid=${toString config.users.groups.wheel.gid}";
  in {
    "/mnt/jacoserver/timj" = {
      device = "//10.0.0.2/private";
      fsType = "cifs";
      options = [
        options
        "credentials=${credentials}"
      ];
    };
    "/mnt/jacoserver/photos" = {
      device = "//10.0.0.2/Photos";
      fsType = "cifs";
      options = [
        options
        "credentials=${credentials}"
      ];
    };
    "/mnt/jacoserver/media" = {
      device = "//10.0.0.2/Media";
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

  # Configure keymap in X11
  services.xserver = {
    enable = true;
    xkb = {
      layout = "gb";
      variant = "";
    };
    windowManager.i3.enable = true;
    videoDrivers = [ "nvidia" ];
    xrandrHeads = [
      # this unfortuantly is very output order specific
      {
        output = "HDMI-0";
        monitorConfig = ''
          Option "LeftOf" "DP-4"
        '';
      }
      "DP-4"
      {
        output = "DP-0";
        monitorConfig = ''
          Option "RightOf" "DP-4"
          Option "Rotate" "right"
        '';
      }
    ];
  };
  services.displayManager.defaultSession = "none+i3";
  services.displayManager.autoLogin = {
    enable = false; #todo make dynamic on LUKS
    user = "timj";
  };

  # Configure console keymap
  console.keyMap = "uk";

  # Video
  hardware.graphics = {
    enable = true;
  };
  hardware.nvidia = {
    modesetting.enable = true;
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
    ];
    #    packages = with pkgs; [ ];
  };
  home-manager.users.timj = ./home.nix;

  environment.systemPackages = with pkgs; [
    vim
    git
  ];

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

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

  #nixpkgs.config.cudaSupport = true;
  services.ollama = let
    unstable = import <nixos-unstable> { config = { allowUnfree = true; }; };
  in {
    enable = true;
    acceleration = "cuda";
    package = unstable.ollama;
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?

}
