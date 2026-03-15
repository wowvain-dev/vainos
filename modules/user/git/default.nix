# Git user module -- Git config via Home Manager
{ config, lib, ... }:

let
  cfg = config.userSettings.git;
in
{
  options.userSettings.git = {
    enable = lib.mkEnableOption "git configuration" // { default = true; };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.wowvain = {
      programs.git = {
        enable = true;
        settings = {
          user = {
            name = "wowvain-dev";      # GitHub username
            email = "wowvain.dev@gmail.com";
          };
          alias = {
            co = "checkout";
            ci = "commit";
            st = "status";
            br = "branch";
            lg = "log --oneline --graph --decorate";
          };
          init.defaultBranch = "main";
          pull.rebase = true;
          push.autoSetupRemote = true;
          safe.directory = "/home/wowvain/.vainos";
        };
      };
    };
  };
}
