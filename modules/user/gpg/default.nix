# GPG user module -- GPG agent with SSH integration via Home Manager
{ config, lib, pkgs, ... }:

let
  cfg = config.userSettings.gpg;
in
{
  options.userSettings.gpg = {
    enable = lib.mkEnableOption "GPG agent with SSH integration" // { default = true; };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.wowvain = {
      programs.gpg = {
        enable = true;
      };

      services.gpg-agent = {
        enable = true;
        enableSshSupport = true;          # GPG agent serves as SSH agent
        enableZshIntegration = true;      # Auto-start in zsh sessions
        defaultCacheTtl = 3600;           # Cache passphrase 1 hour
        defaultCacheTtlSsh = 3600;        # Cache SSH key passphrase 1 hour
        maxCacheTtl = 86400;              # Max cache 24 hours
        maxCacheTtlSsh = 86400;           # Max SSH cache 24 hours
        pinentryPackage = pkgs.pinentry-curses;  # Terminal-based PIN entry
      };
    };
  };
}
