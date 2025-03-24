{
  disko.devices = {
    disk = {
      nvme_samsung_1 = {
        type = "disk";
        device = /dev/disk/by-id/nvme-SAMSUNG_MZVPV128HDGM-00000_S1XVNYAH209846;
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "500M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            primary = {
              size = "100%";
              content = {
                type = "lvm_pv";
                vg = "pool";
              };
            };
          };
        };
      };
      nvme_ct_1 = {
        type = "disk";
        device = /dev/disk/by-id/nvme-CT1000T700SSD5_2340E87B52FA;
        content = {
          type = "gpt";
          partitions = {
            primary = {
              size = "100%";
              content = {
                type = "lvm_pv";
                vg = "pool";
              };
            };
          };
        };
      };
      ssd_samsung_1 = {
        type = "disk";
        device = /dev/disk/by-id/ata-Samsung_SSD_850_EVO_250GB_S21PNSBG411051L;
        content = {
          type = "gpt";
          partitions = {
            primary = {
              size = "100%";
              content = {
                type = "lvm_pv";
                vg = "pool";
              };
            };
          };
        };
      };
      ssd_samsung_2 = {
        type = "disk";
        device = /dev/disk/by-id/ata-Samsung_SSD_870_QVO_1TB_S5SVNF0NB77522E;
        content = {
          type = "gpt";
          partitions = {
            primary = {
              size = "100%";
              content = {
                type = "lvm_pv";
                vg = "pool";
              };
            };
          };
        };
      };
      hdd_wdc_1 = {
        type = "disk";
        device = /dev/disk/by-id/ata-WDC_WD20EZAZ-00GGJB0_WD-WXA1AC8J27Y5;
        content = {
          type = "gpt";
          partitions = {
            primary = {
              size = "100%";
              content = {
                type = "lvm_pv";
                vg = "pool";
              };
            };
          };
        };
      };
      hdd_st_1 = {
        type = "disk";
        device = /dev/disk/by-id/ata-ST2000DL003-9VT166_5YD14T19;
        content = {
          type = "gpt";
          partitions = {
            primary = {
              size = "100%";
              content = {
                type = "lvm_pv";
                vg = "pool";
              };
            };
          };
        };
      };
    };
    lvm_vg = {
      pool = {
        type = "lvm_vg";
        lvs = {
          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
              mountOptions = [
                "defaults"
              ];
            };
          };
          nix = {
            size = "200G";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/nix";
              mountOptions = [
                "noatime"
              ];
            };
          };
          swap = {
            size = "64G";
            content = {
              type = "swap";
              mountpoint = "/swap";
            };
          };
        };
      };
    };
  };
}
