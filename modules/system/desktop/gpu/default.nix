# Desktop GPU module — AMD GPU drivers
# Migrated from hosts/workstation/gpu.nix
#
# TODO: This defaults to AMD GPU drivers. If your workstation has an NVIDIA GPU,
# replace the config block contents with the NVIDIA variant below:
#
# NVIDIA variant:
#   config = lib.mkIf cfg.enable {
#     hardware.graphics.enable = true;
#     services.xserver.videoDrivers = [ "nvidia" ];
#     hardware.nvidia = {
#       modesetting.enable = true;  # Required for Wayland/Hyprland
#       open = true;                # For Turing+ (RTX 20 series or newer)
#       # open = false;             # Uncomment for older GPUs (GTX 10 series or older)
#     };
#   };
#
# To identify your GPU: lspci | grep -i vga
{ config, lib, ... }:

let
  cfg = config.systemSettings.desktop.gpu;
in
{
  options.systemSettings.desktop.gpu = {
    enable = lib.mkEnableOption "AMD GPU drivers";
  };

  config = lib.mkIf cfg.enable {
    # AMD GPU -- Mesa RADV Vulkan driver is used automatically
    hardware.graphics = {
      enable = true;
      enable32Bit = true; # 32-bit support for Steam/Wine compatibility
    };

    # Load amdgpu kernel module early in initrd for console output
    hardware.amdgpu.initrd.enable = true;
  };
}
