# Hyprlock user module -- Hyprlock + hypridle via Home Manager
{ config, lib, ... }:

let
  cfg = config.userSettings.desktop.hyprlock;
in
{
  options.userSettings.desktop.hyprlock = {
    enable = lib.mkEnableOption "hyprlock screen lock and hypridle";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.wowvain = {
      # Screen lock -- hyprlock (WS-11)
      programs.hyprlock = {
        enable = true;
        settings = {
          general = {
            hide_cursor = true;
            grace = 5;
          };

          background = [
            {
              monitor = "";
              color = "rgb(30, 30, 46)";
            }
          ];

          input-field = [
            {
              monitor = "";
              size = "200, 50";
              outline_thickness = 3;
              fade_on_empty = false;
              placeholder_text = "<i>Password...</i>";
            }
          ];
        };
      };

      # Idle management -- hypridle (WS-11)
      services.hypridle = {
        enable = true;
        settings = {
          general = {
            lock_cmd = "pidof hyprlock || hyprlock";
            before_sleep_cmd = "loginctl lock-session";
            after_sleep_cmd = "hyprctl dispatch dpms on";
          };

          listener = [
            {
              timeout = 300; # 5 minutes
              on-timeout = "hyprlock";
            }
            {
              timeout = 600; # 10 minutes
              on-timeout = "hyprctl dispatch dpms off";
              on-resume = "hyprctl dispatch dpms on";
            }
          ];
        };
      };
    };
  };
}
