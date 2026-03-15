# Server containers module — OCI containers with sops secrets
# Migrated from hosts/server/containers.nix
{ config, lib, ... }:

let
  cfg = config.systemSettings.server.containers;
in
{
  options.systemSettings.server.containers = {
    enable = lib.mkEnableOption "OCI containers with sops secrets";
  };

  config = lib.mkIf cfg.enable {
    # sops-nix secrets for container environment
    # Path updated for new location: modules/system/server/containers/ (4 levels up to repo root)
    sops.defaultSopsFile = ../../../../secrets/secrets.yaml;
    sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    sops.secrets."app-env" = {};

    virtualisation.oci-containers = {
      backend = "podman";
      containers.webapp = {
        image = "containous/whoami:latest";
        autoStart = true;
        ports = [ "127.0.0.1:3000:80" ];
        environmentFiles = [ config.sops.secrets."app-env".path ];
      };
    };
  };
}
