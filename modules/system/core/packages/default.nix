# Base system packages (migrated from hosts/common/packages.nix)
{ config, lib, pkgs, ... }:

let
  cfg = config.systemSettings.core.packages;
in
{
  options.systemSettings.core.packages = {
    enable = lib.mkEnableOption "base system packages (vim, git, curl, wget, htop, tree)" // { default = true; };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      vim
      git
      curl
      wget
      htop
      tree
    ];
  };
}
