{ ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "server";

  # Match the stateVersion from the original NixOS installation
  system.stateVersion = "24.11";
}
