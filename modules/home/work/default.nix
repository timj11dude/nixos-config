{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.my.work;
in
{
  options.my.work = {
    enable = lib.mkEnableOption "work-specific development tools and Firefox container";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      dotnet-sdk
      jetbrains.idea
      # NOTE: rider-2026.2.4 is currently marked insecure (CVE-2026-111497,
      # nixpkgs#590447). Enabling `my.work` requires either waiting for a fix
      # or adding "rider-2026.2.4" to nixpkgs.config.permittedInsecurePackages.
      jetbrains.rider
      super-productivity
      terraform
    ];

    programs.firefox.profiles.timj.containers.work = {
      name = "Work";
      color = "orange";
      icon = "briefcase";
      id = 2;
    };
  };
}
