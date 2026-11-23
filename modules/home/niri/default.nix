{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.my.niri;

  validatedConfig = pkgs.runCommand "niri-config.kdl" { } ''
    ${pkgs.niri}/bin/niri validate -c ${./config.kdl}
    cp ${./config.kdl} $out
  '';
in
{
  options.my.niri = {
    enable = lib.mkEnableOption "Niri Wayland compositor user configuration";
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile."niri/config.kdl".source = validatedConfig;
  };
}
