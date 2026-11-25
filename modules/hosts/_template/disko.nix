# Single-drive GPT layout template for `./install.sh`.
#
# `install.sh` copies this file to `modules/hosts/<hostname>/disko.nix`, opens
# it in `$EDITOR`, and only then runs disko. Replace `__DISK_ID__` below with
# the stable by-id name of the target drive. Inspect candidates with:
#
#   lsblk -d -o NAME,SIZE,MODEL,TRAN
#   ls -l /dev/disk/by-id/
#
# For example `nvme-Samsung_SSD_990_PRO_1TB_S6Z1NJ0W123456X` or
# `ata-CT500MX500SSD1_2105E4F12345`. Use the whole-disk entry (without a
# `-partN` suffix). WARNING: disko wipes this drive.
{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/disk/by-id/__DISK_ID__";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };

        # Optional swap partition. Uncomment to enable (adjust the size).
        # swap = {
        #   size = "8G";
        #   content = {
        #     type = "swap";
        #     discardPolicy = "both";
        #   };
        # };

        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
