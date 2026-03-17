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
        runtimeInputs = [ pkgs.coreutils pkgs.gnugrep pkgs.git pkgs.nix pkgs.nixos-rebuild ];
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
