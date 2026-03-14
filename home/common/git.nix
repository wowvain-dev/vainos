{ ... }:
{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "wowvain-dev";      # GitHub username
        email = "TODO@example.com"; # TODO: replace with actual email
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
    };
  };
}
