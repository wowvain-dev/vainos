{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./gpu.nix
    ./desktop.nix
    ./bluetooth.nix
  ];

  networking.hostName = "workstation";

  # Bootloader -- systemd-boot with shared ESP from Windows
  # TODO: If ESP is < 512MB, reduce configurationLimit or set up XBOOTLDR
  boot.loader = {
    systemd-boot.enable = true;
    systemd-boot.configurationLimit = 10;  # Limit stored generations to conserve ESP space
    efi.canTouchEfiVariables = true;
  };

  # Fix clock drift when dual-booting with Windows
  # Windows uses localtime for the hardware clock; NixOS defaults to UTC
  time.hardwareClockInLocalTime = true;

  system.stateVersion = "25.11";
}
