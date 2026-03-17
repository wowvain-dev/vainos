# Waybar user module -- Waybar config via Home Manager
{ config, lib, ... }:

let
  cfg = config.userSettings.desktop.waybar;
in
{
  options.userSettings.desktop.waybar = {
    enable = lib.mkEnableOption "waybar status bar";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.wowvain = {
      programs.waybar = {
        enable = true;
        systemd.enable = true; # Auto-start via systemd user service

        settings.main = {
          layer = "top";
          position = "top";
          height = 30;

          modules-left = [ "hyprland/workspaces" ];
          modules-center = [ "clock" ];
          modules-right = [ "pulseaudio" "network" "cpu" "memory" "tray" ];

          clock = {
            format = "{:%H:%M  %Y-%m-%d}";
          };

          pulseaudio = {
            format = "{volume}% {icon}";
            format-muted = "Muted";
          };

          cpu = {
            format = "CPU {usage}%";
          };

          memory = {
            format = "MEM {}%";
          };
        };

        # Colors and fonts are managed by Stylix via the waybar target.
        # Only non-themed layout styles are kept here.
        style = ''
          #workspaces button {
            padding: 0 5px;
          }

          #clock, #pulseaudio, #network, #cpu, #memory, #tray {
            padding: 0 10px;
          }
        '';
      };
    };
  };
}
