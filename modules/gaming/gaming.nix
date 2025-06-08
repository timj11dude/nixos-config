{ config, pkgs, osConfig, ... }:
let
  unstablePkgs = import <nixos-unstable> { inherit pkgs; };
in {

  programs.lutris = {
    enable = true;
    steamPackage = osConfig.programs.steam.package;
    extraPackages = [ pkgs.winetricks ];
    protonPackages = [pkgs.proton-ge-bin];
    winePackages = [ pkgs.wineWowPackages.full ];
  };

}
