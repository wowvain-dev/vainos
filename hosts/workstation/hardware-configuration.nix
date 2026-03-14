# TODO: Replace this file with the output of `nixos-generate-config --root /mnt`
# after installing NixOS on the workstation. The UUIDs, kernel modules, and
# mount points below are realistic placeholders for a common AMD workstation
# with NVMe storage and EFI boot.
#
# Steps:
#   1. Boot NixOS installer USB
#   2. Partition disk alongside Windows
#   3. Mount everything under /mnt
#   4. Run: nixos-generate-config --root /mnt
#   5. Copy /mnt/etc/nixos/hardware-configuration.nix here
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  # TODO: These kernel modules are for a typical AMD workstation with NVMe.
  # nixos-generate-config will detect the correct modules for your hardware.
  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];  # TODO: Change to "kvm-intel" for Intel CPU
  boot.extraModulePackages = [ ];

  # TODO: Replace UUIDs with your actual partition UUIDs from `blkid`
  fileSystems."/" =
    { device = "/dev/disk/by-uuid/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
      fsType = "ext4";  # TODO: Or "btrfs" if you chose btrfs
    };

  # TODO: This is the Windows-created EFI System Partition (ESP).
  # The UUID will be different on your hardware -- use `blkid` to find it.
  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/XXXX-XXXX";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };

  swapDevices = [ ];
  # TODO: Uncomment and set UUID if you created a swap partition:
  # swapDevices = [ { device = "/dev/disk/by-uuid/yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"; } ];

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # TODO: Uncomment if your hardware has an AMD CPU with integrated graphics
  # hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  # TODO: Uncomment if your hardware has an Intel CPU
  # hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
