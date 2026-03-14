{ ... }:
{
  # Bluetooth hardware and management (WS-14)
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General.Enable = "Source,Sink,Media,Socket";
  };

  # Blueman applet and manager for GUI Bluetooth pairing
  services.blueman.enable = true;
}
