{ config, ... }:
let
  net = config.systemSettings.networking;
in
{
  services.caddy = {
    enable = true;

    virtualHosts."http://${net.ipv4.address}".extraConfig = ''
      handle /static/* {
        root * /srv/www
        encode gzip
        file_server
      }

      handle {
        reverse_proxy http://127.0.0.1:3000
      }
    '';
  };

  # Create the static site directory
  # Deploy built static files to /srv/www/static/ (e.g., Trunk/Yew WASM output)
  systemd.tmpfiles.rules = [
    "d /srv/www 0755 root root -"
    "d /srv/www/static 0755 root root -"
  ];
}
