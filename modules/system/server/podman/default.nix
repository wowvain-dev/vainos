# Server Podman module — container runtime with Docker compatibility
# Migrated from hosts/server/podman.nix
{ config, lib, ... }:

let
  cfg = config.systemSettings.server.podman;
in
{
  options.systemSettings.server.podman = {
    enable = lib.mkEnableOption "Podman container runtime";
  };

  config = lib.mkIf cfg.enable {
    virtualisation = {
      containers.enable = true;
      podman = {
        enable = true;
        dockerCompat = true;
        defaultNetwork.settings.dns_enabled = true;
      };
    };
  };
}
