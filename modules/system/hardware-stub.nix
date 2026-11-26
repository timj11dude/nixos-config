# Minimal hardware stub used ONLY by `./check.sh` when a host's gitignored
# `hardware-configuration.nix` is not present in the local checkout.
{ lib, ... }:
{
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
}
