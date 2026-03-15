# Clipboard user module -- Cliphist + wl-clipboard via Home Manager
{ config, lib, pkgs, ... }:

let
  cfg = config.userSettings.desktop.clipboard;
in
{
  options.userSettings.desktop.clipboard = {
    enable = lib.mkEnableOption "clipboard history (cliphist + wl-clipboard)";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.wowvain = {
      # Clipboard history manager (WS-12)
      # cliphist watches wl-paste and stores clipboard entries
      # Access via Super+C keybind defined in hyprland module
      services.cliphist.enable = true;

      home.packages = with pkgs; [
        wl-clipboard
      ];
    };
  };
}
