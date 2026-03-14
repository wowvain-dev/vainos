{ ... }:
{
  programs.fuzzel = {
    enable = true;

    settings.main = {
      font = "JetBrainsMono Nerd Font:size=12";
      terminal = "kitty";
      layer = "overlay";
    };
  };
}
