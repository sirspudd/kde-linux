## Installation

- Download latest .raw http://kdeos.haraldsitter.eu/index.html
- Attach USB drive
- `lsblk` to find the right `/dev/node`. e.g. `/dev/sda`
- `sudo dd if=kdeos.raw of=/dev/sda bs=4M`
- `sudo sync`
- reboot into USB stick
- no password on sddm
- run calamares via kickoff/krunner

## Updates

Until discover gets support the following needs running

```
git clone https://invent.kde.org/sitter/kde-linux
cd kde-linux
sudo ./update.sh update
```

## VM

### virt-manager

- File -> New VM
- Import existing disk image
- [Forward]
- Select from disk
- Set arch as OS
- [Forward]
- Set resources
- [Forward]
- [x] Customize configuration
- [Finish]
- Config window opens
- Make sure at the bottom it says Firmware: UEFI
- [Add Hardware]
- Add a storage of some reasonable size
- [Finish]
- In the boot options item:
- check VirtIO Disk 2 and move it above 1
- [Apply]
- [Begin installation]

# Local Development

In order to speed up local builds, you can create a `mkosi.local.conf` file in the root of the repository with the following content:

```ini
[Content]
Environment=LOCALE_GEN="en_US.UTF-8 UTF-8" # replace with your locale`
Environment=MIRRORS_COUNTRY=us # replace with your country code`
Environment=PARALLEL_DOWNLOADS=50 # if your internet connection is fast

# Only uncomment this after you have done a complete build once
#Environment=KDE_BUILDER_ARGS="--no-src --install-only"
```


Then (assuming you have docker with the BTRFS storage driver) you can run:

```bash
./build_docker.sh --incremental
```
