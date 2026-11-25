# Host-specific configuration for `__HOSTNAME__`.
# Copy `modules/hosts/_template` to `modules/hosts/<hostname>` and replace `__HOSTNAME__`.
{
  imports = [
    ../../../configuration.nix
  ];

  networking.hostName = "__HOSTNAME__";

  # Enable host-specific features as needed:
  # ai.enable = true;
  # gaming.enable = true;
  # programs.noctalia.enable = true;
}
