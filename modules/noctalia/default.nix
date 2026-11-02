{ config, pkgs, lib, ... }:

let
  rev = "v5.4.1";
  noctalia-src = builtins.fetchTarball {
    url = "https://github.com/noctalia-dev/noctalia/archive/refs/tags/${rev}.tar.gz";
    sha256 = "0ih3aizacgi1v5b5qq907p3j6vsx0wjvnf9hc9gqwasb1dqir8cg";
  };
  noctalia = pkgs.callPackage (noctalia-src + "/nix/package.nix") {
    inherit config rev;
    cudaSupport = false;
  };
in
{
  imports = [
    # Noctalia's own NixOS module (disables the nixpkgs one to avoid conflicts).
    (noctalia-src + "/nix/nixos-module.nix")
  ];

  programs.noctalia = {
    enable = true;
    package = noctalia;
    # Enables NetworkManager, Bluetooth, UPower and a power-profile service,
    # which Noctalia's integrations depend on.
    recommendedServices.enable = true;
    systemd.enable = true;
  };
}
