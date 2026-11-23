{
  pkgs,
  ...
}:
let
  validatedConfig = pkgs.runCommand "niri-config.kdl" { } ''
    ${pkgs.niri}/bin/niri validate -c ${./config.kdl}
    cp ${./config.kdl} $out
  '';
in
{
  xdg.configFile."niri/config.kdl".source = validatedConfig;
}
