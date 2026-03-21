# Claude Code CLI — AI coding assistant
# Uses sadjow/claude-code-nix flake for always up-to-date native binary
{ config, lib, pkgs, inputs, ... }:

let
  cfg = config.systemSettings.core.claude-code;
in
{
  options.systemSettings.core.claude-code = {
    enable = lib.mkEnableOption "Claude Code CLI";
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [ inputs.claude-code.overlays.default ];
    environment.systemPackages = [ pkgs.claude-code ];
  };
}
