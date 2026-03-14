{ ... }:
{
  # SSH hardening -- key-only auth
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password"; # NOT "no" -- deployment needs key-based root SSH
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  # Brute-force protection
  services.fail2ban = {
    enable = true;
    maxretry = 5;
    bantime = "1h";
    bantime-increment = {
      enable = true;
      maxtime = "168h"; # 1 week max ban
    };
  };

  # Networking -- static IP configuration (matches Hetzner server setup)
  networking = {
    hostName = "server";
    useDHCP = false;
    usePredictableInterfaceNames = false;

    interfaces.eth0 = {
      ipv4.addresses = [{ address = "46.224.225.195"; prefixLength = 32; }];
      ipv4.routes = [{ address = "172.31.1.1"; prefixLength = 32; }];
      ipv6.addresses = [
        { address = "2a01:4f8:1c19:452b::1"; prefixLength = 64; }
        { address = "2a01:4f8:1c19:452b::2"; prefixLength = 64; }
      ];
    };

    defaultGateway = { address = "172.31.1.1"; interface = "eth0"; };
    defaultGateway6 = { address = "fe80::1"; interface = "eth0"; };
    nameservers = [ "185.12.64.1" "185.12.64.2" ];

    # Firewall -- deny by default, allow only SSH + HTTP + HTTPS
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 80 443 ];
    };
  };
}
