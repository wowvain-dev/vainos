# Nix settings: flakes, GC, auto-optimise-store (migrated from hosts/common/nix.nix)
{ config, lib, ... }:

let
  cfg = config.systemSettings.core.nix;
in
{
  options.systemSettings.core.nix = {
    enable = lib.mkEnableOption "nix flakes and garbage collection settings" // { default = true; };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.config.allowUnfree = true;

    nix = {
      settings = {
        experimental-features = [ "nix-command" "flakes" ];
        auto-optimise-store = true;
      };
      gc = {
        automatic = lib.mkDefault true;
        dates = lib.mkDefault "weekly";
        options = lib.mkDefault "--delete-older-than 30d";
      };
    };
  };
}
