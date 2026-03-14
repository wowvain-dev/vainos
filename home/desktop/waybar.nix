{ ... }:
{
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

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font", "Font Awesome 6 Free";
        font-size: 13px;
      }

      window#waybar {
        background-color: rgba(30, 30, 46, 0.9);
        color: #cdd6f4;
      }

      #workspaces button {
        padding: 0 5px;
        color: #cdd6f4;
      }

      #workspaces button.active {
        color: #89b4fa;
      }

      #clock, #pulseaudio, #network, #cpu, #memory, #tray {
        padding: 0 10px;
      }
    '';
  };
}
