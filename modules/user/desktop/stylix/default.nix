# User-level Stylix module -- per-app theming targets and theme selection option
# The userSettings.theme option is declared here as a user-level preference.
# The system stylix module reads config.userSettings.theme for preset selection.
{ config, lib, ... }:

let
  cfg = config.userSettings.desktop.stylix;
in
{
  options.userSettings.desktop.stylix = {
    enable = lib.mkEnableOption "Stylix per-application theming (user)";
  };

  options.userSettings.theme = lib.mkOption {
    type = lib.types.str;
    default = "gruvbox-dark";
    description = "Theme preset name -- selects base16 scheme and polarity. Available: gruvbox-dark, catppuccin-latte, tokyo-night";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.wowvain = {
      # Stylix auto-themes applications via Home Manager targets.
      # Explicit target control -- enable targets for apps we use,
      # disable for apps we configure manually or do not use.
      stylix.targets = {
        kitty.enable = true;
        waybar.enable = true;
        fuzzel.enable = true;
        mako.enable = true;
        hyprland.enable = true;
        hyprlock.enable = true;
        gtk.enable = true;
        qt.enable = true;
      };
    };
  };
}
