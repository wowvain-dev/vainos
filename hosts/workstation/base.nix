# Workstation boot loader and dual-boot configuration.
# Auto-imported by mkHost from the host directory.
{ ... }:
{
  # Bootloader -- systemd-boot with XBOOTLDR
  # ESP (100MB at /efi) holds only the bootloader binary (~2MB)
  # XBOOTLDR (1GB at /boot) holds kernels, initrds, and generation entries
  boot.loader = {
    systemd-boot.enable = true;
    efi.efiSysMountPoint = "/efi";
    efi.canTouchEfiVariables = true;
  };

  # Fix clock drift when dual-booting with Windows
  # Windows uses localtime for the hardware clock; NixOS defaults to UTC
  time.hardwareClockInLocalTime = true;
}
