# Hyprland user module -- Hyprland HM config (keybinds, settings)
{ config, lib, pkgs, ... }:

let
  cfg = config.userSettings.desktop.hyprland;
  workspaces = builtins.genList (i: toString (i + 1)) 9;
in
{
  options.userSettings.desktop.hyprland = {
    enable = lib.mkEnableOption "hyprland window manager (user config)";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.wowvain = {
      wayland.windowManager.hyprland = {
        enable = true;
        systemd.enable = false; # CRITICAL: conflicts with UWSM

        settings = {
          "$mod" = "SUPER";

          monitor = [ ", preferred, auto, 1" ];

          general = {
            gaps_in = 5;
            gaps_out = 10;
            border_size = 2;
          };

          input = {
            kb_layout = "us";
            follow_mouse = 1;
          };

          bind =
            [
              "$mod, Return, exec, kitty"
              "$mod, D, exec, fuzzel"
              "$mod, Q, killactive"
              "$mod, F, fullscreen"
              "$mod, V, togglefloating"
              "$mod, L, exec, hyprlock"
              ''$mod, C, exec, cliphist list | fuzzel --dmenu | cliphist decode | wl-copy''
              '', Print, exec, grim ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png''
              ''$mod, Print, exec, grim -g "$(slurp)" ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png''
            ]
            ++ (builtins.map (n: "$mod, ${n}, workspace, ${n}") workspaces)
            ++ (builtins.map (n: "$mod SHIFT, ${n}, movetoworkspace, ${n}") workspaces);

          exec-once = [
            "hyprpolkitagent"
            "mkdir -p ~/Pictures/Screenshots"
          ];
        };
      };

      home.packages = with pkgs; [
        hyprpolkitagent
      ];
    };
  };
}
