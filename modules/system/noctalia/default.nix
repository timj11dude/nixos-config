{
  config,
  pkgs,
  lib,
  pins,
  ...
}:
let
  noctalia = pkgs.callPackage (pins.noctalia.src + "/nix/package.nix") {
    inherit config;
    inherit (pins.noctalia) rev;
    cudaSupport = false;
  };
in
{
  config = lib.mkIf config.programs.noctalia.enable {
    programs.noctalia = {
      package = lib.mkDefault noctalia;
      # Enables NetworkManager, Bluetooth, UPower and a power-profile service,
      # which Noctalia's integrations depend on.
      recommendedServices.enable = lib.mkDefault true;
      systemd.enable = lib.mkDefault true;
    };
  };
}
