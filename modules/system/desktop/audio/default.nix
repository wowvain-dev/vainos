# Desktop audio module — PipeWire + WirePlumber Bluetooth audio
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
    };
  };
}
