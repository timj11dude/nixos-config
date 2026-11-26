# Host entrypoint for `aether`.
# `hardware-configuration.nix` is machine-generated and gitignored.
{
  imports = [
    ./configuration.nix
    ./hardware-configuration.nix
  ];
}
