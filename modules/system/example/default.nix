# Example system module — demonstrates the canonical vainos module pattern.
# Copy this directory to create a new system module.
# Delete this module once real modules exist in Phase 5.
{ config, lib, pkgs, ... }:

let
  cfg = config.systemSettings.example;  # Read from systemSettings namespace
in
{
  options.systemSettings.example = {
    enable = lib.mkEnableOption "example system module";

    greeting = lib.mkOption {
      type = lib.types.str;
      default = "Hello from vainos";
      description = "Example string option to demonstrate typed sub-options.";
    };
  };

  config = lib.mkIf cfg.enable {
    # This block only applies when systemSettings.example.enable = true
    # Real modules put NixOS config here: services, networking, boot, etc.
    environment.etc."vainos-example".text = cfg.greeting;
  };
}
