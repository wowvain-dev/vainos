# Server deployment infrastructure — shared base for multi-site hosting
# Provides: zram swap, /srv/sites/ directory tree, sops age key config
{ config, lib, ... }:

let
  cfg = config.systemSettings.server.deploy;
in
{
  options.systemSettings.server.deploy = {
    enable = lib.mkEnableOption "server deployment infrastructure (directories, swap, secrets key)";
  };

  config = lib.mkIf cfg.enable {
    # zram swap -- BTRFS prevents simple swap files, zram trades CPU for memory
    zramSwap = {
      enable = true;
      memoryPercent = 50;
    };

    # Shared directory tree for multi-site hosting
    systemd.tmpfiles.rules = [
      "d /srv/sites 0755 root root -"
      "d /srv/sites/src 0755 root root -"
      "d /srv/sites/www 0755 root caddy -"
    ];

    # sops-nix age key -- moved from containers module
    # Required for any sops secret decryption on the server
    sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };
}
