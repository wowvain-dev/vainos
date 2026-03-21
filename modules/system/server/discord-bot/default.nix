# Discord bot for remote game server management via slash commands
# Shells out to vainos CLI for all game operations -- convenience layer, not reimplementation
{ config, lib, pkgs, ... }:

let
  cfg = config.systemSettings.server.discord-bot;
  python = pkgs.python3.withPackages (ps: [ ps.discordpy ]);
  botScript = ./bot.py;
in
{
  options.systemSettings.server.discord-bot = {
    enable = lib.mkEnableOption "Discord bot for game server management";
    guildId = lib.mkOption {
      type = lib.types.str;
      description = "Discord server (guild) ID for slash command registration";
    };
    channelId = lib.mkOption {
      type = lib.types.str;
      description = "Discord channel ID for status/password announcements";
    };
    adminRoleId = lib.mkOption {
      type = lib.types.str;
      description = "Discord role ID required for game management commands";
    };
  };

  config = lib.mkIf cfg.enable {
    # Bot token secret -- decrypted at service start by sops-nix
    # Format: dotenv (DISCORD_TOKEN=<token>) so EnvironmentFile works directly
    sops.secrets.discord-bot-token = {
      sopsFile = ../../../../secrets/discord-bot.yaml;
      format = "dotenv";
    };

    # Password directory (shared with vainos CLI -- CLI generates, bot reads)
    systemd.tmpfiles.rules = [
      "d /var/lib/vainos-games 0755 root root -"
      "d /var/lib/vainos-games/passwords 0755 root root -"
    ];

    # Bot systemd service
    systemd.services.discord-bot = {
      description = "Discord game management bot";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      path = [ "/run/current-system/sw" pkgs.podman ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${python}/bin/python ${botScript}";
        Restart = "on-failure";
        RestartSec = "10s";
        Environment = [
          "GUILD_ID=${cfg.guildId}"
          "CHANNEL_ID=${cfg.channelId}"
          "ADMIN_ROLE_ID=${cfg.adminRoleId}"
          "PASSWORD_DIR=/var/lib/vainos-games/passwords"
          "GAME_ENV_DIR=/etc/vainos/games"
        ];
        EnvironmentFile = config.sops.secrets.discord-bot-token.path;
      };
    };
  };
}
