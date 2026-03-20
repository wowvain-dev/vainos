# Game server infrastructure -- registry-driven directories, firewall, config gen, OOM protection
# Games are on-demand (started by CLI in Phase 16), NOT always-on NixOS containers.
# The registry produces shell-parseable .env config files consumed by the CLI.
{ config, lib, ... }:

let
  cfg = config.systemSettings.server.games;

  # Single source of truth for all game server definitions
  games = {
    minecraft = {
      image = "itzg/minecraft-server:java21";
      ports = [
        { port = 25565; protocol = "tcp"; }
      ];
      volumes = [
        { host = "data"; container = "/data"; }
      ];
      env = {
        EULA = "TRUE";
        TYPE = "VANILLA";
        VERSION = "LATEST";
        MEMORY = "4G";
        ENABLE_RCON = "true";
        RCON_PASSWORD = "changeme";
      };
      memory = "4G";
      shutdownMethod = "rcon";
    };
    valheim = {
      image = "lloesche/valheim-server:latest";
      ports = [
        { port = 2456; protocol = "udp"; }
        { port = 2457; protocol = "udp"; }
      ];
      volumes = [
        { host = "config"; container = "/config"; }
        { host = "data"; container = "/opt/valheim"; }
      ];
      env = {
        SERVER_NAME = "Vainos Valheim";
        WORLD_NAME = "vainos";
        SERVER_PASS = "changeme";
        SERVER_PORT = "2456";
        SERVER_PUBLIC = "0";
        BACKUPS = "true";
      };
      memory = "4G";
      shutdownMethod = "signal";
      shutdownSignal = "SIGINT";
    };
    zomboid = {
      image = "renegademaster/zomboid-dedicated-server:latest";
      ports = [
        { port = 16261; protocol = "udp"; }
        { port = 16262; protocol = "udp"; }
      ];
      volumes = [
        { host = "server-files"; container = "/home/steam/ZomboidDedicatedServer"; }
        { host = "data"; container = "/home/steam/Zomboid"; }
      ];
      env = {
        ADMIN_PASSWORD = "changeme";
        SERVER_NAME = "Vainos Zomboid";
        MAX_PLAYERS = "8";
        MAX_RAM = "4G";
        GAME_VERSION = "public";
        STEAM_VAC = "true";
      };
      memory = "4G";
      shutdownMethod = "signal";
    };
  };

  # Derive TCP ports from registry
  tcpPorts = lib.concatMap (name:
    map (p: p.port) (builtins.filter (p: p.protocol == "tcp") games.${name}.ports)
  ) (builtins.attrNames games);

  # Derive UDP ports from registry
  udpPorts = lib.concatMap (name:
    map (p: p.port) (builtins.filter (p: p.protocol == "udp") games.${name}.ports)
  ) (builtins.attrNames games);

  # Generate shell-parseable .env file content for a game
  gameEnvFile = name: game:
    let
      baseVars = lib.concatStringsSep "\n" [
        "GAME_NAME=${name}"
        "GAME_IMAGE=${game.image}"
        "GAME_MEMORY=${game.memory}"
        "GAME_SHUTDOWN_METHOD=${game.shutdownMethod}"
        "GAME_SHUTDOWN_SIGNAL=${game.shutdownSignal or "SIGTERM"}"
      ];
      portVars = lib.concatImapStringsSep "\n" (i: p:
        "PORT_${toString (i - 1)}=\"${toString p.port}/${p.protocol}\""
      ) game.ports;
      portCount = "PORT_COUNT=${toString (builtins.length game.ports)}";
      volVars = lib.concatImapStringsSep "\n" (i: v:
        "VOLUME_${toString (i - 1)}=\"/srv/games/${name}/${v.host}:${v.container}\""
      ) game.volumes;
      volCount = "VOLUME_COUNT=${toString (builtins.length game.volumes)}";
      envVars = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (k: v: "ENV_${k}=\"${v}\"") game.env
      );
      envCount = "ENV_COUNT=${toString (builtins.length (builtins.attrNames game.env))}";
    in lib.concatStringsSep "\n" [
      baseVars portVars portCount volVars volCount envVars envCount
    ] + "\n";

in
{
  options.systemSettings.server.games = {
    enable = lib.mkEnableOption "game server infrastructure (registry, directories, firewall, OOM protection)";
    registry = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      default = games;
      description = "Game server registry (read-only, for nix eval access)";
    };
  };

  config = lib.mkIf cfg.enable {
    # Persistent storage directories -- one per game (INFRA-05)
    # Container images create their own internal subdirectory structure
    systemd.tmpfiles.rules = [
      "d /srv/games 0755 root root -"
    ] ++ lib.mapAttrsToList (name: _game:
      "d /srv/games/${name} 0755 root root -"
    ) games;

    # Firewall rules derived from registry (INFRA-06)
    # Individual ports, not ranges -- NixOS deduplicates automatically
    networking.firewall = {
      allowedTCPPorts = tcpPorts;
      allowedUDPPorts = udpPorts;
    };

    # Shell-parseable config files for CLI consumption (REG-01)
    # Generated at /etc/vainos/games/<name>.env
    environment.etc = lib.mapAttrs' (name: game:
      lib.nameValuePair "vainos/games/${name}.env" {
        text = gameEnvFile name game;
      }
    ) games;

    # OOM protection for website containers (INFRA-07)
    # Game servers can consume significant memory -- protect critical services
    virtualisation.oci-containers.containers.wowvain-com.extraOptions = [ "--memory=512m" ];
    virtualisation.oci-containers.containers.electrisim-api.extraOptions = [ "--memory=512m" ];

    # Caddy -- critical infrastructure, low OOM score
    systemd.services.caddy.serviceConfig.OOMScoreAdjust = -500;
  };
}
