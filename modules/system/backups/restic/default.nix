{
  lib,
  config,
  ...
}:
let
  cfg = config.backups.restic;

  readLines = file: lib.filter (line: line != "") (lib.splitString "\n" (builtins.readFile file));
in
{
  options.backups.restic = {
    enable = lib.mkEnableOption "Restic backups";

    username = lib.mkOption {
      type = lib.types.str;
      default = "timj";
      description = "User whose home directory is backed up.";
    };

    passwordFile = lib.mkOption {
      type = lib.types.path;
      default = "/home/timj/.config/restic/password";
      description = "Absolute path to a password file used to encrypt the restic repository.";
    };

    repository = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/jacoserver/timj/restic_backups";
      description = "Restic backup repository path or URL.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.restic.backups =
      let
        defaultExcludeList = readLines ./excludesFile;
        includeList = readLines ./includesFile;
        defaultHomeConfig = {
          user = cfg.username;
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
          inherit (cfg) passwordFile repository;
        };
      in
      {
        homeBackup = lib.recursiveUpdate defaultHomeConfig {
          paths = [ "/home/${cfg.username}" ];
          exclude = defaultExcludeList;
        };
        homeBackupIncludes = lib.recursiveUpdate defaultHomeConfig {
          paths = includeList;
        };
      };
  };
}
