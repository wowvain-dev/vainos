# Login notification when flake inputs are newer than running system
{ config, lib, ... }:

let
  cfg = config.userSettings.updateNotify;
in
{
  options.userSettings.updateNotify = {
    enable = lib.mkEnableOption "shell login notification for pending updates" // { default = true; };

    flakeDir = lib.mkOption {
      type = lib.types.str;
      default = "/etc/nixos";
      description = "path to the flake directory to check for updates";
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.wowvain = {
      programs.zsh.initExtra = ''
        # vainos update notification -- check if flake inputs are newer than system profile
        if [[ -o login ]]; then
          _vainos_flake_lock="${cfg.flakeDir}/flake.lock"
          _vainos_system_profile="/nix/var/nix/profiles/system"
          if [[ -f "$_vainos_flake_lock" ]] && [[ -e "$_vainos_system_profile" ]]; then
            _vainos_lock_mtime="$(stat -c %Y "$_vainos_flake_lock" 2>/dev/null)" || true
            _vainos_profile_mtime="$(stat -c %Y "$_vainos_system_profile" 2>/dev/null)" || true
            if [[ -n "$_vainos_lock_mtime" ]] && [[ -n "$_vainos_profile_mtime" ]]; then
              if (( _vainos_lock_mtime > _vainos_profile_mtime )); then
                echo "[vainos] Flake inputs updated -- run 'vainos sync' to apply"
              fi
            fi
          fi
          unset _vainos_flake_lock _vainos_system_profile _vainos_lock_mtime _vainos_profile_mtime
        fi
      '';
    };
  };
}
