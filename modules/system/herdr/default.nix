{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.herdr;

  # Prebuilt Herdr binary (v0.9.5, x86_64 Linux). It is statically linked, so
  # it needs no glibc/patchelf fiddling — just copy it onto PATH. Building from
  # source would require a recent Rust toolchain that the pinned nixpkgs lacks,
  # so the release binary is used instead — matching the "install with Nix"
  # workflow without flakes.
  herdrSrc = pkgs.fetchurl {
    url = "https://github.com/herdrdev/herdr/releases/download/v0.9.5/herdr-linux-x86_64";
    hash = "sha256-FNnovItKngEY13wyJm921GHwm0A0LrI3UpYL2J9Zkp0=";
  };

  defaultPackage = pkgs.runCommand "herdr" { } ''
    mkdir -p $out/bin
    cp ${herdrSrc} $out/bin/herdr
    chmod +x $out/bin/herdr
  '';
in
{
  options.services.herdr = {
    enable = lib.mkEnableOption "Herdr terminal workspace manager";

    package = lib.mkOption {
      type = lib.types.package;
      default = defaultPackage;
      description = "Herdr package to install.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 19876;
      description = ''
        Port the Herdr server advertises for remote attach.

        Only relevant when `tailnet.enable` is true; local socket access is
        unchanged.
      '';
    };

    tailnet = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Expose the Herdr server over the Tailscale tailnet.

          Requires `services.tailscale.enable`. When enabled, Herdr's port is
          opened in the firewall so the machine can be reached via its
          Tailscale IP (for example over SSH with `herdr --remote
          <tailscale-ip>`).
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    # systemd user service: start the Herdr server on login so panes and
    # agents persist across terminal detach/reattach.
    systemd.user.services.herdr = {
      description = "Herdr terminal workspace server";
      documentation = [ "man:herdr(1)" ];
      after = [ "graphical-session.target" ];
      wantedBy = [ "default.target" ];
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = "5s";
        ExecStart = "${cfg.package}/bin/herdr";
        # Herdr keeps its own logs under ~/.config/herdr; mirror to the
        # journal so startup errors are visible.
        StandardOutput = "journal";
        StandardError = "journal";
        Environment = [ "HERDR_LOG=herdr=warn" ];
      };
    };

    # Open the Herdr port when reachable via the tailnet is requested.
    networking.firewall = lib.mkIf (cfg.tailnet.enable && config.services.tailscale.enable) {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
