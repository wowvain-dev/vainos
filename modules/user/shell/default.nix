# Shell user module -- Zsh + Starship via Home Manager
{ config, lib, ... }:

let
  cfg = config.userSettings.shell;
in
{
  options.userSettings.shell = {
    enable = lib.mkEnableOption "shell (zsh + starship)" // { default = true; };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.wowvain = {
      programs.zsh = {
        enable = true;
        enableCompletion = true;
        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;
        sessionVariables = {
          VAINOS_ROOT = "/etc/vainos";
        };
        history = {
          size = 10000;
          ignoreAllDups = true;
        };
        shellAliases = {
          ll = "ls -la";
          la = "ls -A";
          gs = "git status";
          gp = "git push";
          gl = "git pull";
          gd = "git diff";
          gc = "git commit";
          gco = "git checkout";
          ".." = "cd ..";
          "..." = "cd ../..";
        };
      };

      programs.starship = {
        enable = true;
        enableZshIntegration = true;
      };
    };
  };
}
