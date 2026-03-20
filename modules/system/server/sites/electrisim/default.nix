# electrisim circuit editor -- Flask API container + static frontend under kaaldur.com
{ config, lib, pkgs, ... }:

let
  cfg = config.systemSettings.server.sites.electrisim;
in
{
  options.systemSettings.server.sites.electrisim = {
    enable = lib.mkEnableOption "electrisim circuit editor (Flask API container + static frontend under kaaldur.com)";
  };

  config = lib.mkIf cfg.enable {
    # Caddy sub-path routing -- override kaaldur.com extraConfig with handle_path blocks
    # for electrisim (API + static) before the kaaldur.com catch-all handle block.
    # Uses mkForce because this module owns the full kaaldur.com extraConfig when enabled.
    services.caddy.virtualHosts."kaaldur.com".extraConfig = lib.mkForce ''
      tls internal
      encode gzip

      handle_path /tools/electrisim/api/* {
        reverse_proxy 127.0.0.1:3002
      }

      handle_path /tools/electrisim/* {
        root * /srv/sites/www/electrisim
        file_server
      }

      handle {
        root * /srv/sites/www/kaaldur.com
        try_files {path} /index.html
        file_server
      }
    '';

    # Podman container definition
    virtualisation.oci-containers.backend = "podman";
    virtualisation.oci-containers.containers.electrisim-api = {
      image = "electrisim-api:latest";
      ports = [ "127.0.0.1:3002:3002" ];
      pull = "never";
      environmentFiles = [
        config.sops.secrets.electrisim-env.path
      ];
    };

    # Sops secret for container environment
    sops.secrets.electrisim-env = {
      sopsFile = ../../../../../secrets/electrisim-env.yaml;
      format = "dotenv";
    };

    # Site directories -- source for deploy service, www for static frontend
    systemd.tmpfiles.rules = [
      "d /srv/sites/src/electrisim-api 0755 root root -"
      "d /srv/sites/www/electrisim 0755 root caddy -"
    ];

    # Deploy service -- clone/pull, build container image, restart
    systemd.services.deploy-electrisim-api = {
      description = "Deploy electrisim API container from git";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      path = [ pkgs.git pkgs.podman pkgs.coreutils pkgs.openssh pkgs.bash pkgs.systemd pkgs.gawk pkgs.gnused ];
      script = ''
        set -euo pipefail
        SRC="/srv/sites/src/electrisim-api"
        IMAGE="electrisim-api:latest"

        NEEDS_BUILD=false
        if [ ! -d "$SRC/.git" ]; then
          echo "deploy-electrisim-api: cloning repository"
          git clone git@github.com:electrisim/appElectrisimBackend.git "$SRC"
          NEEDS_BUILD=true
        fi

        if ! podman image exists "$IMAGE"; then
          NEEDS_BUILD=true
        fi

        cd "$SRC"
        git fetch origin

        DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
        if [ -z "$DEFAULT_BRANCH" ]; then
          DEFAULT_BRANCH="master"
        fi

        LOCAL=$(git rev-parse HEAD)
        REMOTE=$(git rev-parse "origin/$DEFAULT_BRANCH")

        if [ "$LOCAL" = "$REMOTE" ] && [ "$NEEDS_BUILD" = "false" ]; then
          echo "deploy-electrisim-api: no new commits, skipping build"
          exit 0
        fi

        echo "deploy-electrisim-api: new commits detected, building..."
        git reset --hard "$REMOTE"

        if podman build -t "$IMAGE" .; then
          echo "deploy-electrisim-api: build successful, restarting container"
          systemctl restart podman-electrisim-api
          echo "deploy-electrisim-api: deployed $(git rev-parse --short HEAD)"
        else
          echo "deploy-electrisim-api: ERROR - build failed, keeping existing container" >&2
          exit 1
        fi
      '';
    };

    # Deploy timer -- check for updates every 30 minutes
    systemd.timers.deploy-electrisim-api = {
      description = "Timer for electrisim API deployment";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5m";
        OnUnitActiveSec = "30m";
        Persistent = true;
      };
    };
  };
}
