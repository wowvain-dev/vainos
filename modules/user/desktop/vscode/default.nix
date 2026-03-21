# VSCode user module -- bare install via Home Manager
{ config, lib, pkgs, ... }:

let
  cfg = config.userSettings.desktop.vscode;
in
{
  options.userSettings.desktop.vscode = {
    enable = lib.mkEnableOption "visual studio code editor";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.wowvain = {
      home.packages = [
        pkgs.vscode  # Bare install -- no extensions or settings managed by Nix
      ];
    };
  };
}
