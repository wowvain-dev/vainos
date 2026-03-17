# kaaldur.com static site -- SvelteKit adapter-static served by Caddy
{ config, lib, pkgs, ... }:

let
  cfg = config.systemSettings.server.sites.kaaldur-com;
in
{
  options.systemSettings.server.sites.kaaldur-com = {
    enable = lib.mkEnableOption "kaaldur.com static site (SvelteKit)";
  };

  config = lib.mkIf cfg.enable {
    # Caddy virtual hosts -- apex domain serves static files, www redirects
    services.caddy.virtualHosts = {
      "kaaldur.com" = {
        extraConfig = ''
          root * /srv/sites/www/kaaldur.com
          encode gzip
          try_files {path} /index.html
          file_server
        '';
      };
      "www.kaaldur.com" = {
        extraConfig = ''
          redir https://kaaldur.com{uri} permanent
        '';
      };
    };

    # Site-specific directories (children of deploy module's /srv/sites/ tree)
    systemd.tmpfiles.rules = [
      "d /srv/sites/src/kaaldur.com 0755 root root -"
      "d /srv/sites/www/kaaldur.com 0755 root caddy -"
    ];

    # Deploy service -- clone/pull, build, copy to www
    systemd.services.deploy-kaaldur-com = {
      description = "Deploy kaaldur.com static site from git";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      path = [ pkgs.git pkgs.nodejs pkgs.coreutils pkgs.openssh ];
      script = ''
        set -euo pipefail
        SRC="/srv/sites/src/kaaldur.com"
        WWW="/srv/sites/www/kaaldur.com"

        # Auto-clone if repo not present
        NEEDS_BUILD=false
        if [ ! -d "$SRC/.git" ]; then
          echo "deploy-kaaldur-com: cloning repository"
          git clone git@github.com:KaaldurSoftworks/website.git "$SRC"
          NEEDS_BUILD=true
        fi

        # Force build if www has no index.html (first deploy or cleared output)
        if [ ! -f "$WWW/index.html" ]; then
          NEEDS_BUILD=true
        fi

        cd "$SRC"
        git fetch origin master

        LOCAL=$(git rev-parse HEAD)
        REMOTE=$(git rev-parse origin/master)

        if [ "$LOCAL" = "$REMOTE" ] && [ "$NEEDS_BUILD" = "false" ]; then
          echo "deploy-kaaldur-com: no new commits, skipping build"
          exit 0
        fi

        echo "deploy-kaaldur-com: new commits detected, building..."
        git reset --hard origin/master

        npm ci
        npm run build

        # Verify build output exists
        if [ ! -f build/index.html ]; then
          echo "deploy-kaaldur-com: ERROR - build/index.html not found" >&2
          exit 1
        fi

        # Deploy: clear old content, copy new
        rm -rf "$WWW"/*
        cp -r build/* "$WWW"/
        chown -R root:caddy "$WWW"

        echo "deploy-kaaldur-com: deployed $(git rev-parse --short HEAD)"
      '';
    };

    # Deploy timer -- check for updates every 15 minutes
    systemd.timers.deploy-kaaldur-com = {
      description = "Timer for kaaldur.com deployment";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5m";
        OnUnitActiveSec = "15m";
        Persistent = true;
      };
    };
  };
}
