{ pkgs, ... }:
{
  # Screenshot tools (WS-13)
  # grim: Wayland screenshot utility
  # slurp: region selection tool for Wayland
  # Keybinds defined in hyprland.nix:
  #   Print       -> fullscreen screenshot
  #   Super+Print -> region selection screenshot
  # Screenshots saved to ~/Pictures/Screenshots/
  home.packages = with pkgs; [
    grim
    slurp
  ];

  # Ensure XDG Pictures directory is set
  xdg.userDirs = {
    enable = true;
    pictures = "$HOME/Pictures";
  };
}
