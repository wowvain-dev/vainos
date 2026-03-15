# Desktop Hyprland module — compositor + greetd + PAM + fonts + XDG portals
# Migrated from hosts/workstation/desktop.nix (compositor portion)
{ config, lib, pkgs, ... }:

let
  cfg = config.systemSettings.desktop.hyprland;
in
{
  options.systemSettings.desktop.hyprland = {
    enable = lib.mkEnableOption "Hyprland compositor with greetd, PAM, fonts, and XDG portals";
  };

  config = lib.mkIf cfg.enable {
    # Hyprland compositor with UWSM session management
    programs.hyprland = {
      enable = true;
      withUWSM = true;
      xwayland.enable = true;
    };

    # greetd login manager with tuigreet
    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.greetd.tuigreet}/bin/tuigreet --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions --remember --remember-user-session --time";
          user = "greeter";
        };
      };
    };

    # Suppress greetd TTY warning messages on TTY1
    systemd.services.greetd.serviceConfig = {
      Type = "idle";
      StandardInput = "tty";
      StandardOutput = "tty";
      StandardError = "journal";
      TTYReset = true;
      TTYVHangup = true;
      TTYVTDisallocate = true;
    };

    # XDG portal (hyprland portal auto-enabled by programs.hyprland; add GTK for file picker)
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    };

    # Electron/Chromium Wayland hint
    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    # PAM for hyprlock (needed for screen lock)
    security.pam.services.hyprlock = {};

    # Fonts
    fonts.packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      nerd-fonts.fira-code
      font-awesome
      noto-fonts
      noto-fonts-color-emoji
    ];
  };
}
