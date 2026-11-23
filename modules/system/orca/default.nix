{
  config,
  lib,
  ...
}:
let
  cfg = config.services.orca-ide;
in
{
  # Named orca-ide because NixOS already defines services.orca (the screen reader).
  options.services.orca-ide = {
    enable = lib.mkEnableOption "Orca server network access";

    port = lib.mkOption {
      type = lib.types.port;
      default = 6768;
      description = ''
        Port the Orca server listens on when the desktop app's "Advertise this
        app as a server" toggle is enabled. For a headless server without the
        desktop app, use `services.orca-server` instead.

        Only relevant when `tailnet.enable` is true.
      '';
    };

    tailnet = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Expose the Orca server over the Tailscale tailnet.

          Requires `services.tailscale.enable`. When enabled, the Orca port is
          opened in the firewall so paired clients can reach the machine via its
          Tailscale IP.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall = lib.mkIf (cfg.tailnet.enable && config.services.tailscale.enable) {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
