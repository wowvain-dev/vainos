# Blender user module -- bare install via Home Manager
{ config, lib, pkgs, ... }:

let
  cfg = config.userSettings.desktop.blender;
in
{
  options.userSettings.desktop.blender = {
    enable = lib.mkEnableOption "blender 3D creation suite";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.wowvain = {
      home.packages = [
        pkgs.blender  # Bare install -- no custom config
      ];
    };
  };
}
