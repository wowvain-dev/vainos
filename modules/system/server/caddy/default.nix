# Server Caddy module — base web server enablement
# Per-site vhosts are added by modules under modules/system/server/sites/
{ config, lib, ... }:

let
  cfg = config.systemSettings.server.caddy;
in
{
  options.systemSettings.server.caddy = {
    enable = lib.mkEnableOption "Caddy web server";
  };

  config = lib.mkIf cfg.enable {
    services.caddy = {
      enable = true;

      # Use staging ACME CA during development to avoid Let's Encrypt rate limits
      # Remove this line (or set to null) when DNS points to this server for production certs
      acmeCA = "https://acme-staging-v02.api.letsencrypt.org/directory";

      # Global Caddy settings
      globalConfig = ''
        email admin@wowvain.com
      '';
    };
  };
}
