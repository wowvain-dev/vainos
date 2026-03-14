{ ... }:
{
  programs.git = {
    enable = true;
    userName = "wowvain-dev";      # GitHub username
    userEmail = "TODO@example.com"; # TODO: replace with actual email
    aliases = {
      co = "checkout";
      ci = "commit";
      st = "status";
      br = "branch";
      lg = "log --oneline --graph --decorate";
    };
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
    };
  };
}
