{ ... }:
{
  imports = [
    ./nix.nix
    ./locale.nix
    ./users.nix
    ./packages.nix
  ];

  # Required for Home Manager zsh to work properly (vendor completions, /etc/shells)
  programs.zsh.enable = true;
}
