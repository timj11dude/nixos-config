# Host-specific configuration for `aether`.
{
  config,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
  ];

  networking = {
    hostName = "aether";
    hosts = {
      "127.0.0.1" = [
        "localhost"
        "aether"
      ];
      "192.168.0.178" = [
        "kube_control_plane"
        "cluster"
      ];
    };
    firewall = {
      enable = true;
      allowedTCPPorts = [ 24800 ];
      allowedUDPPorts = [ 24800 ];
    };
  };

  # TrueNAS CIFS mounts
  sops.secrets."truenas/login" = { };

  fileSystems =
    let
      credentials = config.sops.secrets."truenas/login".path;
      options = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s,uid=1000,gid=${toString config.users.groups.wheel.gid}";
      truenas = "192.168.1.178";
      mkTrueNasMount = share: {
        device = "//${truenas}/${share}";
        fsType = "cifs";
        options = [
          options
          "credentials=${credentials}"
        ];
      };
    in
    {
      "/mnt/jacoserver/timj" = mkTrueNasMount "private";
      "/mnt/jacoserver/photos" = mkTrueNasMount "Photos";
      "/mnt/jacoserver/media" = mkTrueNasMount "Media";
    };

  # Peripherals, GPU & scanner
  hardware = {
    ckb-next.enable = true;
    graphics.enable = true;
    nvidia = {
      modesetting.enable = true;
      powerManagement.enable = true; # Saves/restores VRAM on sleep/resume
      open = true;
    };
    sane = {
      enable = true;
      extraBackends = [ pkgs.epkowa ];
    };
  };

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

  # Host feature toggles
  ai.enable = true;

  backups.restic = {
    enable = true;
    googleDrive.enable = true;
  };
  gaming.enable = true;
  programs.noctalia.enable = true;

  services = {
    xserver.videoDrivers = [ "nvidia" ];

    herdr = {
      enable = false;
      # Reachable via the Tailscale tailnet.
      tailnet.enable = true;
    };

    orca-ide = {
      enable = true;
      # Opens the Orca port on the tailnet for paired clients. The desktop app
      # keeps its own "Advertise this app as a server" toggle; services.orca-server
      # stays disabled so the two are not run together.
      tailnet.enable = true;
    };
  };
}
