{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.super-productivity;
  mcpDir = "${config.xdg.dataHome}/super-productivity-mcp";

  # Upstream SP-MCP plugin source (https://github.com/organicmoron/SP-MCP).
  # Provides mcp_server.py and plugin.js used to bridge Super Productivity
  # with Claude Desktop via the Model Context Protocol.
  spMcpSrc = pkgs.fetchFromGitHub {
    owner = "organicmoron";
    repo = "SP-MCP";
    rev = "main";
    sha256 = "1a0cmhh75q611scvjm5wzddnxqr1q8f41jf584q9lhbxapd800bp";
    fetchSubmodules = false;
  };
in
{
  options.programs.super-productivity = {
    enable = lib.mkEnableOption "Super Productivity (todo app & time tracker)";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.super-productivity;
      description = "Super Productivity package to install.";
    };

    mcp = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Install and configure the SP-MCP plugin
          (https://github.com/organicmoron/SP-MCP).

          This installs the MCP server (`mcp_server.py`) and the plugin
          (`plugin.js`) into the Super Productivity data directory, installs
          the Python `mcp` library, and configures Claude Desktop to talk to
          Super Productivity.

          Note: `plugin.js` still needs to be uploaded manually via Super
          Productivity → Settings → Plugins → Upload Plugin. Once uploaded
          and both apps are restarted, Claude can read and update your tasks.

          Warning: this module manages `${config.xdg.configHome}/Claude/
          claude_desktop_config.json` (or `claudeConfig`) and will overwrite
          it. Merge any other MCP servers you use into the generated file.
        '';
      };

      pythonPackage = lib.mkOption {
        type = lib.types.package;
        default = pkgs.python3.withPackages (ps: [ ps.mcp ]);
        description = ''
          Python environment providing the `mcp` library used by the SP-MCP
          server.
        '';
      };

      dataDir = lib.mkOption {
        type = lib.types.str;
        default = mcpDir;
        description = ''
          Directory used by the SP-MCP server for plugin communication and to
          store mcp_server.py / plugin.js.
        '';
      };

      claudeConfig = lib.mkOption {
        type = lib.types.str;
        default = "${config.xdg.configHome}/Claude/claude_desktop_config.json";
        description = ''
          Path to the Claude Desktop configuration file to write the SP-MCP
          MCP server entry into.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ] ++ lib.optionals cfg.mcp.enable [ cfg.mcp.pythonPackage ];

    # MCP server and plugin files made available to Super Productivity and
    # Claude Desktop. Only present when mcp.enable is true.
    home.file = lib.mkIf cfg.mcp.enable {
      "${cfg.mcp.dataDir}/mcp_server.py" = {
        source = "${spMcpSrc}/mcp_server.py";
        mode = "0755";
      };

      "${cfg.mcp.dataDir}/plugin.js" = {
        source = "${spMcpSrc}/plugin.js";
      };

      # Communication directories used by the plugin <-> server bridge.
      "${cfg.mcp.dataDir}/plugin_commands" = {
        type = "directory";
        mode = "0755";
      };

      "${cfg.mcp.dataDir}/plugin_responses" = {
        type = "directory";
        mode = "0755";
      };

      # Claude Desktop MCP server configuration.
      "${cfg.mcp.claudeConfig}" = {
        text = builtins.toJSON {
          mcpServers = {
            "super-productivity" = {
              command = "${cfg.mcp.pythonPackage}/bin/python3";
              args = [ "${cfg.mcp.dataDir}/mcp_server.py" ];
            };
          };
        };
        mode = "0600";
      };
    };
  };
}
