# Game server infrastructure -- registry-driven directories, firewall, config gen, OOM protection
# Games are on-demand (started by CLI in Phase 16), NOT always-on NixOS containers.
# The registry produces shell-parseable .env config files consumed by the CLI.
{ config, lib, pkgs, ... }:

let
  cfg = config.systemSettings.server.games;

  # === Game Server Registry ===
  # Single source of truth for all game server definitions.
  # Each game entry drives: .env config generation, tmpfiles directories, firewall rules.
  #
  # Adding mods to a game:
  #   Mods use the existing `volumes` and `env` fields -- no special "mods" field needed.
  #   Example: Adding Forge to Minecraft:
  #     env = { TYPE = "FORGE"; VERSION = "1.20.4"; FORGEVERSION = "latest"; /* ... */ };
  #   Example: Adding a mod volume:
  #     volumes = [ { host = "data"; container = "/data"; } { host = "mods"; container = "/data/mods"; } ];
  #   tmpfiles rules auto-create all volume directories under /srv/games/<name>/.
  #   After editing, run: nixos-rebuild switch (same workflow as adding a game).
  #
  # Fields per game:
  #   image             - Container image (e.g., "itzg/minecraft-server:java21")
  #   ports             - List of { port; protocol; } for firewall and -p flags
  #   volumes           - List of { host; container; } -- host is relative to /srv/games/<name>/
  #   env               - Arbitrary env vars passed as -e flags to podman
  #   memory            - Memory limit string (e.g., "4G")
  #   shutdownMethod    - "rcon" | "signal" -- how CLI gracefully stops the game
  #   shutdownSignal    - Signal name for signal method (default: SIGTERM)
  #   owner             - Optional "UID:GID" for volume ownership (e.g., "1000:1000")
  #   playerCheckMethod - "rcon-query" | "log-parse" | "none" -- how bot checks for connected players
  #   passwordEnvVar    - Env var name for server password (e.g., "SERVER_PASS") -- empty string = no password
  #   passwordType      - "alphanumeric" (default) | "numeric" -- controls generated password format
  #   passwordWriteMethod - "env" (default, pass via -e) | "minecraft-plugin" | "zomboid-ini"
  #   readyPattern        - grep pattern in container logs that indicates server is fully started
  #   consoleMethod       - "rcon" | "attach" | "none" -- how admin console access works
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
        TYPE = "PAPER";
        VERSION = "LATEST";
        MEMORY = "4G";
        ENABLE_RCON = "true";
        RCON_PASSWORD = "changeme";
        MODRINTH_PROJECTS = "passwords";
      };
      memory = "4G";
      shutdownMethod = "rcon";
      playerCheckMethod = "rcon-query";
      passwordEnvVar = "SERVER_PASSWORD";
      passwordType = "numeric";
      passwordWriteMethod = "minecraft-plugin";
      readyPattern = "Done";
      consoleMethod = "rcon";
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
        UPDATE_CRON = "";
        RESTART_CRON = "";
      };
      memory = "4G";
      shutdownMethod = "signal";
      shutdownSignal = "SIGINT";
      playerCheckMethod = "log-parse";
      passwordEnvVar = "SERVER_PASS";
      readyPattern = "Game server connected";
      consoleMethod = "none";  # Valheim has no server console; admin via in-game F5 or config files
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
        RCON_PORT = "27015";
        RCON_PASSWORD = "changeme_rcon";
        DEFAULT_PORT = "16261";
        UDP_PORT = "16262";
      };
      memory = "4G";
      shutdownMethod = "signal";
      owner = "1000:1000";  # steam user inside container
      playerCheckMethod = "log-parse";
      passwordEnvVar = "SERVER_PASSWORD";
      passwordWriteMethod = "zomboid-ini";
      readyPattern = "SERVER STARTED";
      consoleMethod = "attach";
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
        "GAME_PLAYER_CHECK=${game.playerCheckMethod or "none"}"
        "GAME_PASSWORD_ENV=${game.passwordEnvVar or ""}"
        "GAME_PASSWORD_TYPE=${game.passwordType or "alphanumeric"}"
        "GAME_PASSWORD_WRITE=${game.passwordWriteMethod or "env"}"
        "GAME_READY_PATTERN=\"${game.readyPattern or ""}\""
        "GAME_CONSOLE_METHOD=${game.consoleMethod or "none"}"
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
    # Persistent storage directories -- one per game + volume subdirectories (INFRA-05)
    # Container images create their own internal subdirectory structure
    systemd.tmpfiles.rules = [
      "d /srv/games 0755 root root -"
      "d /srv/games/backups 0755 root root -"
    ] ++ lib.concatMap (name:
      let
        game = games.${name};
        user = if game ? owner then (builtins.elemAt (lib.splitString ":" game.owner) 0) else "root";
        group = if game ? owner then (builtins.elemAt (lib.splitString ":" game.owner) 1) else "root";
      in
      [ "d /srv/games/${name} 0755 ${user} ${group} -" ]
      ++ map (v: "d /srv/games/${name}/${v.host} 0755 ${user} ${group} -") game.volumes
    ) (builtins.attrNames games);

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

    # Enable podman-restart.service so game containers with --restart=always survive reboots (INFRA-08)
    systemd.services.podman-restart.wantedBy = [ "multi-user.target" ];

    # Scheduled automatic backup of all running game servers (MAINT-01)
    # Enumerates running game-* containers and calls `vainos game backup` for each.
    # Backup retention (last 5 per game) handled by the CLI function.
    systemd.services.vainos-game-backup = {
      description = "Backup all running game servers";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      path = [ pkgs.podman ];
      script = ''
        echo "vainos-game-backup: starting scheduled backup"
        running=$(podman ps --format '{{.Names}}' 2>/dev/null | grep '^game-' || true)
        if [ -z "$running" ]; then
          echo "vainos-game-backup: no game containers running, nothing to back up"
          exit 0
        fi
        echo "$running" | while IFS= read -r container; do
          name="''${container#game-}"
          echo "vainos-game-backup: backing up $name"
          vainos game backup "$name" || echo "vainos-game-backup: WARNING: backup failed for $name"
        done
        echo "vainos-game-backup: scheduled backup complete"
      '';
    };

    systemd.timers.vainos-game-backup = {
      description = "Daily backup timer for game servers";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 04:00:00";
        Persistent = true;
        RandomizedDelaySec = "15m";
      };
    };

    # Game server landing pages -- browser-accessible connection instructions
    services.caddy.virtualHosts = {
      "minecraft.wowvain.com" = {
        extraConfig = ''
          header Content-Type "text/html; charset=utf-8"
          respond <<HTML
            <!DOCTYPE html>
            <html lang="en">
            <head>
              <meta charset="utf-8">
              <meta name="viewport" content="width=device-width, initial-scale=1">
              <title>Minecraft Server</title>
              <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #1a1a2e; color: #e0e0e0; min-height: 100vh; display: flex; align-items: center; justify-content: center; }
                .card { background: #16213e; border-radius: 12px; padding: 2.5rem; max-width: 480px; width: 90%; box-shadow: 0 8px 32px rgba(0,0,0,0.3); }
                h1 { font-size: 1.8rem; margin-bottom: 0.5rem; color: #7bed9f; }
                .subtitle { color: #888; margin-bottom: 2rem; }
                .step { margin-bottom: 1.2rem; }
                .step-num { display: inline-block; width: 28px; height: 28px; background: #7bed9f; color: #1a1a2e; border-radius: 50%; text-align: center; line-height: 28px; font-weight: bold; font-size: 0.85rem; margin-right: 0.5rem; }
                .addr { background: #0f3460; border-radius: 8px; padding: 1rem; margin: 1rem 0; font-family: 'Courier New', monospace; font-size: 1.2rem; text-align: center; color: #7bed9f; cursor: pointer; transition: background 0.2s; }
                .addr:hover { background: #1a4a7a; }
                .addr:active { background: #245a8a; }
                .hint { font-size: 0.85rem; color: #666; text-align: center; }
                .status { margin-top: 1.5rem; padding-top: 1.5rem; border-top: 1px solid #1f3460; font-size: 0.9rem; color: #888; }
              </style>
            </head>
            <body>
              <div class="card">
                <h1>Minecraft</h1>
                <p class="subtitle">Java Edition Server</p>
                <div class="step"><span class="step-num">1</span> Open Minecraft, go to <strong>Multiplayer</strong></div>
                <div class="step"><span class="step-num">2</span> Click <strong>Add Server</strong></div>
                <div class="step"><span class="step-num">3</span> Enter the server address:</div>
                <div class="addr" onclick="navigator.clipboard.writeText('minecraft.wowvain.com')" title="Click to copy">minecraft.wowvain.com</div>
                <p class="hint">Click to copy &middot; No port needed</p>
                <div class="status">
                  <strong>Version:</strong> Latest &middot; <strong>Type:</strong> Vanilla
                </div>
              </div>
            </body>
            </html>
          HTML
        '';
      };
      "valheim.wowvain.com" = {
        extraConfig = ''
          header Content-Type "text/html; charset=utf-8"
          respond <<HTML
            <!DOCTYPE html>
            <html lang="en">
            <head>
              <meta charset="utf-8">
              <meta name="viewport" content="width=device-width, initial-scale=1">
              <title>Valheim Server</title>
              <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #1a1a2e; color: #e0e0e0; min-height: 100vh; display: flex; align-items: center; justify-content: center; }
                .card { background: #16213e; border-radius: 12px; padding: 2.5rem; max-width: 480px; width: 90%; box-shadow: 0 8px 32px rgba(0,0,0,0.3); }
                h1 { font-size: 1.8rem; margin-bottom: 0.5rem; color: #ffa502; }
                .subtitle { color: #888; margin-bottom: 2rem; }
                .step { margin-bottom: 1.2rem; }
                .step-num { display: inline-block; width: 28px; height: 28px; background: #ffa502; color: #1a1a2e; border-radius: 50%; text-align: center; line-height: 28px; font-weight: bold; font-size: 0.85rem; margin-right: 0.5rem; }
                .addr { background: #0f3460; border-radius: 8px; padding: 1rem; margin: 1rem 0; font-family: 'Courier New', monospace; font-size: 1.2rem; text-align: center; color: #ffa502; cursor: pointer; transition: background 0.2s; }
                .addr:hover { background: #1a4a7a; }
                .addr:active { background: #245a8a; }
                .hint { font-size: 0.85rem; color: #666; text-align: center; }
                .status { margin-top: 1.5rem; padding-top: 1.5rem; border-top: 1px solid #1f3460; font-size: 0.9rem; color: #888; }
              </style>
            </head>
            <body>
              <div class="card">
                <h1>Valheim</h1>
                <p class="subtitle">Dedicated Server</p>
                <div class="step"><span class="step-num">1</span> Open Valheim, click <strong>Join Game</strong></div>
                <div class="step"><span class="step-num">2</span> Click <strong>Add Server</strong></div>
                <div class="step"><span class="step-num">3</span> Enter the server address:</div>
                <div class="addr" onclick="navigator.clipboard.writeText('valheim.wowvain.com')" title="Click to copy">valheim.wowvain.com</div>
                <p class="hint">Click to copy &middot; No port needed (uses default 2456)</p>
                <div class="step"><span class="step-num">4</span> Password: <strong>changeme</strong></div>
                <div class="status">
                  <strong>World:</strong> vainos &middot; <strong>Public:</strong> No
                </div>
              </div>
            </body>
            </html>
          HTML
        '';
      };
      "zomboid.wowvain.com" = {
        extraConfig = ''
          header Content-Type "text/html; charset=utf-8"
          respond <<HTML
            <!DOCTYPE html>
            <html lang="en">
            <head>
              <meta charset="utf-8">
              <meta name="viewport" content="width=device-width, initial-scale=1">
              <title>Project Zomboid Server</title>
              <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #1a1a2e; color: #e0e0e0; min-height: 100vh; display: flex; align-items: center; justify-content: center; }
                .card { background: #16213e; border-radius: 12px; padding: 2.5rem; max-width: 480px; width: 90%; box-shadow: 0 8px 32px rgba(0,0,0,0.3); }
                h1 { font-size: 1.8rem; margin-bottom: 0.5rem; color: #e74c3c; }
                .subtitle { color: #888; margin-bottom: 2rem; }
                .step { margin-bottom: 1.2rem; }
                .step-num { display: inline-block; width: 28px; height: 28px; background: #e74c3c; color: #fff; border-radius: 50%; text-align: center; line-height: 28px; font-weight: bold; font-size: 0.85rem; margin-right: 0.5rem; }
                .addr { background: #0f3460; border-radius: 8px; padding: 1rem; margin: 1rem 0; font-family: 'Courier New', monospace; font-size: 1.2rem; text-align: center; color: #e74c3c; cursor: pointer; transition: background 0.2s; }
                .addr:hover { background: #1a4a7a; }
                .addr:active { background: #245a8a; }
                .hint { font-size: 0.85rem; color: #666; text-align: center; }
                .status { margin-top: 1.5rem; padding-top: 1.5rem; border-top: 1px solid #1f3460; font-size: 0.9rem; color: #888; }
              </style>
            </head>
            <body>
              <div class="card">
                <h1>Project Zomboid</h1>
                <p class="subtitle">Dedicated Server</p>
                <div class="step"><span class="step-num">1</span> Open Project Zomboid, go to <strong>Join</strong></div>
                <div class="step"><span class="step-num">2</span> Enter the server address:</div>
                <div class="addr" onclick="navigator.clipboard.writeText('zomboid.wowvain.com')" title="Click to copy">zomboid.wowvain.com</div>
                <p class="hint">Click to copy &middot; Leave port as default (16261)</p>
                <div class="step"><span class="step-num">3</span> Enter your account username and password</div>
                <div class="status">
                  <strong>Server:</strong> Vainos Zomboid &middot; <strong>Max Players:</strong> 8
                </div>
              </div>
            </body>
            </html>
          HTML
        '';
      };
    };
  };
}
