{ config, pkgs, osConfig, ... }:
let
  unstablePkgs = import <nixos-unstable> { inherit pkgs; };
in {
  home.packages = with pkgs; [
    wowup-cf
    prismlauncher
  ];
  programs.lutris = {
    enable = true;
    steamPackage = osConfig.programs.steam.package;
    extraPackages = [ pkgs.winetricks ];
    protonPackages = [pkgs.proton-ge-bin];
    winePackages = [ pkgs.wineWowPackages.full ];
  };

# todo figure out how to do this here, rather than in home.nix
#  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
#    "wowup-cf"
#  ];
}
