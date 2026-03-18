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

      # Global Caddy settings
      globalConfig = ''
        email admin@wowvain.com
      '';
    };
  };
}
