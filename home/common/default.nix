{ ... }:
{
  imports = [
    ./shell.nix
    ./git.nix
    ./neovim.nix
    ./dev-tools.nix
  ];

  home.stateVersion = "25.11";
  programs.home-manager.enable = true;
}
