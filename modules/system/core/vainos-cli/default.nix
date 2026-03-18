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
          VAINOS_ROOT="''${VAINOS_ROOT:-/etc/nixos}"
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
            shift || true
            while [ $# -gt 0 ]; do
              case "$1" in
                --force) force=true ;;
              esac
              shift
            done

            load_game_config "$name"

            # Check if already running
            if podman container exists "game-''${name}" 2>/dev/null; then
              echo "Error: game-''${name} is already running"
              echo "Use 'vainos game stop ''${name}' first"
              exit 1
            fi

            # Memory pre-flight (SAFE-01)
            if [ "$force" != true ]; then
              check_memory
            fi

            echo "Starting ''${name}..."

            # Build podman run command from .env variables
            local cmd=(podman run -d
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
              # Remove quotes if present
              spec="''${spec%\"}"
              spec="''${spec#\"}"
              local port="''${spec%%/*}"
              cmd+=(-p "''${port}:''${spec}")
            done

            # Add volumes (VOLUME_0="/srv/games/minecraft/data:/data" -> -v ...)
            for ((i=0; i<VOLUME_COUNT; i++)); do
              local var="VOLUME_''${i}"
              local vol="''${!var}"
              vol="''${vol%\"}"
              vol="''${vol#\"}"
              cmd+=(-v "$vol")
            done

            # Add environment variables (ENV_EULA="TRUE" -> -e EULA=TRUE)
            while IFS='=' read -r key value; do
              local env_key="''${key#ENV_}"
              # Remove surrounding quotes if present
              value="''${value%\"}"
              value="''${value#\"}"
              cmd+=(-e "''${env_key}=''${value}")
            done < <(grep '^ENV_' "$env_file")

            # Add image
            cmd+=("$GAME_IMAGE")

            # Run container
            local container_id
            container_id=$("''${cmd[@]}")
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
            echo "Running on port(s): ''${ports}"
          }

          # --- Subcommand: game stop (CLI-08, SAFE-03) ---
          game_stop() {
            local name="$1"
            load_game_config "$name"

            # Check if running
            if ! podman container exists "game-''${name}" 2>/dev/null; then
              echo "Error: game-''${name} is not running"
              exit 1
            fi

            # Registry-driven graceful shutdown (SAFE-03)
            case "$GAME_SHUTDOWN_METHOD" in
              rcon)
                echo "Saving world..."
                podman exec "game-''${name}" rcon-cli save-all || true
                sleep 5
                echo "Stopping server..."
                # Use podman stop (SIGTERM) -- mc-server-runner handles graceful shutdown
                # Do NOT use rcon-cli stop: it kills the Java process but mc-server-runner restarts it
                podman stop --time 30 "game-''${name}"
                ;;
              signal)
                echo "Stopping ''${name}..."
                podman kill --signal="''${GAME_SHUTDOWN_SIGNAL}" "game-''${name}"
                podman stop --time 30 "game-''${name}" 2>/dev/null || true
                ;;
              *)
                echo "Stopping ''${name}..."
                podman stop --time 30 "game-''${name}"
                ;;
            esac

            # Remove container to clear restart-always intent (so it stays stopped across reboots)
            podman rm "game-''${name}" 2>/dev/null || true
            echo "Stopped."
          }

          # --- Subcommand: game list (CLI-09) ---
          game_list() {
            printf "%-12s %-10s %-20s %s\n" "GAME" "STATUS" "PORTS" "MEMORY"
            for env_file in /etc/vainos/games/*.env; do
              [ -f "$env_file" ] || continue
              # Source in subshell to avoid variable pollution between games
              (
                # shellcheck disable=SC1090
                source "$env_file"
                local status="stopped"
                if podman container exists "game-''${GAME_NAME}" 2>/dev/null; then
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
            if ! podman container exists "game-''${name}" 2>/dev/null; then
              echo "Error: game-''${name} is not running"
              exit 1
            fi
            podman stats --no-stream "game-''${name}"
          }

          # --- Subcommand: game logs (CLI-11) ---
          game_logs() {
            local name="$1"
            if ! podman container exists "game-''${name}" 2>/dev/null; then
              echo "Error: game-''${name} is not running"
              exit 1
            fi
            podman logs -f "game-''${name}"
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
              exit 0
            fi

            local subcmd="$1"
            shift

            case "$subcmd" in
              start)
                if [ $# -eq 0 ]; then echo "Usage: vainos game start <name> [--force]"; exit 1; fi
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

          case "$command" in
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
