# vainos CLI wrapper -- single command for rebuild, update, gc, and status
{ config, lib, pkgs, ... }:

let
  cfg = config.systemSettings.core.vainos-cli;
in
{
  options.systemSettings.core.vainos-cli = {
    enable = lib.mkEnableOption "vainos CLI management tool" // { default = true; };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      (pkgs.writeShellApplication {
        name = "vainos";
        runtimeInputs = [ pkgs.coreutils pkgs.findutils pkgs.gnugrep pkgs.gawk pkgs.git pkgs.nix pkgs.nixos-rebuild pkgs.procps ];
        text = ''
          # --- Configuration ---
          VAINOS_ROOT="''${VAINOS_ROOT:-/etc/vainos}"

          # Wrapper: run podman as root (doas if needed, direct if already root)
          pm() {
            if [ "$(id -u)" -eq 0 ]; then
              podman "$@"
            else
              doas podman "$@"
            fi
          }
          if [ ! -f "$VAINOS_ROOT/flake.nix" ]; then
            echo "Error: No flake.nix found at $VAINOS_ROOT"
            echo "Set VAINOS_ROOT to your vainos flake directory"
            exit 1
          fi

          # --- Helper: show usage ---
          usage() {
            echo "vainos -- NixOS configuration management"
            echo ""
            echo "Usage: vainos <command> [options]"
            echo ""
            echo "Commands:"
            echo "  vainos home               Rebuild user config only (fast, no sudo)"
            echo "  vainos sync [host]        Rebuild local (default) or deploy to remote host"
            echo "  vainos update [--rebuild]  Update flake inputs; optionally rebuild after"
            echo "  vainos gc [full]           Garbage-collect old generations (default: 30d retention)"
            echo "  vainos status              Show current generation, flake revision, and changes"
            echo "  vainos game <cmd>          Manage game servers (start, stop, list, status, logs)"
            echo "  vainos help                Show this help message"
          }

          # --- Subcommand: sync ---
          cmd_sync() {
            if [ $# -eq 0 ]; then
              # Local rebuild
              echo ":: Rebuilding local system..."
              doas nixos-rebuild switch --flake "$VAINOS_ROOT#$(hostname)" --impure
            else
              # Remote deploy
              local host="$1"
              local var_name
              var_name="$(echo "$host" | tr '[:lower:]' '[:upper:]')_SSH"

              # Source deploy.env for SSH target
              if [ -f "$VAINOS_ROOT/local/deploy.env" ]; then
                # deploy.env uses Makefile syntax (VAR = value), parse it
                local target
                target="$(grep "^''${var_name}" "$VAINOS_ROOT/local/deploy.env" | head -1 | sed 's/.*=[ ]*//')"
                if [ -z "$target" ]; then
                  echo "Error: Variable $var_name not found in $VAINOS_ROOT/local/deploy.env"
                  exit 1
                fi
              else
                echo "Error: $VAINOS_ROOT/local/deploy.env not found"
                echo "Create it with: $var_name = user@host"
                exit 1
              fi

              echo ":: Deploying to $host ($target)..."
              nixos-rebuild switch \
                --flake "$VAINOS_ROOT#$host" --impure \
                --target-host "$target" \
                --build-host localhost
            fi
          }

          # --- Subcommand: update ---
          cmd_update() {
            local do_rebuild=false
            while [ $# -gt 0 ]; do
              case "$1" in
                --rebuild) do_rebuild=true ;;
                *) echo "Error: Unknown option '$1' for update"; exit 1 ;;
              esac
              shift
            done

            echo ":: Updating flake inputs..."
            nix flake update --flake "$VAINOS_ROOT"

            if [ "$do_rebuild" = true ]; then
              echo ":: Rebuilding after update..."
              cmd_sync
            fi
          }

          # --- Subcommand: gc ---
          cmd_gc() {
            if [ "''${1:-}" = "full" ]; then
              echo ":: Full garbage collection (removing all old generations)..."
              doas nix-collect-garbage -d
            else
              echo ":: Garbage collection (keeping last 30 days)..."
              doas nix-collect-garbage --delete-older-than 30d
            fi

            echo ":: Nix store size:"
            du -sh /nix/store 2>/dev/null | cut -f1
          }

          # --- Subcommand: status ---
          cmd_status() {
            echo "vainos status"

            # Current generation
            local gen
            gen="$(doas nix-env --list-generations --profile /nix/var/nix/profiles/system 2>/dev/null | tail -1 | sed 's/^[ ]*//')"
            echo "  generation: ''${gen:-unknown}"

            # Flake revision
            local rev
            rev="$(git -C "$VAINOS_ROOT" rev-parse --short HEAD 2>/dev/null || echo "not a git repo")"
            echo "  flake rev:  $rev"

            # Uncommitted changes
            local changes
            changes="$(git -C "$VAINOS_ROOT" status --porcelain 2>/dev/null)"
            if [ -n "$changes" ]; then
              local count
              count="$(echo "$changes" | wc -l | tr -d ' ')"
              echo "  changes:    $count uncommitted files"
            else
              echo "  changes:    clean"
            fi
          }

          PASSWORD_DIR="/var/lib/vainos-games/passwords"

          # --- Helper: generate and persist a game password ---
          generate_password() {
            local name="$1"
            local pw_type="$2"  # "numeric" or "alphanumeric"
            local pw_file="''${PASSWORD_DIR}/''${name}.txt"
            mkdir -p "$PASSWORD_DIR"
            local password
            if [ "$pw_type" = "numeric" ]; then
              password="$(shuf -i 1-9 -n 4 | tr -d '\n')"
            else
              password="$(head -c 16 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 16)"
            fi
            echo -n "$password" > "$pw_file"
            echo "$password"
          }

          # --- Helper: read existing password for a game ---
          read_password() {
            local name="$1"
            local pw_file="''${PASSWORD_DIR}/''${name}.txt"
            if [ -f "$pw_file" ]; then
              cat "$pw_file"
            fi
          }

          # --- Helper: load game config from registry .env ---
          load_game_config() {
            local name="$1"
            local env_file="/etc/vainos/games/''${name}.env"
            if [ ! -f "$env_file" ]; then
              echo "Error: Unknown game '$name'"
              echo "Available games: $(find /etc/vainos/games/ -maxdepth 1 -name '*.env' -printf '%f\n' 2>/dev/null | sed 's/\.env$//' | tr '\n' ' ')"
              exit 1
            fi
            # shellcheck source=/dev/null
            source "$env_file"
          }

          # --- Helper: parse memory string to MB (e.g., "4G" -> 4096, "512m" -> 512) ---
          parse_memory_mb() {
            local mem="$1"
            local num="''${mem%[GgMm]}"
            local suffix="''${mem: -1}"
            case "$suffix" in
              G|g) echo $((num * 1024)) ;;
              M|m) echo "$num" ;;
              *)   echo "$num" ;;
            esac
          }

          # --- Helper: memory pre-flight check (SAFE-01) ---
          check_memory() {
            local required_mb
            required_mb=$(parse_memory_mb "$GAME_MEMORY")
            local available_mb
            available_mb=$(free -m | awk '/^Mem:/ {print $7}')

            if [ "$available_mb" -lt "$required_mb" ]; then
              echo "Error: Insufficient memory"
              echo "  Required: ''${GAME_MEMORY} (''${required_mb} MB)"
              echo "  Available: ''${available_mb} MB"
              echo "  Use --force to bypass this check"
              exit 1
            fi
          }

          # --- Subcommand: game start (CLI-07, SAFE-01, SAFE-02) ---
          game_start() {
            local name="$1"
            local force=false
            local -a extra_envs=()
            shift || true
            while [ $# -gt 0 ]; do
              case "$1" in
                --force) force=true ;;
                --env)
                  shift
                  if [ $# -eq 0 ]; then
                    echo "Error: --env requires a KEY=VALUE argument"
                    exit 1
                  fi
                  extra_envs+=("$1")
                  ;;
                --env=*)
                  extra_envs+=("''${1#--env=}")
                  ;;
              esac
              shift
            done

            load_game_config "$name"

            # Check if already running
            if pm ps -q --filter "name=^game-''${name}$" 2>/dev/null | grep -q .; then
              echo "Error: game-''${name} is already running"
              echo "Use 'vainos game stop ''${name}' first"
              exit 1
            fi

            # Clean up dead container with same name
            pm rm "game-''${name}" 2>/dev/null || true

            # Memory pre-flight (SAFE-01)
            if [ "$force" != true ]; then
              check_memory
            fi

            # Auto-shutdown: if MAX_RUNNING_GAMES reached, stop an empty server
            local running_games
            running_games="$(pm ps --format '{{.Names}}' 2>/dev/null | grep '^game-' || true)"
            local running_count
            running_count="$(echo "$running_games" | grep -c . || true)"
            if [ "$running_count" -ge "$MAX_RUNNING_GAMES" ]; then
              echo "''${running_count} game(s) already running (max ''${MAX_RUNNING_GAMES}). Checking for empty servers..."
              local stopped_one=false
              while IFS= read -r container_name; do
                [ -n "$container_name" ] || continue
                local gname="''${container_name#game-}"
                local players
                players="$(count_players "$gname")"
                if [ "$players" -eq 0 ]; then
                  echo "Auto-stopping empty server: ''${gname}"
                  game_stop "$gname"
                  stopped_one=true
                  break
                fi
              done <<< "$running_games"
              if [ "$stopped_one" != true ]; then
                echo "Error: all running servers have active players, cannot free resources"
                echo "Stop a server manually first: vainos game stop <name>"
                exit 1
              fi
            fi

            echo "Starting ''${name}..."

            # --- Password generation (CLI owns this) ---
            local password=""
            if [ -n "$GAME_PASSWORD_ENV" ]; then
              password="$(generate_password "$name" "$GAME_PASSWORD_TYPE")"
              extra_envs+=("''${GAME_PASSWORD_ENV}=''${password}")
            fi

            # Build podman run command from .env variables
            local -a cmd_args=(run -d -i
              --name "game-''${name}"
              --restart always
              --memory "$GAME_MEMORY"
              --oom-score-adj 500
            )

            # Add ports (PORT_0="25565/tcp" -> -p 25565:25565/tcp)
            local env_file="/etc/vainos/games/''${name}.env"
            for ((i=0; i<PORT_COUNT; i++)); do
              local var="PORT_''${i}"
              local spec="''${!var}"
              spec="''${spec%\"}"
              spec="''${spec#\"}"
              local port="''${spec%%/*}"
              cmd_args+=(-p "''${port}:''${spec}")
            done

            # Add volumes (VOLUME_0="/srv/games/minecraft/data:/data" -> -v ...)
            for ((i=0; i<VOLUME_COUNT; i++)); do
              local var="VOLUME_''${i}"
              local vol="''${!var}"
              vol="''${vol%\"}"
              vol="''${vol#\"}"
              cmd_args+=(-v "$vol")
            done

            # Add environment variables (ENV_EULA="TRUE" -> -e EULA=TRUE)
            while IFS='=' read -r key value; do
              local env_key="''${key#ENV_}"
              value="''${value%\"}"
              value="''${value#\"}"
              cmd_args+=(-e "''${env_key}=''${value}")
            done < <(grep '^ENV_' "$env_file")

            # Add extra env overrides (--env flags + generated password)
            for env_override in "''${extra_envs[@]}"; do
              cmd_args+=(-e "$env_override")
            done

            # --- Pre-start password hooks (write password to game-specific config) ---
            if [ -n "$password" ]; then
              # Helper: find host path for a container mount
              find_host_vol() {
                local target="$1"
                for ((i=0; i<VOLUME_COUNT; i++)); do
                  local var="VOLUME_''${i}"
                  local vol="''${!var}"
                  vol="''${vol%\"}"
                  vol="''${vol#\"}"
                  if [[ "$vol" == *":''${target}" ]]; then
                    echo "''${vol%%:*}"
                    return
                  fi
                done
              }

              case "$GAME_PASSWORD_WRITE" in
                minecraft-plugin)
                  local data_vol
                  data_vol="$(find_host_vol /data)"
                  if [ -n "$data_vol" ]; then
                    local pw_plugin_dir="''${data_vol}/plugins/Passwords"
                    mkdir -p "$pw_plugin_dir"
                    cat > "''${pw_plugin_dir}/config.yml" <<PWCFG
check-type: server
server:
  password: $password
  staff-password: $password
PWCFG
                    chown -R 1000:1000 "''${data_vol}/plugins"
                  fi
                  ;;
                zomboid-ini)
                  local data_vol
                  data_vol="$(find_host_vol /home/steam/Zomboid)"
                  if [ -n "$data_vol" ]; then
                    # Find the server .ini file (name matches SERVER_NAME env)
                    local ini_file
                    ini_file="$(find "$data_vol/Server/" -maxdepth 1 -name '*.ini' -print -quit 2>/dev/null)"
                    if [ -n "$ini_file" ]; then
                      sed -i "s/^Password=.*/Password=''${password}/" "$ini_file"
                    fi
                  fi
                  ;;
              esac
            fi

            # Add image
            cmd_args+=("$GAME_IMAGE")

            # Run container
            local container_id
            container_id=$(pm "''${cmd_args[@]}")
            echo "Container: ''${container_id:0:12}"

            # Show ports
            local ports=""
            for ((i=0; i<PORT_COUNT; i++)); do
              local var="PORT_''${i}"
              local spec="''${!var}"
              spec="''${spec%\"}"
              spec="''${spec#\"}"
              local port="''${spec%%/*}"
              ports+="''${port} "
            done
            echo "Ports: ''${ports}"

            # Wait for server to be ready
            if [ -n "$GAME_READY_PATTERN" ]; then
              local timeout=300
              local elapsed=0
              printf "Waiting for server to be ready "
              while [ "$elapsed" -lt "$timeout" ]; do
                if pm logs "game-''${name}" 2>&1 | grep -q "$GAME_READY_PATTERN"; then
                  printf "\n"
                  echo "Server is live!"
                  if [ -n "$password" ]; then
                    echo "Password: $password"
                  fi
                  return
                fi
                # Check container is still running
                if ! pm ps -q --filter "name=^game-''${name}$" 2>/dev/null | grep -q .; then
                  printf "\n"
                  echo "Error: container exited unexpectedly"
                  exit 1
                fi
                printf "."
                sleep 5
                elapsed=$((elapsed + 5))
              done
              printf "\n"
              echo "Warning: server did not become ready within ''${timeout}s (may still be starting)"
            fi

            if [ -n "$password" ]; then
              echo "Password: $password"
            fi
          }

          # --- Subcommand: game stop (CLI-08, SAFE-03) ---
          game_stop() {
            local name="$1"
            load_game_config "$name"

            # Check if running
            if ! pm ps -q --filter "name=^game-''${name}$" 2>/dev/null | grep -q .; then
              echo "Error: game-''${name} is not running"
              exit 1
            fi

            # Registry-driven graceful shutdown (SAFE-03)
            case "$GAME_SHUTDOWN_METHOD" in
              rcon)
                echo "Saving world..."
                pm exec "game-''${name}" rcon-cli save-all || true
                sleep 5
                echo "Stopping server..."
                # Use podman stop (SIGTERM) -- mc-server-runner handles graceful shutdown
                # Do NOT use rcon-cli stop: it kills the Java process but mc-server-runner restarts it
                pm stop --time 30 "game-''${name}"
                ;;
              signal)
                echo "Stopping ''${name}..."
                pm kill --signal="''${GAME_SHUTDOWN_SIGNAL}" "game-''${name}"
                pm stop --time 30 "game-''${name}" 2>/dev/null || true
                ;;
              *)
                echo "Stopping ''${name}..."
                pm stop --time 30 "game-''${name}"
                ;;
            esac

            # Remove container to clear restart-always intent (so it stays stopped across reboots)
            pm rm "game-''${name}" 2>/dev/null || true
            echo "Stopped."
          }

          # --- Subcommand: game list (CLI-09) ---
          game_list() {
            # Fetch running containers once to avoid multiple doas prompts
            local running_containers
            running_containers="$(pm ps --format '{{.Names}}' 2>/dev/null || true)"
            printf "%-12s %-10s %-20s %s\n" "GAME" "STATUS" "PORTS" "MEMORY"
            for env_file in /etc/vainos/games/*.env; do
              [ -f "$env_file" ] || continue
              # Source in subshell to avoid variable pollution between games
              (
                # shellcheck disable=SC1090
                source "$env_file"
                local status="stopped"
                if echo "$running_containers" | grep -q "^game-''${GAME_NAME}$"; then
                  status="running"
                fi
                # Build port display
                local ports=""
                for ((i=0; i<PORT_COUNT; i++)); do
                  local var="PORT_''${i}"
                  local spec="''${!var}"
                  spec="''${spec%\"}"
                  spec="''${spec#\"}"
                  ports+="''${spec} "
                done
                printf "%-12s %-10s %-20s %s\n" "$GAME_NAME" "$status" "$ports" "$GAME_MEMORY"
              )
            done
          }

          # --- Subcommand: game status (CLI-10) ---
          game_status() {
            local name="$1"
            if ! pm ps -q --filter "name=^game-''${name}$" 2>/dev/null | grep -q .; then
              echo "Error: game-''${name} is not running"
              exit 1
            fi
            pm stats --no-stream "game-''${name}"
          }

          # --- Subcommand: game logs (CLI-11) ---
          game_logs() {
            local name="$1"
            if ! pm ps -q --filter "name=^game-''${name}$" 2>/dev/null | grep -q .; then
              echo "Error: game-''${name} is not running"
              exit 1
            fi
            pm logs -f "game-''${name}"
          }

          BACKUP_DIR="/srv/games/backups"
          MAX_RUNNING_GAMES=2

          # --- Helper: count players on a running game ---
          count_players() {
            local name="$1"
            local env_file="/etc/vainos/games/''${name}.env"
            # shellcheck source=/dev/null
            source "$env_file"
            case "$GAME_PLAYER_CHECK" in
              rcon-query)
                local output
                output="$(pm exec "game-''${name}" rcon-cli list 2>/dev/null)" || { echo "0"; return; }
                local count
                count="$(echo "$output" | grep -oP 'There are \K\d+')" || { echo "0"; return; }
                echo "$count"
                ;;
              log-parse)
                local logs
                logs="$(pm logs --tail 500 "game-''${name}" 2>&1)"
                local connects disconnects
                connects="$(echo "$logs" | grep -cE 'Got handshake from client|is trying to connect|logged in with entity' || true)"
                disconnects="$(echo "$logs" | grep -cE 'Closing socket|Disconnecting client|lost connection|left the game' || true)"
                local active=$(( connects - disconnects ))
                if [ "$active" -lt 0 ]; then active=0; fi
                echo "$active"
                ;;
              *)
                echo "0"
                ;;
            esac
          }

          # --- Subcommand: game players (query online players) ---
          game_players() {
            local name="''${1:-}"
            local running_containers
            running_containers="$(pm ps --format '{{.Names}}' 2>/dev/null || true)"

            if [ -n "$name" ]; then
              if ! echo "$running_containers" | grep -q "^game-''${name}$"; then
                echo "''${name}: stopped"
                return
              fi
              local count
              count="$(count_players "$name")"
              echo "''${name}: ''${count} player(s)"
            else
              # Show all running games
              for env_file in /etc/vainos/games/*.env; do
                [ -f "$env_file" ] || continue
                local gname
                gname="$(grep '^GAME_NAME=' "$env_file" | cut -d= -f2)"
                if echo "$running_containers" | grep -q "^game-''${gname}$"; then
                  local count
                  count="$(count_players "$gname")"
                  printf "%-12s %s player(s)\n" "$gname" "$count"
                else
                  printf "%-12s stopped\n" "$gname"
                fi
              done
            fi
          }

          # --- Subcommand: game cmd (one-shot command execution) ---
          game_cmd() {
            local name="$1"
            shift
            local cmd_text="$*"
            if [ -z "$cmd_text" ]; then
              echo "Usage: vainos game cmd <name> <command>"
              exit 1
            fi
            load_game_config "$name"

            if ! pm ps -q --filter "name=^game-''${name}$" 2>/dev/null | grep -q .; then
              echo "Error: game-''${name} is not running"
              exit 1
            fi

            if [ "$GAME_CONSOLE_METHOD" != "rcon" ]; then
              echo "Error: game '$name' does not support remote commands (no RCON)"
              exit 1
            fi
            pm exec "game-''${name}" rcon-cli "$cmd_text"
          }

          # --- Subcommand: game console (interactive admin session) ---
          game_console() {
            local name="$1"
            load_game_config "$name"

            if ! pm ps -q --filter "name=^game-''${name}$" 2>/dev/null | grep -q .; then
              echo "Error: game-''${name} is not running"
              exit 1
            fi

            case "$GAME_CONSOLE_METHOD" in
              rcon)
                echo "Connecting to ''${name} RCON console (type 'exit' or Ctrl-C to quit)..."
                pm exec -it "game-''${name}" rcon-cli
                ;;
              attach)
                echo "Attaching to ''${name} server console (press Ctrl+P then Ctrl+Q to detach)..."
                pm attach --detach-keys="ctrl-p,ctrl-q" "game-''${name}"
                ;;
              *)
                echo "''${name} does not have a server console."
                echo "Admin management is done in-game or via config files."
                echo "Config directory: /srv/games/''${name}/"
                ;;
            esac
          }

          # --- Subcommand: game backup (snapshot world data) ---
          game_backup() {
            local name="$1"
            load_game_config "$name"

            local game_dir="/srv/games/''${name}"
            if [ ! -d "$game_dir" ]; then
              echo "Error: no data directory for '$name'"
              exit 1
            fi

            mkdir -p "''${BACKUP_DIR}/''${name}"
            local timestamp
            timestamp="$(date +%Y%m%d-%H%M%S)"
            local backup_file="''${BACKUP_DIR}/''${name}/''${timestamp}.tar.gz"

            echo "Backing up ''${name}..."

            # If server is running with RCON, save world first
            if pm ps -q --filter "name=^game-''${name}$" 2>/dev/null | grep -q .; then
              if [ "$GAME_SHUTDOWN_METHOD" = "rcon" ]; then
                echo "Saving world before backup..."
                pm exec "game-''${name}" rcon-cli save-all 2>/dev/null || true
                sleep 3
              fi
            fi

            tar -czf "$backup_file" -C /srv/games "$name"
            local size
            size="$(du -h "$backup_file" | cut -f1)"
            echo "Backup saved: $backup_file ($size)"

            # Keep only last 5 backups per game
            local count
            count="$(find "''${BACKUP_DIR}/''${name}" -name '*.tar.gz' | wc -l)"
            if [ "$count" -gt 5 ]; then
              find "''${BACKUP_DIR}/''${name}" -name '*.tar.gz' -printf '%T+ %p\n' | sort | head -n $((count - 5)) | cut -d' ' -f2- | while read -r old; do
                rm -f "$old"
                echo "Pruned old backup: $old"
              done
            fi
          }

          # --- Subcommand: game restore (restore from backup) ---
          game_restore() {
            local name="$1"
            local backup_dir="''${BACKUP_DIR}/''${name}"

            if [ ! -d "$backup_dir" ]; then
              echo "Error: no backups found for '$name'"
              exit 1
            fi

            # If a specific file is provided as $2, use it; otherwise use latest
            local backup_file
            if [ -n "''${2:-}" ]; then
              backup_file="$2"
            else
              backup_file="$(find "$backup_dir" -name '*.tar.gz' -printf '%T+ %p\n' | sort -r | head -1 | cut -d' ' -f2-)"
            fi

            if [ -z "$backup_file" ] || [ ! -f "$backup_file" ]; then
              echo "Error: no backup file found"
              echo "Available backups:"
              find "$backup_dir" -name '*.tar.gz' -printf '  %f (%s bytes)\n' 2>/dev/null
              exit 1
            fi

            # Server must be stopped
            if pm ps -q --filter "name=^game-''${name}$" 2>/dev/null | grep -q .; then
              echo "Error: stop the server first (vainos game stop ''${name})"
              exit 1
            fi

            echo "Restoring ''${name} from: $(basename "$backup_file")"
            echo "This will OVERWRITE current data in /srv/games/''${name}/"
            echo "Press Enter to continue or Ctrl-C to cancel..."
            read -r

            rm -rf "/srv/games/''${name}"
            tar -xzf "$backup_file" -C /srv/games
            echo "Restored."
          }

          # --- Subcommand: game update (pull latest image + restart) ---
          game_update() {
            local name="$1"
            load_game_config "$name"

            echo "Backing up ''${name} before update..."
            game_backup "$name"

            echo "Pulling latest image: ''${GAME_IMAGE}..."
            pm pull "$GAME_IMAGE"

            # If running, stop and restart
            if pm ps -q --filter "name=^game-''${name}$" 2>/dev/null | grep -q .; then
              echo "Stopping ''${name} for update..."
              game_stop "$name"
              echo "Starting ''${name} with updated image..."
              game_start "$name" --force
            else
              echo "Image updated. Start with: vainos game start ''${name}"
            fi
          }

          # --- Subcommand: game password (show current password) ---
          game_password() {
            local name="$1"
            local pw_file="''${PASSWORD_DIR}/''${name}.txt"
            if [ ! -f "$pw_file" ]; then
              echo "No password set for '$name' (generates on next start)"
              exit 0
            fi
            cat "$pw_file"
          }

          # --- Subcommand: game (sub-dispatcher) ---
          cmd_game() {
            if [ $# -eq 0 ]; then
              echo "Usage: vainos game <command> [args]"
              echo ""
              echo "Commands:"
              echo "  start <name> [--force]  Start a game server"
              echo "  stop <name>             Stop a game server (graceful shutdown)"
              echo "  list                    List all games and their status"
              echo "  status <name>           Show game server resource usage"
              echo "  logs <name>             Follow game server logs"
              echo "  password <name>         Show current server password"
              echo "  players [name]          Show online player count"
              echo "  cmd <name> <command>    Run a one-shot command (RCON)"
              echo "  console <name>          Interactive admin console"
              echo "  update <name>           Pull latest image, backup, and restart"
              echo "  backup <name>           Backup world data"
              echo "  restore <name> [file]   Restore from backup (latest or specific)"
              exit 0
            fi

            local subcmd="$1"
            shift

            case "$subcmd" in
              start)
                if [ $# -eq 0 ]; then echo "Usage: vainos game start <name> [--force] [--env KEY=VALUE]"; exit 1; fi
                game_start "$@"
                ;;
              stop)
                if [ $# -eq 0 ]; then echo "Usage: vainos game stop <name>"; exit 1; fi
                game_stop "$1"
                ;;
              list)   game_list ;;
              status)
                if [ $# -eq 0 ]; then echo "Usage: vainos game status <name>"; exit 1; fi
                game_status "$1"
                ;;
              logs)
                if [ $# -eq 0 ]; then echo "Usage: vainos game logs <name>"; exit 1; fi
                game_logs "$1"
                ;;
              password)
                if [ $# -eq 0 ]; then echo "Usage: vainos game password <name>"; exit 1; fi
                game_password "$1"
                ;;
              players) game_players "''${1:-}" ;;
              cmd)
                if [ $# -lt 2 ]; then echo "Usage: vainos game cmd <name> <command>"; exit 1; fi
                game_cmd "$@"
                ;;
              console)
                if [ $# -eq 0 ]; then echo "Usage: vainos game console <name>"; exit 1; fi
                game_console "$1"
                ;;
              update)
                if [ $# -eq 0 ]; then echo "Usage: vainos game update <name>"; exit 1; fi
                game_update "$1"
                ;;
              backup)
                if [ $# -eq 0 ]; then echo "Usage: vainos game backup <name>"; exit 1; fi
                game_backup "$1"
                ;;
              restore)
                if [ $# -eq 0 ]; then echo "Usage: vainos game restore <name> [file]"; exit 1; fi
                game_restore "$@"
                ;;
              *)
                echo "Error: Unknown game command '$subcmd'"
                echo "Run 'vainos game' for usage"
                exit 1
                ;;
            esac
          }

          # --- Main dispatch ---
          if [ $# -eq 0 ]; then
            usage
            exit 0
          fi

          command="$1"
          shift

          # --- Subcommand: home ---
          cmd_home() {
            echo ":: Rebuilding user config..."
            # Uses 'test' to build + activate home-manager without touching bootloader
            doas nixos-rebuild test --flake "$VAINOS_ROOT#$(hostname)" --impure --fast
          }

          case "$command" in
            home)   cmd_home ;;
            sync)   cmd_sync "$@" ;;
            update) cmd_update "$@" ;;
            gc)     cmd_gc "$@" ;;
            status) cmd_status ;;
            game)   cmd_game "$@" ;;
            help)   usage ;;
            *)
              echo "Error: Unknown command '$command'"
              echo ""
              usage
              exit 1
              ;;
          esac
        '';
      })
    ];
  };
}
