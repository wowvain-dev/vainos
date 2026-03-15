# Example user module -- demonstrates the canonical vainos user module pattern.
# User modules are NixOS modules that set Home Manager config via home-manager.users.wowvain.
# Copy this directory to create a new user module.
# Delete this module once real modules exist in Phase 5.
{ config, lib, pkgs, ... }:

let
  cfg = config.userSettings.example;
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
    # User modules set Home Manager config at the NixOS level
    home-manager.users.wowvain.home.file.".vainos-example".text = cfg.editorTheme;
  };
}
