{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.my.niri;

  combinedConfig = pkgs.writeText "niri-config-raw.kdl" (
    lib.replaceStrings [ "// @EXTRA_INPUT_CONFIG@" ] [ cfg.extraInputConfig ] (
      builtins.readFile ./config.kdl
    )
    + lib.optionalString (cfg.extraConfig != "") "\n${cfg.extraConfig}"
  );

  validatedConfig = pkgs.runCommand "niri-config.kdl" { } ''
    ${pkgs.niri}/bin/niri validate -c ${combinedConfig}
    cp ${combinedConfig} $out
  '';
in
{
  options.my.niri = {
    enable = lib.mkEnableOption "Niri Wayland compositor user configuration";
    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Host-specific KDL configuration appended to the shared Niri config.";
    };
    extraInputConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        Host-specific KDL nodes spliced into the shared Niri `input` block
        (niri rejects a repeated top-level `input` node, so use this instead of `extraConfig`).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile."niri/config.kdl".source = validatedConfig;
  };
}
