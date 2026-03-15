# System-level zsh enable (migrated from hosts/common/default.nix)
# CRITICAL: This enables vendor completions and /etc/shells registration.
# Without it, Home Manager zsh integration breaks.
{ config, lib, ... }:

let
  cfg = config.systemSettings.core.zsh;
in
{
  options.systemSettings.core.zsh = {
    enable = lib.mkEnableOption "system-level zsh (vendor completions, /etc/shells)" // { default = true; };
  };

  config = lib.mkIf cfg.enable {
    programs.zsh.enable = true;
  };
}
