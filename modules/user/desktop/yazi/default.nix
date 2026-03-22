# Yazi user module -- Yazi terminal file manager via Home Manager
{ config, lib, pkgs, ... }:

let
  cfg = config.userSettings.desktop.yazi;
  vainos-trash = pkgs.writeShellScriptBin "vainos-trash" (builtins.readFile ./vainos-trash.sh);
in
{
  options.userSettings.desktop.yazi = {
    enable = lib.mkEnableOption "yazi terminal file manager";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.wowvain = {
      programs.yazi = {
        enable = true;

        # Shell integration enables cd-on-exit: when quitting yazi,
        # the terminal directory changes to where yazi was browsing.
        # This works by creating a shell function that wraps the yazi
        # binary and reads its --cwd-file output to cd on exit.
        enableZshIntegration = true;

        settings = {
          manager = {
            # Show hidden files by default
            show_hidden = true;
            # Sort directories before files
            sort_dir_first = true;
          };
        };

        keymap = {
          manager.prepend_keymap = [
            {
              on = [ "d" ];
              run = ''shell 'vainos-trash "$@"' --confirm'';
              desc = "Trash files (centralized)";
            }
          ];
        };
      };

      home.packages = [ vainos-trash ];
    };
  };
}
