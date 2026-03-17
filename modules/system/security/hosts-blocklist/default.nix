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
    # Primary approach: use stevenblack-blocklist package to merge into /etc/hosts.
    # This fetches the StevenBlack unified hosts file at build time and blocks
    # ad-serving/malware domains by resolving them to 0.0.0.0.
    networking.extraHosts =
      builtins.readFile (
        pkgs.stevenblack-blocklist.override {
          include = [ "fakenews" "gambling" ];
        }
        + "/hosts"
      );

    # Alternative (if networking.stevenBlackHosts is available in nixpkgs):
    #   networking.stevenBlackHosts.enable = true;
    # That option is cleaner but may not exist in all nixpkgs versions.
  };
}
