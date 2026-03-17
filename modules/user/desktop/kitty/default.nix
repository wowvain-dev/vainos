# Kitty user module -- Kitty terminal config via Home Manager
{ config, lib, ... }:

let
  cfg = config.userSettings.desktop.kitty;
in
{
  options.userSettings.desktop.kitty = {
    enable = lib.mkEnableOption "kitty terminal emulator";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.wowvain = {
      programs.kitty = {
        enable = true;

        # Font is managed by Stylix via the kitty target.

        settings = {
          scrollback_lines = 10000;
          enable_audio_bell = false;
          window_padding_width = 4;
          background_opacity = lib.mkForce "0.95";
        };

        shellIntegration.enableZshIntegration = true;
      };
    };
  };
}
