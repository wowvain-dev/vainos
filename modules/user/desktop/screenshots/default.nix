# Screenshots user module -- Grim + slurp + XDG dirs via Home Manager
{ config, lib, pkgs, ... }:

let
  cfg = config.userSettings.desktop.screenshots;
in
{
  options.userSettings.desktop.screenshots = {
    enable = lib.mkEnableOption "screenshot tools (grim + slurp)";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.wowvain = {
      # Screenshot tools (WS-13)
      # grim: Wayland screenshot utility
      # slurp: region selection tool for Wayland
      # Keybinds defined in hyprland module:
      #   Print       -> fullscreen screenshot
      #   Super+Print -> region selection screenshot
      # Screenshots saved to ~/Pictures/Screenshots/
      home.packages = with pkgs; [
        grim
        slurp
      ];

      # Ensure XDG Pictures directory is set
      xdg.userDirs = {
        enable = true;
        pictures = "$HOME/Pictures";
      };
    };
  };
}
