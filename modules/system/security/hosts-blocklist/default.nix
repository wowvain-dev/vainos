# Ad-blocking hosts file -- StevenBlack unified hosts list applied system-wide
{ config, lib, pkgs, ... }:

let
  cfg = config.systemSettings.security.hosts-blocklist;
in
{
  options.systemSettings.security.hosts-blocklist = {
    enable = lib.mkEnableOption "ad-blocking via StevenBlack hosts file";
  };

  config = lib.mkIf cfg.enable {
    networking.extraHosts =
      builtins.readFile "${pkgs.stevenblack-blocklist}/alternates/fakenews-gambling/hosts";
  };
}
