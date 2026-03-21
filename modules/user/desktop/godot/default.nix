# Godot user module -- bare install via Home Manager
{ config, lib, pkgs, ... }:

let
  cfg = config.userSettings.desktop.godot;
in
{
  options.userSettings.desktop.godot = {
    enable = lib.mkEnableOption "godot game engine";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.wowvain = {
      home.packages = [
        pkgs.godot_4  # Standard GDScript build (not mono/C#)
      ];
    };
  };
}
