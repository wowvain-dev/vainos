# Desktop Stream Deck module -- Elgato Stream Deck button pad support
{ config, lib, ... }:

let
  cfg = config.systemSettings.desktop.streamdeck;
in
{
  options.systemSettings.desktop.streamdeck = {
    enable = lib.mkEnableOption "Elgato Stream Deck support (streamdeck-ui)";
  };

  config = lib.mkIf cfg.enable {
    # streamdeck-ui with udev rules for device access
    programs.streamdeck-ui = {
      enable = true;
      autoStart = true;
    };
  };
}
