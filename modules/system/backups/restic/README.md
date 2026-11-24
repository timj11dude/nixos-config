# Restic Backups

Configures scheduled Restic backups for `/home/timj` (using `excludesFile`) and
explicitly included subdirectories (using `includesFile`):

- **TrueNAS** (`homeBackup`, `homeBackupIncludes`): hourly (`*:02`) to
  `/mnt/jacoserver/timj/restic_backups`.
- **Google Drive** (`homeBackupGoogleDrive`, `homeBackupIncludesGoogleDrive`,
  opt-in via `backups.restic.googleDrive.enable`): daily (`03:00` and `03:30`)
  to `rclone:gdrive:restic_backups` using the same password file.

## Google Drive Setup (`rclone`)

After rebuilding NixOS so `rclone` is installed, configure the `gdrive` remote
as your normal user:

```sh
rclone config
```

1. Choose `n` (New remote) and name it `gdrive`.
2. Select `drive` (Google Drive).
3. *(Recommended)* Supply your own Google Cloud OAuth `client_id` and
   `client_secret` (see <https://rclone.org/drive/#making-your-own-client-id>)
   for much higher throughput and to avoid sharing rclone's default API quota.
   Leave blank to use rclone's default client.
4. Scope: `1` (Full access to all files, excluding Application Data Folder) or
   `drive.file` (`3`, only files created by rclone).
5. Complete the browser OAuth flow when prompted.

Verify the remote works and permissions on the config file are private:

```sh
chmod 600 ~/.config/rclone/rclone.conf
rclone lsd gdrive:
```

## Running & Inspecting Backups Manually

NixOS installs wrapper scripts with the service environment pre-configured:

```sh
# Trigger a backup immediately via systemd
sudo systemctl start restic-backups-homeBackupGoogleDrive.service
sudo systemctl start restic-backups-homeBackupIncludesGoogleDrive.service

# Check logs
journalctl -u restic-backups-homeBackupGoogleDrive.service -n 50

# Inspect snapshots using the generated wrapper
restic-homeBackupGoogleDrive snapshots
```
