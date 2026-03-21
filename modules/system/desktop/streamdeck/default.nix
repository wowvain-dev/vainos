# Desktop Stream Deck module -- OpenDeck via Flatpak + udev rules
# OpenDeck supports original Elgato SDK plugins (Discord, OBS, etc.)
# unlike streamdeck-ui which only supports macros/scripts.
{ config, lib, pkgs, ... }:

let
  cfg = config.systemSettings.desktop.streamdeck;
in
{
  options.systemSettings.desktop.streamdeck = {
    enable = lib.mkEnableOption "Elgato Stream Deck support (OpenDeck via Flatpak)";
  };

  config = lib.mkIf cfg.enable {
    # Flatpak for OpenDeck (me.amankhanna.opendeck on Flathub)
    services.flatpak.enable = true;

    # XDG Desktop Portal for Flatpak app integration with Hyprland
    xdg.portal.enable = true;

    # Auto-add Flathub repo on first boot
    systemd.services.flatpak-repo = {
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.flatpak ];
      script = ''
        flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
      '';
    };

    # Stream Deck udev rules — required even with Flatpak
    # Grants user access to Elgato Stream Deck USB devices
    services.udev.extraRules = ''
      # Elgato Stream Deck Mini
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0063", TAG+="uaccess"
      # Elgato Stream Deck Mini (v2)
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0090", TAG+="uaccess"
      # Elgato Stream Deck Original
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0060", TAG+="uaccess"
      # Elgato Stream Deck Original (v2)
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006d", TAG+="uaccess"
      # Elgato Stream Deck MK.2
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0080", TAG+="uaccess"
      # Elgato Stream Deck XL
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="006c", TAG+="uaccess"
      # Elgato Stream Deck XL (v2)
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="008f", TAG+="uaccess"
      # Elgato Stream Deck Pedal
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0086", TAG+="uaccess"
      # Elgato Stream Deck Plus
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="0084", TAG+="uaccess"
      # Elgato Stream Deck Neo
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", ATTRS{idProduct}=="009a", TAG+="uaccess"
    '';

    # Wine for running Windows-only Stream Deck plugins
    environment.systemPackages = with pkgs; [
      wine-wayland
    ];
  };
}
