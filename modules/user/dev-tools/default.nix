# Dev tools user module -- CLI tools + language toolchains via Home Manager
{ config, lib, pkgs, ... }:

let
  cfg = config.userSettings.devTools;
in
{
  options.userSettings.devTools = {
    enable = lib.mkEnableOption "development tools and language toolchains" // { default = true; };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.wowvain = {
      home.packages = with pkgs; [
        # --- CLI tools (DEV-04) ---
        # Note: curl, wget, htop, tree already in hosts/common/packages.nix
        ripgrep     # rg -- fast grep
        fd          # fd -- fast find
        jq          # JSON processor

        # --- JavaScript/TypeScript (DEV-05) ---
        nodejs
        nodePackages.typescript

        # --- Rust (DEV-06) ---
        # Using nixpkgs stable toolchain (not rustup -- avoids FHS issues on NixOS)
        cargo
        rustc
        rustfmt
        clippy
        # rust-analyzer already in neovim.nix extraPackages

        # --- Go (DEV-07) ---
        go

        # --- Python (DEV-08) ---
        # Note: pip install only works inside venvs on NixOS (no global pip)
        python3

        # --- C/C++ (DEV-09) ---
        gcc
        (lib.setPrio 20 clang)  # lower priority than gcc to avoid bin/c++ conflict
        cmake
        gnumake

        # --- Haskell (DEV-10) ---
        ghc
        cabal-install

        # --- Lua (DEV-11) ---
        lua
        luarocks

        # --- Dart (DEV-12) ---
        dart

        # --- Java (DEV-13) ---
        jdk     # defaults to latest OpenJDK

        # --- Odin (DEV-14) ---
        odin

        # --- Zig (DEV-15) ---
        zig
        zls         # zig language server

        # --- Nim (DEV-16) ---
        nim
        nimble      # nim package manager

        # --- Elixir (DEV-17) ---
        elixir      # includes Erlang/OTP as a dependency
        erlang      # explicit Erlang for shell access (erl)

        # --- Ruby (DEV-18) ---
        ruby
        bundler     # ruby dependency manager
      ];
    };
  };
}
