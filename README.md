# vainos

My NixOS config. One flake, two machines: a headless server and a Hyprland workstation.

## What's in here

- **server** - Caddy reverse proxy, Podman containers, fail2ban, static networking, SSH hardened
- **workstation** - Hyprland on Wayland, Stylix theming, PipeWire audio, AMD GPU, dev toolchains

## Repo structure

```
flake.nix                       # entry point, auto-discovers hosts
lib/
  mkHost.nix                    # builds a host from modules + inputs
  autoImport.nix                # finds modules by directory convention
  options.nix                   # systemSettings / userSettings namespaces
hosts/{name}/
  default.nix                   # pure data: what to enable, what values to set
  base.nix                      # boot config, hardware quirks (auto-imported)
  hardware-configuration.nix
modules/
  system/                       # NixOS modules (root level)
  user/                         # Home Manager modules (user level)
local/                          # machine-specific stuff (gitignored)
  server.nix                    # static IP, interface
  workstation.nix               # usually empty (DHCP)
  deploy.env                    # SSH target for remote deploys
secrets/
  secrets.yaml                  # sops-encrypted, see below
```

## How it works

Host `default.nix` files are just data. They set values in two freeform option namespaces (`systemSettings` and `userSettings`) and flip enable flags. Modules read those values and produce actual NixOS config.

Modules are auto-discovered: if a directory under `modules/` has a `default.nix`, it gets imported. No central import list to maintain. Directories prefixed with `.` or `_` are skipped.

Machine-specific stuff (IPs, SSH targets) goes in `local/` which is gitignored. The flake needs `--impure` to read those.

## Flake inputs

| Input | Channel | What for |
|-------|---------|----------|
| nixpkgs | `nixos-25.11` | packages, NixOS modules |
| home-manager | `release-25.11` | user env management |
| sops-nix | master | build-time secret decryption |
| stylix | master | system-wide theming |
| vainim | external flake | neovim config (symlinked in, not managed here) |

## Modules

### System - core

| Module | Option | What it does |
|--------|--------|--------------|
| locale | `systemSettings.core.locale.enable` | timezone (Europe/Bucharest), UTF-8. On by default |
| nix | `systemSettings.core.nix.enable` | flakes, auto-optimise store, weekly gc (30d). On by default |
| packages | `systemSettings.core.packages.enable` | vim, git, curl, wget, htop, tree. On by default |
| users | `systemSettings.core.users.enable` | creates `wowvain` with zsh + SSH key. On by default |
| zsh | `systemSettings.core.zsh.enable` | system-level zsh, needed for home-manager zsh to work. On by default |
| vainos-cli | `systemSettings.core.vainos-cli.enable` | the `vainos` CLI (see below). On by default |
| auto-update | `systemSettings.maintenance.autoUpdate.enable` | systemd timer: `flake update` + `rebuild switch` on a schedule (default weekly, 6h random delay) |

### System - desktop

| Module | Option | What it does |
|--------|--------|--------------|
| hyprland | `systemSettings.desktop.hyprland.enable` | compositor + UWSM session + XWayland + greetd login + XDG portals |
| audio | `systemSettings.desktop.audio.enable` | PipeWire, WirePlumber, 32-bit ALSA, PulseAudio compat, BT codecs |
| gpu | `systemSettings.desktop.gpu.enable` | AMD (Mesa/RADV), 32-bit for Steam/Wine, early amdgpu in initrd |
| bluetooth | `systemSettings.desktop.bluetooth.enable` | bluez + Blueman, power on boot |
| stylix | `systemSettings.desktop.stylix.enable` | theme presets, font stack (FiraCode, Inter, Noto Serif, Noto Emoji) |

Theme presets via `userSettings.theme`: `gruvbox-dark`, `catppuccin-latte`, `tokyo-night`

### System - security

| Module | Option | What it does |
|--------|--------|--------------|
| doas | `systemSettings.security.doas.enable` | replaces sudo, aliases `sudo` to `doas` |
| hosts-blocklist | `systemSettings.security.hosts-blocklist.enable` | StevenBlack hosts file (ads, fakenews, gambling) |

### System - server

| Module | Option | What it does |
|--------|--------|--------------|
| networking | `systemSettings.server.networking.enable` | static IP, SSH key-only, fail2ban (5 retries / 1h ban), firewall (22/80/443) |
| caddy | `systemSettings.server.caddy.enable` | `/static/*` from `/srv/www`, everything else to `127.0.0.1:3000` |
| podman | `systemSettings.server.podman.enable` | container runtime with docker CLI compat |
| containers | `systemSettings.server.containers.enable` | OCI containers with sops secret injection |

### User - general

| Module | Option | What it does |
|--------|--------|--------------|
| shell | `userSettings.shell.enable` | zsh + completions + autosuggestions + syntax highlighting + Starship. On by default |
| git | `userSettings.git.enable` | git config, aliases (co/ci/st/br/lg), rebase pulls. On by default |
| neovim | `userSettings.neovim.enable` | neovim + LSPs + formatters. Lua config comes from vainim (symlinked). On by default |
| gpg | `userSettings.gpg.enable` | gpg-agent with SSH support, 1h/24h cache. On by default |
| dev-tools | `userSettings.devTools.enable` | rust, go, python, node/ts, c/c++, haskell, lua, dart, java, odin, ripgrep, fd, jq. On by default |
| update-notify | `userSettings.updateNotify.enable` | zsh login hook, tells you when flake inputs updated but not applied yet. On by default |

### User - desktop

| Module | Option | What it does |
|--------|--------|--------------|
| hyprland | `userSettings.desktop.hyprland.enable` | keybinds (SUPER mod), workspaces, gaps, borders |
| waybar | `userSettings.desktop.waybar.enable` | top bar: workspaces, clock, volume, network, cpu, mem, tray |
| kitty | `userSettings.desktop.kitty.enable` | terminal, 10k scrollback, 0.95 opacity |
| fuzzel | `userSettings.desktop.fuzzel.enable` | app launcher |
| mako | `userSettings.desktop.mako.enable` | notifications, 5s timeout |
| hyprlock | `userSettings.desktop.hyprlock.enable` | lock screen + hypridle (lock at 5min, dpms off at 10min) |
| clipboard | `userSettings.desktop.clipboard.enable` | cliphist + wl-clipboard, Super+C |
| screenshots | `userSettings.desktop.screenshots.enable` | grim + slurp to ~/Pictures/Screenshots/, Print / Super+Print |
| stylix | `userSettings.desktop.stylix.enable` | per-app Stylix targets (kitty, waybar, fuzzel, mako, hyprland, hyprlock, gtk, qt) |

## vainos CLI

```
vainos sync [host]        rebuild local or deploy remote via SSH
vainos update [--rebuild] update flake inputs, optionally rebuild
vainos gc [full]          garbage collect (30d default, or nuke everything old)
vainos status             current generation, flake rev, pending changes
vainos help               usage
```

Reads SSH targets from `local/deploy.env`. Uses doas.

## Local config

Machine-specific values stay out of git. Copy the examples:

```bash
cp local/server.nix.example local/server.nix
cp local/workstation.nix.example local/workstation.nix
cp local/deploy.env.example local/deploy.env
```

`local/server.nix` has networking (static IP, gateway, nameservers, interface).
`local/deploy.env` has the SSH target (`SERVER_SSH = root@1.2.3.4`).

## About .sops.yaml and secrets/

These are safe to have in the repo.

`.sops.yaml` just has **public** age keys and tells sops which keys to encrypt to. Public keys encrypt, they can't decrypt.

`secrets/secrets.yaml` has the encrypted values (container env vars, etc). The ciphertext is useless without the private age keys, which only exist on the target machines (derived from the host SSH key at `/etc/ssh/ssh_host_ed25519_key`). Nothing sensitive is exposed.

To add a secret:

```bash
sops secrets/secrets.yaml
```

Then reference it in a module:

```nix
sops.secrets.my-secret = {
  sopsFile = ../../secrets/secrets.yaml;
  key = "my-secret";
};
```

## Make targets

```bash
make switch-server         # deploy to server via SSH
make switch-workstation    # rebuild workstation locally
make boot-server           # deploy to server, apply on next boot
make check                 # nix flake check
make update                # nix flake update
```

## Adding a module

1. Create `modules/system/<category>/<name>/default.nix` (or under `modules/user/`)
2. Declare an enable option in `systemSettings` or `userSettings`
3. Guard config with `lib.mkIf cfg.enable { ... }`
4. Flip the flag in the host's `default.nix`

Auto-discovered, no imports to update.

## Adding a host

1. `hosts/<name>/default.nix` with `systemSettings.system = "x86_64-linux"` and module enables
2. `hosts/<name>/hardware-configuration.nix` from `nixos-generate-config`
3. Optionally `hosts/<name>/base.nix` for boot config
4. `local/<name>.nix` for machine-specific values
5. Flake picks it up automatically

## License

Personal config. Use however you want.
