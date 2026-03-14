{ ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "workstation";

  # Populated in Phase 2 after NixOS installation
  system.stateVersion = "25.11";
}
