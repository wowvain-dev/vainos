# doas privilege escalation -- replaces sudo with minimal, auditable config
{ config, lib, pkgs, ... }:

let
  cfg = config.systemSettings.security.doas;
in
{
  options.systemSettings.security.doas = {
    enable = lib.mkEnableOption "doas privilege escalation (replaces sudo)";
  };

  config = lib.mkIf cfg.enable {
    # Enable doas with wheel group rule
    security.doas.enable = true;
    security.doas.extraRules = [
      {
        groups = [ "wheel" ];
        persist = true;
        keepEnv = true;
      }
    ];

    # Disable sudo -- doas replaces it
    security.sudo.enable = false;

    # Shell alias so scripts expecting `sudo` use doas instead
    environment.shellAliases.sudo = "doas";
  };
}
