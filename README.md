# vainos

A modular NixOS configuration managing a headless server and a Hyprland Wayland workstation from a single flake.

## Overview

vainos uses a convention-based module system where hosts declare **what** they want (pure data in option namespaces) and modules provide **how** (NixOS configuration). Modules are auto-discovered by directory structure, machine-specific values live in gitignored `local/` files, and secrets are managed with sops-nix.

**Hosts:**
- **server** — hardened headless box with Caddy reverse proxy, Podman containers, fail2ban, static networking
- **workstation** — Hyprland Wayland desktop with Stylix theming, PipeWire audio, AMD GPU, development toolchains

## Architecture

```
flake.nix                       # Entry point — scans hosts/, wires inputs
├── lib/
│   ├── mkHost.nix              # Host builder — assembles modules + inputs per host
│   ├── autoImport.nix          # Recursive module discovery (dir with default.nix = module)
│   └── options.nix             # Freeform systemSettings / userSettings namespaces
├── hosts/{name}/
│   ├── default.nix             # Pure data: which modules to enable, settings values
│   ├── base.nix                # NixOS config (boot, hardware quirks) — auto-imported
│   └── hardware-configuration.nix
├── modules/
│   ├── system/                 # NixOS modules (run as root)
│   └── user/                   # Home Manager modules (run as user)
├── local/                      # Machine-specific overrides (gitignored)
│   ├── server.nix              # Static IP, interface name
│   ├── workstation.nix         # Usually empty (DHCP)
│   └── deploy.env              # SSH target for remote deployment
└── secrets/
    └── secrets.yaml            # SOPS-encrypted secrets (age keys)
```

### How it works

1. `flake.nix` scans `hosts/` for directories containing `default.nix`
2. Each host's `default.nix` declares `systemSettings` and `userSettings` — pure data, no NixOS config
3. `mkHost.nix` auto-imports all modules from `modules/system/` and `modules/user/`
4. Each module reads from the option namespaces and activates only when its enable flag is set
5. Machine-specific config is loaded from `local/{name}.nix` (requires `--impure`)

### Option namespaces

Two freeform top-level namespaces allow loose coupling between modules:

- **`systemSettings`** — system-level: networking, services, maintenance, security, hardware
- **`userSettings`** — user-level: theme, shell, editor, desktop preferences

Any module can read from either namespace. Hosts set values, modules consume them.

## Flake inputs

| Input | Channel | Purpose |
|-------|---------|---------|
| nixpkgs | `nixos-25.11` | Package set and NixOS modules |
| home-manager | `release-25.11` | User environment management |
| sops-nix | master | Encrypted secrets at build time |
| stylix | master | System-wide theming (follows nixpkgs) |
| vainim | external flake | Neovim configuration (symlinked, not managed) |

## System modules

### Core

| Module | Option | Description |
|--------|--------|-------------|
| **locale** | `systemSettings.core.locale.enable` | Timezone (`Europe/Bucharest`), UTF-8 locale. Enabled by default. |
| **nix** | `systemSettings.core.nix.enable` | Enables flakes, auto-optimise store, weekly GC keeping 30 days. Enabled by default. |
| **packages** | `systemSettings.core.packages.enable` | Base packages: vim, git, curl, wget, htop, tree. Enabled by default. |
| **users** | `systemSettings.core.users.enable` | Creates `wowvain` user with zsh, wheel group, SSH ed25519 key. Enabled by default. |
| **zsh** | `systemSettings.core.zsh.enable` | System-level zsh with vendor completions. Required for Home Manager zsh. Enabled by default. |
| **vainos-cli** | `systemSettings.core.vainos-cli.enable` | `vainos` CLI tool — see [CLI section](#vainos-cli) below. Enabled by default. |
| **auto-update** | `systemSettings.maintenance.autoUpdate.enable` | Systemd timer that runs `nix flake update` + `nixos-rebuild switch` on a configurable schedule (default: weekly) with randomized 6h delay. |

### Desktop (workstation only)

| Module | Option | Description |
|--------|--------|-------------|
| **hyprland** | `systemSettings.desktop.hyprland.enable` | Hyprland compositor with UWSM session management, XWayland, greetd/tuigreet login, XDG portals, PAM for hyprlock |
| **audio** | `systemSettings.desktop.audio.enable` | PipeWire with WirePlumber, 32-bit ALSA, PulseAudio compat, Bluetooth codecs (SBC-XQ, mSBC), rtkit |
| **gpu** | `systemSettings.desktop.gpu.enable` | AMD GPU (Mesa/RADV Vulkan), 32-bit support for Steam/Wine, early amdgpu in initrd |
| **bluetooth** | `systemSettings.desktop.bluetooth.enable` | Bluez with power-on-boot, Blueman GUI |
| **stylix** | `systemSettings.desktop.stylix.enable` | System-level Stylix theming with preset selection, font stack (FiraCode, Inter, Noto Serif, Noto Color Emoji), wallpaper |

**Theme presets** (set via `userSettings.theme`): `gruvbox-dark`, `catppuccin-latte`, `tokyo-night`

### Security

| Module | Option | Description |
|--------|--------|-------------|
| **doas** | `systemSettings.security.doas.enable` | Replaces sudo with doas. Wheel group, persist, keepEnv. Aliases `sudo` to `doas`. |
| **hosts-blocklist** | `systemSettings.security.hosts-blocklist.enable` | DNS-level ad/tracker blocking via StevenBlack hosts list (fakenews + gambling categories) |

### Server

| Module | Option | Description |
|--------|--------|-------------|
| **networking** | `systemSettings.server.networking.enable` | Static IP from `systemSettings.networking`, SSH key-only auth, fail2ban (5 retries, 1h ban), firewall (22/80/443 TCP only) |
| **caddy** | `systemSettings.server.caddy.enable` | Reverse proxy: `/static/*` serves `/srv/www`, everything else proxies to `127.0.0.1:3000` |
| **podman** | `systemSettings.server.podman.enable` | Podman container runtime with Docker CLI compatibility |
| **containers** | `systemSettings.server.containers.enable` | OCI container declarations with sops-nix secret injection. Default: whoami test container on port 3000. |

## User modules (Home Manager)

### Always-available

| Module | Option | Description |
|--------|--------|-------------|
| **shell** | `userSettings.shell.enable` | Zsh with completions, autosuggestions, syntax highlighting, 10k history (no dupes), Starship prompt. Enabled by default. |
| **git** | `userSettings.git.enable` | Git config (`wowvain-dev`), aliases (co/ci/st/br/lg), rebase pulls, auto-setup remote. Enabled by default. |
| **neovim** | `userSettings.neovim.enable` | Neovim with LSPs (lua, python, typescript, yaml, bash, rust, go, clang, odin, markdown), formatters (stylua, prettier). Config managed externally by vainim (symlinked). Enabled by default. |
| **gpg** | `userSettings.gpg.enable` | GPG agent with SSH integration, 1h/24h cache, curses pinentry. Enabled by default. |
| **dev-tools** | `userSettings.devTools.enable` | Toolchains: Rust, Go, Python, Node/TS, C/C++, Haskell, Lua, Dart, Java, Odin. CLI: ripgrep, fd, jq. Enabled by default. |
| **update-notify** | `userSettings.updateNotify.enable` | Zsh login hook that shows a message when flake inputs were updated but not yet applied. Enabled by default. |

### Desktop (workstation only)

| Module | Option | Description |
|--------|--------|-------------|
| **hyprland** | `userSettings.desktop.hyprland.enable` | Window management keybinds (SUPER mod), workspace config, gaps/borders, app launch bindings |
| **waybar** | `userSettings.desktop.waybar.enable` | Top bar: workspaces, clock, volume, network, CPU, memory, tray |
| **kitty** | `userSettings.desktop.kitty.enable` | Terminal: 10k scrollback, no bell, 0.95 opacity, 4px padding |
| **fuzzel** | `userSettings.desktop.fuzzel.enable` | Application launcher on overlay layer |
| **mako** | `userSettings.desktop.mako.enable` | Notification daemon: 5s timeout, rounded borders |
| **hyprlock** | `userSettings.desktop.hyprlock.enable` | Screen lock + hypridle (lock at 5min, DPMS off at 10min, lock before sleep) |
| **clipboard** | `userSettings.desktop.clipboard.enable` | Clipboard history via cliphist + wl-clipboard (Super+C) |
| **screenshots** | `userSettings.desktop.screenshots.enable` | grim + slurp screenshots to `~/Pictures/Screenshots/` (Print / Super+Print) |
| **stylix** | `userSettings.desktop.stylix.enable` | Per-app Stylix targets: kitty, waybar, fuzzel, mako, hyprland, hyprlock, GTK, Qt |

## vainos CLI

The `vainos` command is a shell wrapper for common operations:

```
vainos sync [host]       Rebuild locally or deploy to a remote host via SSH
vainos update [--rebuild]  Update flake inputs, optionally rebuild immediately
vainos gc [full]         Garbage collect (30 days default, or all old generations)
vainos status            Show current generation, flake revision, pending changes
vainos help              Show usage
```

Deployment reads SSH targets from `local/deploy.env`. Uses `doas` for privilege escalation.

## Local configuration

Machine-specific values (IPs, interfaces, SSH targets) are kept in `local/` and gitignored. Copy the examples to get started:

```bash
cp local/server.nix.example local/server.nix
cp local/workstation.nix.example local/workstation.nix
cp local/deploy.env.example local/deploy.env
```

**`local/server.nix`** — static networking:
```nix
{
  systemSettings.networking = {
    ipv4.address = "203.0.113.10";
    ipv4.prefixLength = 24;
    ipv4.gateway = "203.0.113.1";
    ipv6.addresses = [ "2001:db8::1/64" ];
    ipv6.gateway = "2001:db8::";
    nameservers = [ "1.1.1.1" "9.9.9.9" ];
    interface = "eth0";
  };
}
```

**`local/deploy.env`** — SSH target for remote rebuild:
```makefile
SERVER_SSH = root@203.0.113.10
```

The flake uses `--impure` to read these files at build time since they're outside the flake's tracked inputs.

## Secrets management

Secrets are encrypted with [sops-nix](https://github.com/Mic92/sops-nix) using age keys.

**What's in the repo and why it's safe:**

- **`.sops.yaml`** — contains age **public** keys and file matching rules. Public keys can only *encrypt*, not decrypt. This file must be in the repo for sops to know which keys to encrypt to.
- **`secrets/secrets.yaml`** — contains encrypted secret values (e.g., container environment variables). The encrypted blobs are useless without the corresponding age private keys, which live only on the target machines (`/etc/ssh/ssh_host_ed25519_key` for the server).

Neither file exposes sensitive information. The private keys needed to decrypt never leave the target hosts.

**Adding a secret:**
```bash
# Edit (decrypts in-place, re-encrypts on save)
sops secrets/secrets.yaml

# Reference in a module
sops.secrets.my-secret = {
  sopsFile = ../../secrets/secrets.yaml;
  key = "my-secret";
};
```

## Makefile targets

```bash
make switch-server         # Deploy to server via SSH
make switch-workstation    # Rebuild workstation locally
make boot-server           # Deploy to server (apply on next boot)
make check                 # Run nix flake check
make update                # Run nix flake update
```

## Adding a new module

1. Create `modules/system/<category>/<name>/default.nix` (or `modules/user/...` for Home Manager)
2. Declare an enable option under `systemSettings` or `userSettings`
3. Guard all config with `lib.mkIf cfg.enable { ... }`
4. Enable it in the relevant host's `default.nix`

The module is auto-discovered — no import lists to update.

## Adding a new host

1. Create `hosts/<name>/default.nix` with `systemSettings.system = "x86_64-linux"` and desired module enables
2. Add `hosts/<name>/hardware-configuration.nix` (from `nixos-generate-config`)
3. Optionally add `hosts/<name>/base.nix` for boot/hardware config
4. Create `local/<name>.nix` for machine-specific values
5. The flake auto-discovers it — `nixosConfigurations.<name>` is immediately available

## License

Personal configuration. Use as reference or fork as you like.
