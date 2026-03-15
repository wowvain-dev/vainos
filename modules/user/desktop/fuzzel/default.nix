# Fuzzel user module -- Fuzzel launcher config via Home Manager
{ config, lib, ... }:

let
  cfg = config.userSettings.desktop.fuzzel;
in
{
  options.userSettings.desktop.fuzzel = {
    enable = lib.mkEnableOption "fuzzel application launcher";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.wowvain = {
      programs.fuzzel = {
        enable = true;

        settings.main = {
          font = "JetBrainsMono Nerd Font:size=12";
          terminal = "kitty";
          layer = "overlay";
        };
      };
    };
  };
}
