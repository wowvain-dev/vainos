# wowvain.com container site -- Axum backend + Yew/WASM frontend via Podman
{ config, lib, pkgs, ... }:

let
  cfg = config.systemSettings.server.sites.wowvain-com;
in
{
  options.systemSettings.server.sites.wowvain-com = {
    enable = lib.mkEnableOption "wowvain.com container site (Axum + Yew/WASM)";
  };

  config = lib.mkIf cfg.enable {
    # Caddy virtual hosts -- apex domain reverse-proxies to container, www redirects
    services.caddy.virtualHosts = {
      "wowvain.com" = {
        extraConfig = ''
          encode gzip
          reverse_proxy 127.0.0.1:3001
        '';
      };
      "www.wowvain.com" = {
        extraConfig = ''
          redir https://wowvain.com{uri} permanent
        '';
      };
    };

    # Podman container definition
    virtualisation.oci-containers.backend = "podman";
    virtualisation.oci-containers.containers.wowvain-com = {
      image = "wowvain-com:latest";
      ports = [ "127.0.0.1:3001:3001" ];
      pull = "never";
      environmentFiles = [
        config.sops.secrets.wowvain-env.path
      ];
    };

    # Sops secret for container environment
    sops.secrets.wowvain-env = {
      sopsFile = ../../../../../secrets/wowvain-env.yaml;
      format = "dotenv";
    };

    # Site source directory (no www/ needed -- container serves directly)
    systemd.tmpfiles.rules = [
      "d /srv/sites/src/wowvain.com 0755 root root -"
    ];

    # Deploy service -- clone/pull, build container image, restart
    systemd.services.deploy-wowvain-com = {
      description = "Deploy wowvain.com container from git";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      path = [ pkgs.git pkgs.podman pkgs.coreutils pkgs.openssh pkgs.bash pkgs.systemd pkgs.gawk pkgs.gnused ];
      script = ''
        set -euo pipefail
        SRC="/srv/sites/src/wowvain.com"
        IMAGE="wowvain-com:latest"

        # Auto-clone if repo not present (DEPLOY-05)
        NEEDS_BUILD=false
        if [ ! -d "$SRC/.git" ]; then
          echo "deploy-wowvain-com: cloning repository"
          git clone git@github.com:wowvain-dev/website.git "$SRC"
          NEEDS_BUILD=true
        fi

        # Force build if no image exists yet
        if ! podman image exists "$IMAGE"; then
          NEEDS_BUILD=true
        fi

        cd "$SRC"
        git fetch origin

        # Detect default branch from local ref (set by clone/fetch, no network needed)
        DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
        if [ -z "$DEFAULT_BRANCH" ]; then
          DEFAULT_BRANCH="master"
        fi

        LOCAL=$(git rev-parse HEAD)
        REMOTE=$(git rev-parse "origin/$DEFAULT_BRANCH")

        if [ "$LOCAL" = "$REMOTE" ] && [ "$NEEDS_BUILD" = "false" ]; then
          echo "deploy-wowvain-com: no new commits, skipping build"
          exit 0
        fi

        echo "deploy-wowvain-com: new commits detected, building..."
        git reset --hard "$REMOTE"

        if podman build -t "$IMAGE" .; then
          echo "deploy-wowvain-com: build successful, restarting container"
          systemctl restart podman-wowvain-com
          echo "deploy-wowvain-com: deployed $(git rev-parse --short HEAD)"
        else
          echo "deploy-wowvain-com: ERROR - build failed, keeping existing container" >&2
          exit 1
        fi
      '';
    };

    # Deploy timer -- check for updates every 30 minutes
    systemd.timers.deploy-wowvain-com = {
      description = "Timer for wowvain.com deployment";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5m";
        OnUnitActiveSec = "30m";
        Persistent = true;
      };
    };
  };
}
