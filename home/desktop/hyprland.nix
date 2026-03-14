{ pkgs, ... }:
let
  workspaces = builtins.genList (i: toString (i + 1)) 9;
in
{
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
        ]
        ++ (builtins.map (n: "$mod, ${n}, workspace, ${n}") workspaces)
        ++ (builtins.map (n: "$mod SHIFT, ${n}, movetoworkspace, ${n}") workspaces);

      exec-once = [
        "hyprpolkitagent"
      ];
    };
  };

  home.packages = with pkgs; [
    hyprpolkitagent
  ];
}
