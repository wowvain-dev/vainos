{ ... }:
{
  programs.kitty = {
    enable = true;

    font = {
      name = "JetBrainsMono Nerd Font";
      size = 12;
    };

    settings = {
      scrollback_lines = 10000;
      enable_audio_bell = false;
      window_padding_width = 4;
      background_opacity = "0.95";
    };

    shellIntegration.enableBashIntegration = true;
  };
}
