# Desktop audio module — PipeWire + WirePlumber + Elgato XLR fix
# Migrated from hosts/workstation/desktop.nix (PipeWire portion)
{ config, lib, ... }:

let
  cfg = config.systemSettings.desktop.audio;
in
{
  options.systemSettings.desktop.audio = {
    enable = lib.mkEnableOption "PipeWire audio with WirePlumber Bluetooth support";
  };

  config = lib.mkIf cfg.enable {
    # Real-time audio scheduling
    security.rtkit.enable = true;

    # PipeWire audio
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;

      # Bluetooth audio codec support (A2DP, HSP/HFP)
      wireplumber.extraConfig."10-bluez" = {
        "monitor.bluez.properties" = {
          "bluez5.enable-sbc-xq" = true;
          "bluez5.enable-msbc" = true;
          "bluez5.enable-hw-volume" = true;
          "bluez5.roles" = [ "hsp_hs" "hsp_ag" "hfp_hf" "hfp_ag" ];
        };
      };

      # Elgato Wave XLR / XLR Dock mic fix
      # Without this, the mic produces no audio when playback is also active.
      # Setting node.always-process = true on the input node forces the mic
      # capture to stay active regardless of playback state.
      # Source: https://github.com/jmansar/wavexlr-on-linux-cfg
      wireplumber.extraConfig."51-elgato-xlr" = {
        "monitor.alsa.rules" = [
          {
            matches = [
              { "node.name" = "~alsa_input.usb-Elgato_Systems_Elgato_Wave_XLR_*"; }
            ];
            actions.update-props = {
              "node.always-process" = true;
            };
          }
          {
            matches = [
              { "node.name" = "~alsa_input.usb-Elgato_Systems_Elgato_XLR_Dock*"; }
            ];
            actions.update-props = {
              "node.always-process" = true;
            };
          }
        ];
      };
    };
  };
}
