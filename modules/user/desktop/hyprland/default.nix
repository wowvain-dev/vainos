# Hyprland user module -- Hyprland HM config (keybinds, settings)
{ config, lib, pkgs, ... }:

let
  cfg = config.userSettings.desktop.hyprland;
  workspaces = builtins.genList (i: toString (i + 1)) 9;
  keybind-cheatsheet = pkgs.writeShellScriptBin "keybind-cheatsheet" (builtins.readFile ./keybind-cheatsheet.sh);
in
{
  options.userSettings.desktop.hyprland = {
    enable = lib.mkEnableOption "hyprland window manager (user config)";
    monitors = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ", preferred, auto, 1" ];
      description = "Hyprland monitor configuration lines (machine-specific, set in local config)";
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.wowvain = {
      wayland.windowManager.hyprland = {
        enable = true;
        systemd.enable = false; # CRITICAL: conflicts with UWSM

        settings = {
          "$mod" = "SUPER";

          monitor = cfg.monitors;

          general = {
            gaps_in = 5;
            gaps_out = 10;
            border_size = 2;
            layout = "dwindle";
          };

          dwindle = {
            preserve_split = true;
          };

          input = {
            kb_layout = "us";
            follow_mouse = 2;
            float_switch_override_focus = 2;
          };

          bind =
            [
              # ── Core ──
              "$mod, Return, exec, kitty"
              "$mod, D, exec, fuzzel"
              "$mod, Q, killactive"
              "$mod, F, fullscreen"
              "$mod, V, togglefloating"
              "$mod, L, exec, hyprlock"
              ''$mod, C, exec, cliphist list | fuzzel --dmenu | cliphist decode | wl-copy''

              "$mod, Y, exec, keybind-cheatsheet"

              # ── Apps ──
              "$mod, B, exec, firefox"
              "$mod, E, exec, kitty yazi"
              ''$mod SHIFT, E, exec, kitty sudo -E yazi''

              # ── Screenshots ──
              '', Print, exec, grim ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png''
              ''$mod SHIFT, S, exec, grim -g "$(slurp)" - | tee ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png | wl-copy''

              # ── Window focus (arrow keys) ──
              "$mod, left, movefocus, l"
              "$mod, right, movefocus, r"
              "$mod, up, movefocus, u"
              "$mod, down, movefocus, d"

              # ── Window swap ──
              "$mod SHIFT, left, swapwindow, l"
              "$mod SHIFT, right, swapwindow, r"
              "$mod SHIFT, up, swapwindow, u"
              "$mod SHIFT, down, swapwindow, d"

              # ── Window resize ──
              "$mod CTRL, left, resizeactive, -40 0"
              "$mod CTRL, right, resizeactive, 40 0"
              "$mod CTRL, up, resizeactive, 0 -40"
              "$mod CTRL, down, resizeactive, 0 40"

              # ── Layout ──
              "$mod, J, togglesplit"
              "$mod, P, pin"

              # ── Groups (tabbed) ──
              "$mod, G, togglegroup"
              "$mod, Tab, changegroupactive, f"

              # ── Scratchpad ──
              "$mod, S, togglespecialworkspace, magic"
              "$mod SHIFT, grave, movetoworkspace, special:magic"

              # ── Multi-monitor ──
              "$mod SHIFT, comma, movecurrentworkspacetomonitor, l"
              "$mod SHIFT, period, movecurrentworkspacetomonitor, r"
            ]
            ++ (builtins.map (n: "$mod, ${n}, focusworkspaceoncurrentmonitor, ${n}") workspaces)
            ++ (builtins.map (n: "$mod SHIFT, ${n}, movetoworkspace, ${n}") workspaces)
            ++ [ "$mod, 0, focusworkspaceoncurrentmonitor, 10" "$mod SHIFT, 0, movetoworkspace, 10" ];

          # ── Workspace defaults ──
          workspace = [
            "1, monitor:HDMI-A-2, default:true"
          ];

          # ── Mouse binds ──
          bindm = [
            "$mod, mouse:272, movewindow"
            "$mod, mouse:273, resizewindow"
          ];

          exec-once = [
            "hyprpolkitagent"
            "mkdir -p ~/Pictures/Screenshots"
          ];
        };
      };

      home.packages = with pkgs; [
        hyprpolkitagent
        keybind-cheatsheet
      ];
    };
  };
}
