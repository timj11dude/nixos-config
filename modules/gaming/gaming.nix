{ config, pkgs, lib, osConfig, ... }:
let
  unstablePkgs = import <nixos-unstable> { inherit pkgs; };
in {
  home.packages = with pkgs; [
    wowup-cf
    prismlauncher
    discord
  ];
  programs.lutris = {
    enable = true;
    steamPackage = osConfig.programs.steam.package;
    extraPackages = [ pkgs.winetricks ];
    protonPackages = [pkgs.proton-ge-bin];
    winePackages = [ pkgs.wineWow64Packages.full ];
  };

  nixpkgs.config.allowUnfreePackages = [
    "wowup-cf"
    "discord"
  ];
}
