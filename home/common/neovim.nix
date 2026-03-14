{ pkgs, inputs, ... }:
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    extraPackages = with pkgs; [
      # Runtime deps for Treesitter grammar compilation
      gcc
      tree-sitter
      # LSPs that vainim expects (available in PATH, bypasses mason.nvim on NixOS)
      lua-language-server
      basedpyright
      nodePackages.typescript-language-server
      vscode-langservers-extracted  # html, css, json, eslint
      yaml-language-server
      bash-language-server
      rust-analyzer
      gopls
      clang-tools    # provides clangd
      ols            # odin language server
      marksman       # markdown
      # Formatters
      stylua
      prettierd
      nodePackages.prettier
    ];
    # IMPORTANT: Do NOT set extraLuaConfig or plugins -- vainim manages its own config via lazy.nvim
  };

  # Symlink vainim config to ~/.config/nvim
  xdg.configFile."nvim".source = inputs.vainim;
}
