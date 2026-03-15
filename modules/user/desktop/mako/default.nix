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

        settings = {
          default-timeout = 5000;
          border-radius = 5;
          font = "JetBrainsMono Nerd Font 11";
          background-color = "#1e1e2edd";
          text-color = "#cdd6f4";
          border-color = "#89b4fa";
          border-size = 2;
        };
      };
    };
  };
}
