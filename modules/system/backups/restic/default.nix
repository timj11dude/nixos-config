{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.backups.restic;
  gdrive = cfg.googleDrive;

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

    googleDrive = {
      enable = lib.mkEnableOption "Restic backups to Google Drive via rclone";

      repository = lib.mkOption {
        type = lib.types.str;
        default = "rclone:gdrive:restic_backups";
        description = ''
          Rclone-backed Restic repository URL for Google Drive
          (format: `rclone:<remote>:<path>`).
        '';
      };

      rcloneConfigFile = lib.mkOption {
        type = lib.types.path;
        default = "/home/${cfg.username}/.config/rclone/rclone.conf";
        defaultText = lib.literalExpression ''"/home/''${config.backups.restic.username}/.config/rclone/rclone.conf"'';
        description = ''
          Absolute path to the rclone configuration file containing the Google Drive
          remote. Kept writable by the backup user so rclone can persist refreshed
          OAuth2 tokens.
        '';
      };

      rcloneOptions = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.oneOf [
            lib.types.str
            lib.types.bool
          ]
        );
        default = {
          # Permanently delete pruned pack and lock files instead of filling Google Drive Trash.
          drive-use-trash = false;
        };
        description = "Options passed to rclone via `services.restic.backups.<name>.rcloneOptions`.";
      };

      onCalendar = lib.mkOption {
        type = lib.types.str;
        default = "*-*-* 03:00:00";
        description = "Systemd OnCalendar schedule for the Google Drive home backup.";
      };

      includesOnCalendar = lib.mkOption {
        type = lib.types.str;
        default = "*-*-* 03:30:00";
        description = ''
          Systemd OnCalendar schedule for the Google Drive includes backup,
          staggered after `onCalendar` to avoid repository lock contention.
        '';
      };

      pruneOpts = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "--keep-daily 7"
          "--keep-weekly 5"
          "--keep-monthly 12"
          "--keep-yearly 75"
        ];
        description = "Retention policy passed to `restic forget --prune` for Google Drive backups.";
      };
    };
  };

  config = lib.mkIf cfg.enable (
    let
      defaultExcludeList = readLines ./excludesFile;
      includeList = readLines ./includesFile;

      baseBackupConfig = {
        user = cfg.username;
        initialize = true;
        extraBackupArgs = [
          "--exclude-caches"
          "--one-file-system" # avoids following symlinks (including into the nix store)
        ];
        inherit (cfg) passwordFile;
      };

      nasBackupConfig = baseBackupConfig // {
        timerConfig = {
          OnCalendar = "*:02";
          Persistent = true;
        };
        pruneOpts = [
          "--keep-hourly 3"
          "--keep-daily 3"
          "--keep-weekly 5"
          "--keep-monthly 12"
          "--keep-yearly 75"
        ];
        inherit (cfg) repository;
      };

      gdriveBackupConfig = baseBackupConfig // {
        inherit (gdrive)
          repository
          rcloneConfigFile
          rcloneOptions
          pruneOpts
          ;
      };
    in
    {
      environment.systemPackages = lib.optionals gdrive.enable [
        pkgs.rclone
      ];

      services.restic.backups = {
        homeBackup = nasBackupConfig // {
          paths = [ "/home/${cfg.username}" ];
          exclude = defaultExcludeList;
        };
        homeBackupIncludes = nasBackupConfig // {
          paths = includeList;
        };
      }
      // lib.optionalAttrs gdrive.enable {
        homeBackupGoogleDrive = gdriveBackupConfig // {
          paths = [ "/home/${cfg.username}" ];
          exclude = defaultExcludeList;
          timerConfig = {
            OnCalendar = gdrive.onCalendar;
            Persistent = true;
          };
        };
        homeBackupIncludesGoogleDrive = gdriveBackupConfig // {
          paths = includeList;
          timerConfig = {
            OnCalendar = gdrive.includesOnCalendar;
            Persistent = true;
          };
        };
      };

      # Serialize the two Google Drive jobs if both trigger together (e.g. Persistent
      # catch-up after sleep) so they do not contend on the exclusive repository lock
      # during `forget --prune`.
      systemd.services.restic-backups-homeBackupIncludesGoogleDrive = lib.mkIf gdrive.enable {
        after = [ "restic-backups-homeBackupGoogleDrive.service" ];
      };
    }
  );
}
