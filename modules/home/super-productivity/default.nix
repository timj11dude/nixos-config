{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.super-productivity;
in
{
  options.programs.super-productivity = {
    enable = lib.mkEnableOption "Super Productivity (todo app & time tracker)";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.super-productivity;
      description = "Super Productivity package to install.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];
  };
}
