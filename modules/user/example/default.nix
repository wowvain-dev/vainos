# Example user module — demonstrates the canonical vainos module pattern for Home Manager.
# Copy this directory to create a new user module.
# Delete this module once real modules exist in Phase 5.
{ config, lib, pkgs, ... }:

let
  cfg = config.userSettings.example;  # Read from userSettings namespace
in
{
  options.userSettings.example = {
    enable = lib.mkEnableOption "example user module";

    editorTheme = lib.mkOption {
      type = lib.types.str;
      default = "gruvbox";
      description = "Example string option to demonstrate typed sub-options.";
    };
  };

  config = lib.mkIf cfg.enable {
    # This block only applies when userSettings.example.enable = true
    # Real modules put Home Manager config here: programs, services, files, etc.
    home.file.".vainos-example".text = cfg.editorTheme;
  };
}
