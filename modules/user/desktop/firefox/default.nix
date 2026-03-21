# Firefox user module -- Firefox browser with profile config via Home Manager
{ config, lib, pkgs, ... }:

let
  cfg = config.userSettings.desktop.firefox;
in
{
  options.userSettings.desktop.firefox = {
    enable = lib.mkEnableOption "firefox web browser";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.wowvain = {
      programs.firefox = {
        enable = true;

        # Default profile with declarative settings.
        # Firefox Sync adds the user's additional extensions on top --
        # Nix-declared settings are additive and coexist with Sync.
        profiles.default = {
          isDefault = true;

          # Declarative extensions require the NUR firefox-addons overlay.
          # When NUR is added to flake inputs, uncomment to lock these:
          #   extensions.packages = with pkgs.firefox-addons; [
          #     ublock-origin    # content blocker
          #     bitwarden        # password manager
          #   ];
          # Until then, install uBlock Origin and Bitwarden from addons.mozilla.org
          # on first launch. Firefox Sync will persist them across rebuilds.

          search.default = "DuckDuckGo";
          search.force = true;

          settings = {
            # Disable default browser check
            "browser.shell.checkDefaultBrowser" = false;
            # Enable HTTPS-only mode
            "dom.security.https_only_mode" = true;
            # Disable telemetry
            "toolkit.telemetry.enabled" = false;
            "datareporting.healthreport.uploadEnabled" = false;
            # Disable Pocket
            "extensions.pocket.enabled" = false;
          };
        };
      };
    };
  };
}
