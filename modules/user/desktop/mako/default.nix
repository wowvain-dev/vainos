# Mako user module -- Mako notification config via Home Manager
{ config, lib, ... }:

let
  cfg = config.userSettings.desktop.mako;
in
{
  options.userSettings.desktop.mako = {
    enable = lib.mkEnableOption "mako notification daemon";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.wowvain = {
      services.mako = {
        enable = true;

        # Colors and font are managed by Stylix via the mako target.
        settings = {
          default-timeout = 5000;
          border-radius = 5;
          border-size = 2;
        };
      };
    };
  };
}
