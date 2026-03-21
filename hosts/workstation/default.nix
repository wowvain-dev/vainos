# Workstation host configuration -- pure data.
# NixOS config lives in sibling .nix files (auto-imported by mkHost).
# hardware-configuration.nix is auto-imported by mkHost.
{ ... }:
{
  # Architecture -- read by flake.nix scanner
  systemSettings.system = "x86_64-linux";

  # NixOS state version -- applied as system.stateVersion by mkHost
  systemSettings.stateVersion = "25.11";

  # --- Enable desktop system modules ---
  systemSettings.desktop.hyprland.enable = true;
  systemSettings.desktop.audio.enable = true;
  systemSettings.desktop.gpu.enable = true;
  systemSettings.desktop.bluetooth.enable = true;
  systemSettings.desktop.gaming.enable = true;

  # --- Enable desktop user modules ---
  userSettings.desktop.hyprland.enable = true;
  userSettings.desktop.waybar.enable = true;
  userSettings.desktop.kitty.enable = true;
  userSettings.desktop.fuzzel.enable = true;
  userSettings.desktop.mako.enable = true;
  userSettings.desktop.hyprlock.enable = true;
  userSettings.desktop.clipboard.enable = true;
  userSettings.desktop.screenshots.enable = true;

  # --- Enable application modules ---
  userSettings.desktop.alacritty.enable = true;
  userSettings.desktop.firefox.enable = true;
  userSettings.desktop.yazi.enable = true;
  userSettings.desktop.discord.enable = true;
  userSettings.desktop.whatsapp.enable = true;
  userSettings.desktop.emacs.enable = true;
  userSettings.desktop.vscode.enable = true;
  userSettings.desktop.zed.enable = true;
  userSettings.desktop.blender.enable = true;
  userSettings.desktop.godot.enable = true;

  # --- Enable theming modules ---
  systemSettings.desktop.stylix.enable = true;
  userSettings.desktop.stylix.enable = true;
  userSettings.theme = "gruvbox-dark";

  # --- Enable security modules ---
  systemSettings.security.doas.enable = true;
  systemSettings.security.hosts-blocklist.enable = true;

  # --- Enable CLI module ---
  systemSettings.core.vainos-cli.enable = true;

  # --- Enable maintenance modules ---
  systemSettings.maintenance.autoUpdate.enable = false;
  userSettings.updateNotify.enable = true;
}
