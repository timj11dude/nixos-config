{
  pkgs,
  lib,
  config,
  ...
}:
{
  options = {
    defaults.hostname = lib.mkOption {
      type = lib.types.str;
      description = "The name for the machine";
    };
  };
  config = {
    networking.hostName = config.defaults.hostname;
    time.timeZone = "Europe/London";
  };
}
