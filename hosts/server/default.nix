# Server host configuration -- pure data.
# NixOS config lives in sibling .nix files (auto-imported by mkHost).
# hardware-configuration.nix is auto-imported by mkHost.
{ ... }:
{
  # Architecture -- read by flake.nix scanner
  systemSettings.system = "x86_64-linux";

  # NixOS state version -- applied as system.stateVersion by mkHost
  systemSettings.stateVersion = "24.11";

  # --- Enable server modules ---
  systemSettings.server.networking.enable = true;
  systemSettings.server.caddy.enable = true;
  systemSettings.server.podman.enable = true;
  systemSettings.server.deploy.enable = true;
  systemSettings.server.games.enable = true;

  # --- Enable Discord bot ---
  systemSettings.server.discord-bot.enable = true;
  systemSettings.server.discord-bot.guildId = "REPLACE_WITH_GUILD_ID";
  systemSettings.server.discord-bot.channelId = "REPLACE_WITH_CHANNEL_ID";
  systemSettings.server.discord-bot.adminRoleId = "REPLACE_WITH_ROLE_ID";

  # --- Enable site modules ---
  systemSettings.server.sites.electrisim.enable = true;
  systemSettings.server.sites.kaaldur-com.enable = true;
  systemSettings.server.sites.wowvain-com.enable = true;

  # --- Enable security modules ---
  systemSettings.security.doas.enable = true;
  systemSettings.security.hosts-blocklist.enable = true;

  # --- Enable CLI module ---
  systemSettings.core.vainos-cli.enable = true;

  # --- Enable maintenance modules ---
  systemSettings.maintenance.autoUpdate.enable = true;
  userSettings.updateNotify.enable = true;
}
