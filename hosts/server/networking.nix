{ config, ... }:
let
  net = config.systemSettings.networking;
in
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

  # Networking -- static IP configuration
  networking = {
    useDHCP = false;
    usePredictableInterfaceNames = false;

    interfaces.${net.interface} = {
      ipv4.addresses = [{
        address = net.ipv4.address;
        prefixLength = net.ipv4.prefixLength;
      }];
      ipv4.routes = [{
        address = net.ipv4.gatewayRoute;
        prefixLength = 32;
      }];
      ipv6.addresses = net.ipv6.addresses;
    };

    defaultGateway = {
      address = net.ipv4.gateway;
      interface = net.interface;
    };
    defaultGateway6 = {
      address = net.ipv6.gateway;
      interface = net.interface;
    };
    nameservers = net.nameservers;

    # Firewall -- deny by default, allow only SSH + HTTP + HTTPS
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 80 443 ];
    };
  };
}
