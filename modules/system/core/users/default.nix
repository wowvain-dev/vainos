# User accounts: wowvain user and root SSH keys (migrated from hosts/common/users.nix)
{ config, lib, pkgs, ... }:

let
  cfg = config.systemSettings.core.users;
in
{
  options.systemSettings.core.users = {
    enable = lib.mkEnableOption "wowvain user and root SSH key configuration" // { default = true; };
  };

  config = lib.mkIf cfg.enable {
    users.users.wowvain = {
      isNormalUser = true;
      shell = pkgs.zsh;
      extraGroups = lib.mkDefault [ "wheel" ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILcxrMxPWHixXIWknswA7O/4ScrxNO2H3c9E5TmofKi9 wowva@vain_main"
      ];
    };

    # Root SSH access for remote deployment (nixos-rebuild --target-host)
    users.users.root.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILcxrMxPWHixXIWknswA7O/4ScrxNO2H3c9E5TmofKi9 wowva@vain_main"
    ];
  };
}
