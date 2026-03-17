# Automatic flake input updates via systemd timer
{ config, lib, pkgs, ... }:

let
  cfg = config.systemSettings.maintenance.autoUpdate;
in
{
  options.systemSettings.maintenance.autoUpdate = {
    enable = lib.mkEnableOption "automatic flake input updates via systemd timer";

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "weekly";
      description = "systemd calendar expression for update frequency";
    };

    flakeDir = lib.mkOption {
      type = lib.types.str;
      default = "/etc/nixos";
      description = "path to the flake directory";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.vainos-auto-update = {
      description = "Auto-update vainos flake inputs";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "vainos-auto-update" ''
          echo "vainos-auto-update: updating flake inputs in ${cfg.flakeDir}"
          if nix flake update --flake "${cfg.flakeDir}"; then
            echo "vainos-auto-update: flake inputs updated successfully"
          else
            echo "vainos-auto-update: failed to update flake inputs" >&2
            exit 1
          fi
        '';
      };
      path = [ pkgs.nix pkgs.git ];
    };

    systemd.timers.vainos-auto-update = {
      description = "Timer for vainos flake input auto-update";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true;
        RandomizedDelaySec = "6h";
      };
    };
  };
}
