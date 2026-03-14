{ lib, ... }:
{
  users.users.wowvain = {
    isNormalUser = true;
    extraGroups = lib.mkDefault [ "wheel" ];
    # SSH authorized keys can be added per-host or via sops-nix
  };

  # Root SSH access for remote deployment (nixos-rebuild --target-host)
  # TODO: Replace PLACEHOLDER_SSH_KEY with your actual ed25519 public key
  users.users.root.openssh.authorizedKeys.keys = [
    "PLACEHOLDER_SSH_KEY"
  ];
}
