{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./networking.nix
    ./podman.nix
    ./caddy.nix
    ./containers.nix
  ];

  # Boot loader -- UEFI with systemd-boot (matches original install)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Match the stateVersion from the original NixOS installation
  system.stateVersion = "24.11";
}
