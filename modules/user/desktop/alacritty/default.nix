# Alacritty user module -- lightweight terminal fallback via Home Manager
{ config, lib, ... }:

let
  cfg = config.userSettings.desktop.alacritty;
in
{
  options.userSettings.desktop.alacritty = {
    enable = lib.mkEnableOption "alacritty terminal emulator";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.wowvain = {
      programs.alacritty = {
        enable = true;

        # Font and colors are managed by Stylix via the alacritty target.
        # No custom settings beyond Stylix -- alacritty serves as lightweight fallback.
      };
    };
  };
}
