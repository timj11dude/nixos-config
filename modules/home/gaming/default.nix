{
  config,
  pkgs,
  lib,
  osConfig ? { },
  ...
}:
let
  cfg = config.my.gaming;

  wowup-cf =
    let
      version = "2.24.0-beta.6";
      pname = "wowup-cf";
      src = pkgs.fetchurl {
        url = "https://github.com/WowUp/WowUp.CF/releases/download/v${version}/WowUp-CF-${version}.AppImage";
        sha256 = "191fxndc4mz4mbryqxyzah9hzl6i7xiqphfa69yli46m6zy5p7jd";
      };
      appimageContents = pkgs.appimageTools.extractType1 { inherit pname version src; };
    in
    pkgs.appimageTools.wrapType1 {
      inherit pname version src;
      extraInstallCommands = ''
        install -m 444 -D ${appimageContents}/${pname}.desktop -t $out/share/applications
        substituteInPlace $out/share/applications/${pname}.desktop \
          --replace-fail 'Exec=AppRun' 'Exec=${pname}'
        cp -r ${appimageContents}/usr/share/icons $out/share
      '';
    };
in
{
  options.my.gaming = {
    enable = lib.mkEnableOption "user gaming tools (Lutris, Prism Launcher, WowUp, Discord)";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      wowup-cf
      pkgs.prismlauncher
      pkgs.discord
    ];

    programs.lutris = {
      enable = true;
      steamPackage = osConfig.programs.steam.package or pkgs.steam;
      extraPackages = [ pkgs.winetricks ];
      protonPackages = [ pkgs.proton-ge-bin ];
      winePackages = [ pkgs.wineWow64Packages.full ];
    };
  };
}
