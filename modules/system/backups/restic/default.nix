{ lib, config, ... }:
let
  cfg = config.backups.restic;
in
{
  options.backups.restic = {
    enable = lib.options.mkEnableOption "Enable Restic Backups";
    username = lib.options.mkOption {
      type = lib.types.str;
      default = "timj";
    };
    passwordFile = lib.options.mkOption {
      type = lib.types.str;
      description = "Absolute path to a password file used to encrypt the restic repository";
      default = "/home/timj/.config/restic/password";
    };
  };
  config = {
    services.restic =
      let
        listFilter = file: builtins.filter builtins.isString (builtins.split "\n" (builtins.readFile file));
        defaultExcludeList = listFilter ./excludesFile;
        includeList = listFilter ./includesFile;
        defaultHomeConfig = {
          user = "${cfg.username}";
          initialize = true;
          timerConfig = {
            OnCalendar = "*:02";
            Persistent = true;
          };
          extraBackupArgs = [
            "--exclude-caches"
            "--one-file-system" # avoids following symlinks (including into the nix store)
          ];
          pruneOpts = [
            "--keep-hourly 3"
            "--keep-daily 3"
            "--keep-weekly 5"
            "--keep-monthly 12"
            "--keep-yearly 75"
          ];
          passwordFile = "/home/timj/.config/restic/password"; # todo source somewhere safer
          repository = "/mnt/jacoserver/timj/restic_backups"; # todo use ssh
        };
      in
      {
        backups = lib.mkIf cfg.enable {
          homeBackup = lib.recursiveUpdate defaultHomeConfig {
            paths = [
              "/home/${cfg.username}"
            ];
            exclude = defaultExcludeList;
          };
          homeBackupIncludes = lib.recursiveUpdate defaultHomeConfig {
            paths = includeList;
          };
        };
      };
  };
}
