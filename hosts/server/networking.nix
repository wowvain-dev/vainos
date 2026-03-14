{ machineConfig, ... }:
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
    hostName = "server";
    useDHCP = false;
    usePredictableInterfaceNames = false;

    interfaces.${machineConfig.interface} = {
      ipv4.addresses = [{
        address = machineConfig.ipv4.address;
        prefixLength = machineConfig.ipv4.prefixLength;
      }];
      ipv4.routes = [{
        address = machineConfig.ipv4.gatewayRoute;
        prefixLength = 32;
      }];
      ipv6.addresses = machineConfig.ipv6.addresses;
    };

    defaultGateway = {
      address = machineConfig.ipv4.gateway;
      interface = machineConfig.interface;
    };
    defaultGateway6 = {
      address = machineConfig.ipv6.gateway;
      interface = machineConfig.interface;
    };
    nameservers = machineConfig.nameservers;

    # Firewall -- deny by default, allow only SSH + HTTP + HTTPS
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 80 443 ];
    };
  };
}
