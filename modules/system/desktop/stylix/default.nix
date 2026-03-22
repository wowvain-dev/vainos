# System-level Stylix module -- base16 theming, fonts, wallpaper, polarity
# Theme preset is selected via userSettings.theme (declared in user stylix module)
{ config, lib, pkgs, ... }:

let
  cfg = config.systemSettings.desktop.stylix;

  # Theme presets -- each maps to a base16 scheme name and polarity
  themePresets = {
    gruvbox-dark = {
      base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";
      polarity = "dark";
    };
    catppuccin-latte = {
      base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-latte.yaml";
      polarity = "light";
    };
    tokyo-night = {
      base16Scheme = "${pkgs.base16-schemes}/share/themes/tokyo-night-dark.yaml";
      polarity = "dark";
    };
  };

  # Resolve the selected theme from userSettings (fallback to gruvbox-dark)
  selectedTheme = config.userSettings.theme or "gruvbox-dark";
  theme = themePresets.${selectedTheme} or themePresets.gruvbox-dark;
in
{
  options.systemSettings.desktop.stylix = {
    enable = lib.mkEnableOption "Stylix system-wide theming";
  };

  config = lib.mkIf cfg.enable {
    stylix = {
      enable = true;
      enableReleaseChecks = false;
      # Generate a solid-color wallpaper from the theme's base00 background
      image = pkgs.runCommand "wallpaper.png" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
        magick -size 1920x1080 xc:#${config.lib.stylix.colors.base00} $out
      '';
      base16Scheme = theme.base16Scheme;
      polarity = theme.polarity;

      fonts = {
        monospace = {
          package = pkgs.nerd-fonts.fira-code;
          name = "FiraCode Nerd Font";
        };
        sansSerif = {
          package = pkgs.inter;
          name = "Inter";
        };
        serif = {
          package = pkgs.noto-fonts;
          name = "Noto Serif";
        };
        emoji = {
          package = pkgs.noto-fonts-color-emoji;
          name = "Noto Color Emoji";
        };
        sizes = {
          terminal = 12;
          applications = 11;
          desktop = 11;
        };
      };
    };
  };
}
