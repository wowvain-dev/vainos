{ lib, ... }:
{
  users.users.wowvain = {
    isNormalUser = true;
    extraGroups = lib.mkDefault [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILcxrMxPWHixXIWknswA7O/4ScrxNO2H3c9E5TmofKi9 wowva@vain_main"
    ];
  };

  # Root SSH access for remote deployment (nixos-rebuild --target-host)
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILcxrMxPWHixXIWknswA7O/4ScrxNO2H3c9E5TmofKi9 wowva@vain_main"
  ];
}
