{
  config,
  pkgs,
  lib,
  pins,
  ...
}:
let
  cfg = config.services.orca-server;

  # Append the configured agent CLIs to the wrapper PATH so the systemd
  # service can spawn them without an interactive shell profile.
  package = cfg.package.override { agentTools = cfg.agents; };

  userCfg = config.users.users.${cfg.user};
in
{
  options.services.orca-server = {
    enable = lib.mkEnableOption ''
      Orca headless server (`orca serve`).

      Mutually exclusive with the desktop app's own "Advertise this app as
      a server" toggle (Settings → Remote Orca Servers): do not enable both
      on the same machine. Intended for headless hosts where the desktop app
      is not the server, such as a remote machine that clients pair with.

      Pairing links are not logged by the service. Pair clients by running
      `orca pair` as the configured user, or run `orca serve` in a terminal
      while the service is stopped
    '';

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../../home/orca/package.nix { };
      defaultText = lib.literalExpression "pkgs.callPackage ../../home/orca/package.nix { }";
      description = "Orca package providing the `orca` CLI used to run `orca serve`.";
    };

    agents = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pins.unstablePkgs; [
        claude-code
        antigravity-cli
      ];
      defaultText = lib.literalExpression "with (import ../../../pins.nix).unstablePkgs; [ claude-code antigravity-cli ]";
      description = ''
        Agent CLIs the headless Orca server can drive, such as Claude Code
        (`claude`) and Antigravity CLI (`agy` >= 1.5.2).

        Installed system-wide for interactive sign-in and appended to the
        Orca wrapper's PATH so `orca serve` can spawn them under systemd.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "timj";
      description = ''
        User account to run `orca serve` as. Orca stores its profile, worktree
        state, and agent credentials under this user's home directory.
      '';
    };

    group = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Primary group for the `orca serve` service. Defaults to the configured
        user's primary group.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 6768;
      description = ''
        Fixed port for `orca serve` (`--port`).
      '';
    };

    bind = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "100.78.250.15";
      description = ''
        Interface IP for `orca serve` to listen on (`--bind`). Null lets Orca
        choose its default bind address.
      '';
    };

    pairingAddress = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "100.78.250.15";
      description = ''
        Address clients should dial, advertised in pairing links
        (`--pairing-address`). Use the Tailscale IP or a reachable hostname,
        not a wildcard or `127.0.0.1`. Null lets Orca choose.
      '';
    };

    tailnet = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Expose the Orca server over the Tailscale tailnet.

          Requires `services.tailscale.enable`. When enabled, `port` is opened
          in the firewall so paired clients can reach the machine via its
          Tailscale IP.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.users.users ? ${cfg.user};
        message = "services.orca-server.user (${cfg.user}) must refer to an existing entry in users.users.";
      }
    ];

    # Include `gh` system-wide for interactive `gh auth login`; it is also in
    # Orca's wrapper PATH for systemd.
    environment.systemPackages = [
      package
      pkgs.gh
    ]
    ++ cfg.agents;

    systemd.services.orca-server = {
      description = "Orca headless server";
      documentation = [ "https://orca.dev/docs/remote-servers" ];
      after = [
        "network-online.target"
      ]
      ++ lib.optional config.services.tailscale.enable "tailscaled.service";
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        User = cfg.user;
        Group = if cfg.group != null then cfg.group else userCfg.group;
        WorkingDirectory = userCfg.home;
        ExecStart = lib.escapeShellArgs (
          [
            "${package}/bin/orca"
            "serve"
            "--supervise"
            "--no-pairing"
            "--port"
            (toString cfg.port)
          ]
          ++ lib.optionals (cfg.bind != null) [
            "--bind"
            cfg.bind
          ]
          ++ lib.optionals (cfg.pairingAddress != null) [
            "--pairing-address"
            cfg.pairingAddress
          ]
        );
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

    networking.firewall.interfaces.${config.services.tailscale.interfaceName} =
      lib.mkIf (cfg.tailnet.enable && config.services.tailscale.enable)
        {
          allowedTCPPorts = [ cfg.port ];
        };
  };
}
