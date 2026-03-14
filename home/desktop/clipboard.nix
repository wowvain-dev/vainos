{ pkgs, ... }:
{
  # Clipboard history manager (WS-12)
  # cliphist watches wl-paste and stores clipboard entries
  # Access via Super+C keybind defined in hyprland.nix
  services.cliphist.enable = true;

  home.packages = with pkgs; [
    wl-clipboard
  ];
}
