# Emacs user module -- bare install via Home Manager
{ config, lib, pkgs, ... }:

let
  cfg = config.userSettings.desktop.emacs;
in
{
  options.userSettings.desktop.emacs = {
    enable = lib.mkEnableOption "emacs text editor";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.wowvain = {
      home.packages = [
        pkgs.emacs  # Bare install -- no doom-emacs, spacemacs, or custom config
      ];
    };
  };
}
