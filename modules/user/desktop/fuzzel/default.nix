# Fuzzel user module -- Fuzzel launcher config via Home Manager
{ config, lib, ... }:

let
  cfg = config.userSettings.desktop.fuzzel;
in
{
  options.userSettings.desktop.fuzzel = {
    enable = lib.mkEnableOption "fuzzel application launcher";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.wowvain = {
      programs.fuzzel = {
        enable = true;

        # Font is managed by Stylix via the fuzzel target.
        settings.main = {
          terminal = "kitty";
          layer = "overlay";
        };
      };
    };
  };
}
