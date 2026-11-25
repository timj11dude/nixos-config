# Host entrypoint for `__HOSTNAME__`.
# `hardware-configuration.nix` is machine-generated and gitignored.
{
  imports = [
    ./configuration.nix
    ./hardware-configuration.nix
  ];
}
