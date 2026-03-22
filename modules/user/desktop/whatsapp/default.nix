# WhatsApp user module -- WhatsApp messaging client via Home Manager
{ config, lib, pkgs, ... }:

let
  cfg = config.userSettings.desktop.whatsapp;
in
{
  options.userSettings.desktop.whatsapp = {
    enable = lib.mkEnableOption "whatsapp messaging client";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.wowvain = {
      home.packages = [
        pkgs.wasistlos  # GTK wrapper around WhatsApp Web (formerly whatsapp-for-linux)
      ];
    };
  };
}
