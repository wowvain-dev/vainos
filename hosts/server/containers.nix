{ config, ... }:
{
  # sops-nix secrets for container environment
  sops.defaultSopsFile = ../../secrets/secrets.yaml;
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
}
