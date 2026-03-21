# Desktop gaming module -- Steam, Gamemode, controller support
{ config, lib, pkgs, ... }:

let
  cfg = config.systemSettings.desktop.gaming;
in
{
  options.systemSettings.desktop.gaming = {
    enable = lib.mkEnableOption "gaming (Steam, Gamemode, controller support)";
  };

  config = lib.mkIf cfg.enable {
    # Steam with all recommended settings
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = false;
      localNetworkGameTransfers.openFirewall = true;
      gamescopeSession.enable = true;
    };

    # 32-bit graphics libraries for Steam/Wine game compatibility
    hardware.graphics.enable32Bit = true;

    # Gamemode -- performance optimization (switches governor, adjusts nice values)
    programs.gamemode.enable = true;

    # Steam controller and generic gamepad support via Steam Input
    hardware.steam-hardware.enable = true;
  };
}
