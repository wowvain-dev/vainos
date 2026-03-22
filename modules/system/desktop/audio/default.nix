# Desktop audio module — PipeWire + Wave Link-style virtual channels + Elgato XLR
{ config, lib, pkgs, ... }:

let
  cfg = config.systemSettings.desktop.audio;

  # Virtual channel definitions for Wave Link-style mixing
  # Each channel becomes a virtual sink that apps can route to.
  # All channels feed into both Monitor (headphones) and Stream (OBS) mixes.
  channels = [
    { name = "Music";   desc = "Music (Spotify, players)"; }
    { name = "Game";    desc = "Game Audio (Steam, etc.)"; }
    { name = "Chat";    desc = "Chat (Discord, Zoom)"; }
    { name = "Browser"; desc = "Browser Audio"; }
    { name = "System";  desc = "System Sounds (catch-all)"; }
  ];

  # Generate null-audio-sink objects for each channel
  channelSinks = map (ch: {
    factory = "adapter";
    args = {
      "factory.name" = "support.null-audio-sink";
      "node.name" = "channel_${ch.name}";
      "node.description" = ch.desc;
      "media.class" = "Audio/Sink";
      "audio.position" = "FL,FR";
      "monitor.channel-volumes" = true;
    };
  }) channels;

  # Stream mix sink — OBS captures this to get all channel audio
  streamSink = {
    factory = "adapter";
    args = {
      "factory.name" = "support.null-audio-sink";
      "node.name" = "stream_mix";
      "node.description" = "Stream Mix (OBS capture)";
      "media.class" = "Audio/Sink";
      "audio.position" = "FL,FR";
      "monitor.channel-volumes" = true;
    };
  };

  # Generate loopback modules that route each channel → default output (Monitor)
  monitorLoopbacks = map (ch: {
    name = "libpipewire-module-loopback";
    args = {
      "node.description" = "${ch.name} → Monitor";
      "capture.props" = {
        "node.name" = "monitor_capture_${ch.name}";
        "audio.position" = "FL,FR";
        "stream.dont-remix" = true;
        "stream.capture.sink" = true;
        "node.passive" = true;
        "target.object" = "channel_${ch.name}";
      };
      "playback.props" = {
        "node.name" = "monitor_playback_${ch.name}";
        "audio.position" = "FL,FR";
        "node.dont-fallback" = true;
        "stream.dont-remix" = true;
      };
    };
  }) channels;

  # Mic monitor loopback — hear yourself through headphones (mono → stereo)
  # The Elgato XLR mic is mono; without explicit remixing, monitoring only plays in left ear.
  # Captures from default source (Elgato XLR), plays back to default sink with MONO→stereo upmix.
  micMonitorLoopback = {
    name = "libpipewire-module-loopback";
    args = {
      "node.description" = "Mic → Monitor";
      "audio.channels" = 2;
      "audio.position" = "FL,FR";
      "capture.props" = {
        "node.name" = "mic_monitor_capture";
        "audio.channels" = 1;
        "audio.position" = "MONO";
        "node.passive" = true;
        "stream.dont-remix" = true;
      };
      "playback.props" = {
        "node.name" = "mic_monitor_playback";
        "audio.channels" = 2;
        "audio.position" = "FL,FR";
        "stream.dont-remix" = false;
        "node.passive" = true;
        "node.dont-fallback" = true;
      };
    };
  };

  # Generate loopback modules that route each channel → Stream mix (for OBS)
  streamLoopbacks = map (ch: {
    name = "libpipewire-module-loopback";
    args = {
      "node.description" = "${ch.name} → Stream";
      "capture.props" = {
        "node.name" = "stream_capture_${ch.name}";
        "audio.position" = "FL,FR";
        "stream.dont-remix" = true;
        "stream.capture.sink" = true;
        "node.passive" = true;
        "target.object" = "channel_${ch.name}";
      };
      "playback.props" = {
        "node.name" = "stream_playback_${ch.name}";
        "audio.position" = "FL,FR";
        "node.dont-fallback" = true;
        "stream.dont-remix" = true;
        "target.object" = "stream_mix";
      };
    };
  }) channels;

in
{
  options.systemSettings.desktop.audio = {
    enable = lib.mkEnableOption "PipeWire audio with WirePlumber Bluetooth support";

    virtualChannels = lib.mkEnableOption "Wave Link-style virtual audio channels for streaming";
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    # --- Base PipeWire audio ---
    {
      security.rtkit.enable = true;

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

      # Audio control tools
      environment.systemPackages = with pkgs; [
        pavucontrol # PulseAudio volume control — route apps to channels
        pwvucontrol # PipeWire volume control (native, modern alternative)
      ];
    }

    # --- Wave Link-style virtual channels ---
    (lib.mkIf cfg.virtualChannels {
      services.pipewire.extraConfig.pipewire = {
        # Virtual channel sinks — apps route to these
        "91-virtual-channels" = {
          "context.objects" = channelSinks ++ [ streamSink ];
        };

        # Loopback routing: each channel → Monitor (default output) + Stream mix
        "92-channel-routing" = {
          "context.modules" = monitorLoopbacks ++ streamLoopbacks ++ [ micMonitorLoopback ];
        };
      };

      environment.systemPackages = with pkgs; [
        helvum       # Graphical PipeWire patchbay — connect/disconnect audio nodes
        easyeffects  # Mic processing: noise gate, compressor, EQ, de-esser
      ];
    })
  ]);
}
