{ config, pkgs, lib, osConfig, ... }:
let
  unstablePkgs = import <nixos-unstable> { inherit pkgs; };
in {
  home.packages = with pkgs; [
    (let
      version = "2.24.0-beta.6";
      pname = "wowup-cf";
      src = fetchurl {
        url = "https://github.com/WowUp/WowUp.CF/releases/download/v${version}/WowUp-CF-${version}.AppImage";
        sha256 = "191fxndc4mz4mbryqxyzah9hzl6i7xiqphfa69yli46m6zy5p7jd";
      };
      appimageContents = appimageTools.extractType1 { inherit pname version src; };
    in appimageTools.wrapType1 {
      inherit pname version src;
      extraInstallCommands = ''
        install -m 444 -D ${appimageContents}/${pname}.desktop -t $out/share/applications
        substituteInPlace $out/share/applications/${pname}.desktop \
          --replace 'Exec=AppRun' 'Exec=${pname}'
        cp -r ${appimageContents}/usr/share/icons $out/share
      '';
    })
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
