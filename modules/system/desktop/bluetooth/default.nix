# Desktop Bluetooth module — hardware support and Blueman manager
# Migrated from hosts/workstation/bluetooth.nix
{ config, lib, ... }:

let
  cfg = config.systemSettings.desktop.bluetooth;
in
{
  options.systemSettings.desktop.bluetooth = {
    enable = lib.mkEnableOption "Bluetooth hardware and Blueman manager";
  };

  config = lib.mkIf cfg.enable {
    # Bluetooth hardware and management
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings.General.Enable = "Source,Sink,Media,Socket";
    };

    # Blueman applet and manager for GUI Bluetooth pairing
    services.blueman.enable = true;
  };
}
