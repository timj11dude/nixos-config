{
  config,
  lib,
  ...
}:
let
  cfg = config.gaming;
in
{
  options.gaming = {
    enable = lib.mkEnableOption "system-wide gaming support (Steam and gaming unfree packages)";
  };

  config = lib.mkIf cfg.enable {
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
    };

    nixpkgs.config.allowUnfreePackages = [
      "discord"
      "steam"
      "steam-unwrapped"
      "wowup-cf"
    ];
  };
}
