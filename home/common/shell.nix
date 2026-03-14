{ ... }:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
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
}
