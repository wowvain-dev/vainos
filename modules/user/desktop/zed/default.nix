# Zed user module -- bare install via Home Manager
{ config, lib, pkgs, ... }:

let
  cfg = config.userSettings.desktop.zed;
in
{
  options.userSettings.desktop.zed = {
    enable = lib.mkEnableOption "zed code editor";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.wowvain = {
      home.packages = [
        pkgs.zed-editor  # Bare install -- no themes or settings managed by Nix
      ];
    };
  };
}
