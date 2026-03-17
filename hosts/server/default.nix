# Server host configuration -- pure data.
# NixOS config lives in sibling .nix files (auto-imported by mkHost).
# hardware-configuration.nix is auto-imported by mkHost.
{ ... }:
{
  # Architecture -- read by flake.nix scanner
  systemSettings.system = "x86_64-linux";

  # NixOS state version -- applied as system.stateVersion by mkHost
  systemSettings.stateVersion = "24.11";

  # --- Enable server modules ---
  systemSettings.server.networking.enable = true;
  systemSettings.server.caddy.enable = true;
  systemSettings.server.containers.enable = true;
  systemSettings.server.podman.enable = true;

  # --- Enable security modules ---
  systemSettings.security.doas.enable = true;
  systemSettings.security.hosts-blocklist.enable = true;

  # --- Enable CLI module ---
  systemSettings.core.vainos-cli.enable = true;
}
