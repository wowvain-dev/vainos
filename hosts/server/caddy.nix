{ ... }:
{
  services.caddy = {
    enable = true;

    # Pattern 1: Reverse proxy to containerized app
    virtualHosts."http://46.224.225.195".extraConfig = ''
      reverse_proxy http://127.0.0.1:3000
    '';

    # Pattern 2: Static file server for WASM/static sites
    # Uncomment and configure when deploying a static site (e.g., Trunk/Yew WASM app):
    #
    # virtualHosts."static.example.com".extraConfig = ''
    #   root * /srv/www/static-site
    #   encode gzip
    #   file_server
    # '';
  };

  # Create the static site directory so the pattern is ready to use
  # When deploying a static site, place built files in /srv/www/<site-name>/
  systemd.tmpfiles.rules = [
    "d /srv/www 0755 root root -"
  ];
}
