{ ... }:
{
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
}
