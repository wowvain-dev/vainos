# Discord user module -- Discord messaging client via Home Manager
{ config, lib, pkgs, ... }:

let
  cfg = config.userSettings.desktop.discord;
in
{
  options.userSettings.desktop.discord = {
    enable = lib.mkEnableOption "discord messaging client";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.wowvain = {
      home.packages = [
        pkgs.vesktop  # Wayland-native Discord client with better screen sharing
      ];
    };
  };
}
