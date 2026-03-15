# Server boot loader configuration.
# Auto-imported by mkHost from the host directory.
{ ... }:
{
  # Boot loader -- UEFI with systemd-boot (matches original install)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
}
