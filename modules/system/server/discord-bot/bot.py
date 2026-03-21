"""Discord bot for remote game server management via slash commands.

Shells out to the vainos CLI for all game operations -- convenience layer,
not reimplementation. Adds Discord-native UX: slash commands, embeds,
buttons, channel notifications, and safety checks (player protection,
permissions, per-game locking).
"""

import os
import asyncio
import secrets
import re
from pathlib import Path

import discord
from discord import app_commands
from discord.ext import commands

# ---------------------------------------------------------------------------
# Configuration (set by NixOS systemd service Environment / EnvironmentFile)
# ---------------------------------------------------------------------------

GUILD_ID = int(os.environ["GUILD_ID"])
CHANNEL_ID = int(os.environ["CHANNEL_ID"])
ADMIN_ROLE_ID = int(os.environ["ADMIN_ROLE_ID"])
PASSWORD_DIR = Path(os.environ.get("PASSWORD_DIR", "/var/lib/discord-bot/passwords"))
GAME_ENV_DIR = Path(os.environ.get("GAME_ENV_DIR", "/etc/vainos/games"))

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def get_available_games() -> list[str]:
    """Return sorted list of game names from .env files on disk."""
    return sorted(f.stem for f in GAME_ENV_DIR.glob("*.env"))


def read_env_file(game: str) -> dict[str, str]:
    """Parse a game .env file into a dict, handling KEY="value" quoting."""
    env: dict[str, str] = {}
    env_file = GAME_ENV_DIR / f"{game}.env"
    for line in env_file.read_text().splitlines():
        if "=" in line and not line.startswith("#"):
            key, _, value = line.partition("=")
            env[key.strip()] = value.strip().strip('"')
    return env


async def run_cli(*args: str) -> tuple[int, str, str]:
    """Execute a vainos CLI command asynchronously.

    Returns (returncode, stdout, stderr).
    """
    proc = await asyncio.create_subprocess_exec(
        "vainos",
        *args,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    stdout, stderr = await proc.communicate()
    return proc.returncode, stdout.decode(), stderr.decode()


async def run_raw(*args: str) -> tuple[int, str, str]:
    """Execute an arbitrary command asynchronously (e.g. podman exec).

    Returns (returncode, stdout, stderr).
    """
    proc = await asyncio.create_subprocess_exec(
        *args,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    stdout, stderr = await proc.communicate()
    return proc.returncode, stdout.decode(), stderr.decode()


# ---------------------------------------------------------------------------
# Password management
# ---------------------------------------------------------------------------


def get_or_create_password(game: str) -> str:
    """Get existing password or generate a new one.

    Passwords persist across restarts in PASSWORD_DIR/<game>.txt.
    """
    pw_file = PASSWORD_DIR / f"{game}.txt"
    if pw_file.exists():
        return pw_file.read_text().strip()
    password = secrets.token_urlsafe(16)
    pw_file.write_text(password)
    return password


def regenerate_password(game: str) -> str:
    """Force-generate a new password, overwriting the old one."""
    pw_file = PASSWORD_DIR / f"{game}.txt"
    password = secrets.token_urlsafe(16)
    pw_file.write_text(password)
    return password


# ---------------------------------------------------------------------------
# Player check
# ---------------------------------------------------------------------------


async def check_players(game: str, method: str) -> tuple[bool, int, str]:
    """Check whether players are connected to a game server.

    Returns (has_players, count, detail_message).
    """
    if method in ("none", ""):
        return False, 0, ""

    if method == "rcon-query":
        # Minecraft: rcon-cli list inside container
        rc, stdout, _ = await run_raw(
            "podman", "exec", f"game-{game}", "rcon-cli", "list"
        )
        if rc != 0:
            return False, 0, "Could not query RCON"
        match = re.search(r"There are (\d+)", stdout)
        if match:
            count = int(match.group(1))
            return count > 0, count, stdout.strip()
        return False, 0, stdout.strip()

    if method == "log-parse":
        # Valheim/Zomboid: parse recent container logs for connect/disconnect
        rc, stdout, _ = await run_raw(
            "podman", "logs", "--tail", "200", f"game-{game}"
        )
        if rc != 0:
            return False, 0, "Could not read logs"
        connects = len(
            re.findall(r"Got handshake from client|is trying to connect", stdout)
        )
        disconnects = len(
            re.findall(r"Closing socket|Disconnecting client", stdout)
        )
        active = max(0, connects - disconnects)
        return active > 0, active, f"~{active} player(s) estimated from recent logs"

    return False, 0, f"Unknown check method: {method}"


# ---------------------------------------------------------------------------
# Discord helpers
# ---------------------------------------------------------------------------


def make_status_embed(game: str, status: str, details: str = "") -> discord.Embed:
    """Create a coloured embed for game status announcements."""
    colors = {
        "started": discord.Color.green(),
        "stopped": discord.Color.red(),
        "running": discord.Color.blue(),
        "error": discord.Color.orange(),
    }
    embed = discord.Embed(
        title=f"{game.capitalize()} Server",
        color=colors.get(status, discord.Color.greyple()),
    )
    embed.add_field(name="Status", value=status.capitalize(), inline=True)
    if details:
        embed.add_field(name="Details", value=details, inline=False)
    return embed


def has_admin_role(interaction: discord.Interaction) -> bool:
    """Check whether the invoking user has the configured admin role."""
    if not isinstance(interaction.user, discord.Member):
        return False
    return any(role.id == ADMIN_ROLE_ID for role in interaction.user.roles)


async def game_autocomplete(
    interaction: discord.Interaction, current: str
) -> list[app_commands.Choice[str]]:
    """Provide autocomplete choices for the game name parameter."""
    games = get_available_games()
    return [
        app_commands.Choice(name=g, value=g)
        for g in games
        if current.lower() in g.lower()
    ][:25]


# ---------------------------------------------------------------------------
# Confirmation view (player protection)
# ---------------------------------------------------------------------------


class StopConfirm(discord.ui.View):
    """Buttons for confirming a stop/restart when players are connected."""

    def __init__(self) -> None:
        super().__init__(timeout=30)
        self.value: bool | None = None

    @discord.ui.button(label="Stop Anyway", style=discord.ButtonStyle.red)
    async def confirm(
        self, interaction: discord.Interaction, button: discord.ui.Button
    ) -> None:
        await interaction.response.send_message("Stopping server...", ephemeral=True)
        self.value = True
        self.stop()

    @discord.ui.button(label="Cancel", style=discord.ButtonStyle.grey)
    async def cancel(
        self, interaction: discord.Interaction, button: discord.ui.Button
    ) -> None:
        await interaction.response.send_message("Cancelled.", ephemeral=True)
        self.value = False
        self.stop()


# ---------------------------------------------------------------------------
# Slash command group: /game
# ---------------------------------------------------------------------------


class GameCommands(app_commands.Group):
    """Manage game servers from Discord."""

    def __init__(self, bot: "GameBot") -> None:
        super().__init__(name="game", description="Manage game servers")
        self.bot = bot

    # -- /game list --------------------------------------------------------

    @app_commands.command(name="list", description="List all game servers and their status")
    async def list_games(self, interaction: discord.Interaction) -> None:
        await interaction.response.defer(ephemeral=True)

        games = get_available_games()
        if not games:
            await interaction.followup.send("No games configured.")
            return

        lines: list[str] = []
        for g in games:
            env = read_env_file(g)
            rc, _, _ = await run_raw("podman", "container", "exists", f"game-{g}")
            status = "running" if rc == 0 else "stopped"

            # Collect ports
            port_count = int(env.get("PORT_COUNT", "0"))
            ports = []
            for i in range(port_count):
                spec = env.get(f"PORT_{i}", "").strip('"')
                if spec:
                    ports.append(spec)
            port_str = ", ".join(ports) if ports else "-"

            memory = env.get("GAME_MEMORY", "?")
            icon = ":green_circle:" if status == "running" else ":red_circle:"
            lines.append(f"{icon} **{g}** -- {status} | Ports: {port_str} | Mem: {memory}")

        await interaction.followup.send("\n".join(lines))

    # -- /game start -------------------------------------------------------

    @app_commands.command(name="start", description="Start a game server")
    @app_commands.describe(name="Game server name")
    @app_commands.autocomplete(name=game_autocomplete)
    async def start(self, interaction: discord.Interaction, name: str) -> None:
        if not has_admin_role(interaction):
            await interaction.response.send_message(
                "You need the admin role to start servers.", ephemeral=True
            )
            return

        await interaction.response.defer(ephemeral=True)

        if name not in get_available_games():
            await interaction.followup.send(f"Unknown game: `{name}`")
            return

        lock = self.bot.get_lock(name)
        if lock.locked():
            await interaction.followup.send(
                f"An operation is already in progress for **{name}**."
            )
            return

        async with lock:
            env = read_env_file(name)
            password_env = env.get("GAME_PASSWORD_ENV", "")

            cli_args: list[str] = ["game", "start", name, "--force"]

            password: str | None = None
            if password_env:
                password = get_or_create_password(name)
                cli_args.extend(["--env", f"{password_env}={password}"])

            rc, stdout, stderr = await run_cli(*cli_args)

            if rc != 0:
                await interaction.followup.send(
                    f"Failed to start **{name}**:\n```\n{stderr or stdout}\n```"
                )
                return

            await interaction.followup.send(f"Started **{name}**.")

            # Channel announcements
            channel = self.bot.get_channel(CHANNEL_ID)
            if channel and isinstance(channel, discord.TextChannel):
                await channel.send(embed=make_status_embed(name, "started"))
                if password:
                    pw_embed = discord.Embed(
                        title=f"{name.capitalize()} Password",
                        description=f"```\n{password}\n```",
                        color=discord.Color.gold(),
                    )
                    pw_embed.set_footer(text="Use /game newpassword to regenerate")
                    await channel.send(embed=pw_embed)

    # -- /game stop --------------------------------------------------------

    @app_commands.command(name="stop", description="Stop a game server")
    @app_commands.describe(name="Game server name")
    @app_commands.autocomplete(name=game_autocomplete)
    async def stop(self, interaction: discord.Interaction, name: str) -> None:
        if not has_admin_role(interaction):
            await interaction.response.send_message(
                "You need the admin role to stop servers.", ephemeral=True
            )
            return

        await interaction.response.defer(ephemeral=True)

        if name not in get_available_games():
            await interaction.followup.send(f"Unknown game: `{name}`")
            return

        lock = self.bot.get_lock(name)
        if lock.locked():
            await interaction.followup.send(
                f"An operation is already in progress for **{name}**."
            )
            return

        async with lock:
            env = read_env_file(name)
            player_method = env.get("GAME_PLAYER_CHECK", "none")

            has_players, count, detail = await check_players(name, player_method)
            if has_players:
                view = StopConfirm()
                await interaction.followup.send(
                    f"**{count}** player(s) connected to **{name}**:\n{detail}\n\n"
                    "Stop anyway?",
                    view=view,
                )
                await view.wait()
                if not view.value:
                    return

            rc, stdout, stderr = await run_cli("game", "stop", name)

            if rc != 0:
                await interaction.followup.send(
                    f"Failed to stop **{name}**:\n```\n{stderr or stdout}\n```"
                )
                return

            await interaction.followup.send(f"Stopped **{name}**.")

            channel = self.bot.get_channel(CHANNEL_ID)
            if channel and isinstance(channel, discord.TextChannel):
                await channel.send(embed=make_status_embed(name, "stopped"))

    # -- /game restart -----------------------------------------------------

    @app_commands.command(name="restart", description="Restart a game server (stop + start)")
    @app_commands.describe(name="Game server name")
    @app_commands.autocomplete(name=game_autocomplete)
    async def restart(self, interaction: discord.Interaction, name: str) -> None:
        if not has_admin_role(interaction):
            await interaction.response.send_message(
                "You need the admin role to restart servers.", ephemeral=True
            )
            return

        await interaction.response.defer(ephemeral=True)

        if name not in get_available_games():
            await interaction.followup.send(f"Unknown game: `{name}`")
            return

        lock = self.bot.get_lock(name)
        if lock.locked():
            await interaction.followup.send(
                f"An operation is already in progress for **{name}**."
            )
            return

        async with lock:
            env = read_env_file(name)
            player_method = env.get("GAME_PLAYER_CHECK", "none")

            # Player check before stopping
            has_players, count, detail = await check_players(name, player_method)
            if has_players:
                view = StopConfirm()
                await interaction.followup.send(
                    f"**{count}** player(s) connected to **{name}**:\n{detail}\n\n"
                    "Restart anyway?",
                    view=view,
                )
                await view.wait()
                if not view.value:
                    return

            # Stop
            rc, stdout, stderr = await run_cli("game", "stop", name)
            if rc != 0:
                await interaction.followup.send(
                    f"Failed to stop **{name}**:\n```\n{stderr or stdout}\n```"
                )
                return

            # Start (re-inject password)
            password_env = env.get("GAME_PASSWORD_ENV", "")
            cli_args: list[str] = ["game", "start", name, "--force"]
            password: str | None = None
            if password_env:
                password = get_or_create_password(name)
                cli_args.extend(["--env", f"{password_env}={password}"])

            rc, stdout, stderr = await run_cli(*cli_args)
            if rc != 0:
                await interaction.followup.send(
                    f"Stopped **{name}** but failed to start:\n```\n{stderr or stdout}\n```"
                )
                return

            await interaction.followup.send(f"Restarted **{name}**.")

            channel = self.bot.get_channel(CHANNEL_ID)
            if channel and isinstance(channel, discord.TextChannel):
                await channel.send(
                    embed=make_status_embed(name, "started", "Restarted")
                )
                if password:
                    pw_embed = discord.Embed(
                        title=f"{name.capitalize()} Password",
                        description=f"```\n{password}\n```",
                        color=discord.Color.gold(),
                    )
                    pw_embed.set_footer(text="Use /game newpassword to regenerate")
                    await channel.send(embed=pw_embed)

    # -- /game status ------------------------------------------------------

    @app_commands.command(name="status", description="Show game server status")
    @app_commands.describe(name="Game server name (omit for all)")
    @app_commands.autocomplete(name=game_autocomplete)
    async def status(
        self, interaction: discord.Interaction, name: str | None = None
    ) -> None:
        await interaction.response.defer(ephemeral=True)

        if name:
            if name not in get_available_games():
                await interaction.followup.send(f"Unknown game: `{name}`")
                return

            rc, _, _ = await run_raw("podman", "container", "exists", f"game-{name}")
            if rc != 0:
                await interaction.followup.send(
                    embed=make_status_embed(name, "stopped")
                )
                return

            rc, stdout, _ = await run_raw(
                "podman", "stats", "--no-stream", "--format",
                "{{.CPUPerc}}|{{.MemUsage}}", f"game-{name}"
            )
            if rc == 0 and stdout.strip():
                parts = stdout.strip().split("|")
                details = f"CPU: {parts[0]}  |  Memory: {parts[1]}" if len(parts) == 2 else stdout.strip()
            else:
                details = "Running"
            await interaction.followup.send(
                embed=make_status_embed(name, "running", details)
            )
        else:
            # Show all games
            games = get_available_games()
            if not games:
                await interaction.followup.send("No games configured.")
                return

            embeds: list[discord.Embed] = []
            for g in games:
                rc, _, _ = await run_raw("podman", "container", "exists", f"game-{g}")
                st = "running" if rc == 0 else "stopped"
                embeds.append(make_status_embed(g, st))
            await interaction.followup.send(embeds=embeds)

    # -- /game newpassword -------------------------------------------------

    @app_commands.command(name="newpassword", description="Regenerate a game server password")
    @app_commands.describe(name="Game server name")
    @app_commands.autocomplete(name=game_autocomplete)
    async def newpassword(self, interaction: discord.Interaction, name: str) -> None:
        if not has_admin_role(interaction):
            await interaction.response.send_message(
                "You need the admin role to manage passwords.", ephemeral=True
            )
            return

        await interaction.response.defer(ephemeral=True)

        if name not in get_available_games():
            await interaction.followup.send(f"Unknown game: `{name}`")
            return

        env = read_env_file(name)
        password_env = env.get("GAME_PASSWORD_ENV", "")
        if not password_env:
            await interaction.followup.send(
                f"**{name}** has no password field configured."
            )
            return

        password = regenerate_password(name)
        await interaction.followup.send(
            f"Password regenerated for **{name}**. Takes effect on next start."
        )

        channel = self.bot.get_channel(CHANNEL_ID)
        if channel and isinstance(channel, discord.TextChannel):
            pw_embed = discord.Embed(
                title=f"{name.capitalize()} New Password",
                description=f"```\n{password}\n```",
                color=discord.Color.gold(),
            )
            pw_embed.set_footer(text="Takes effect on next /game start or /game restart")
            await channel.send(embed=pw_embed)


# ---------------------------------------------------------------------------
# Bot class
# ---------------------------------------------------------------------------


class GameBot(commands.Bot):
    """Discord bot for game server management."""

    def __init__(self) -> None:
        intents = discord.Intents.default()
        super().__init__(command_prefix="!", intents=intents)
        self.game_locks: dict[str, asyncio.Lock] = {}

    def get_lock(self, game: str) -> asyncio.Lock:
        """Get or create a per-game asyncio lock."""
        if game not in self.game_locks:
            self.game_locks[game] = asyncio.Lock()
        return self.game_locks[game]

    async def setup_hook(self) -> None:
        """Register slash commands."""
        self.tree.add_command(GameCommands(self))

    async def on_ready(self) -> None:
        """Sync commands once the bot is fully connected."""
        guild = discord.Object(id=GUILD_ID)
        self.tree.copy_global_to(guild=guild)
        await self.tree.sync(guild=guild)
        print(f"Bot ready. Synced commands to guild {GUILD_ID}", flush=True)


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

bot = GameBot()
bot.run(os.environ["DISCORD_TOKEN"])
