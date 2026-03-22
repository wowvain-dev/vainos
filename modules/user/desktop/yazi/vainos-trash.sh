#!/usr/bin/env bash
# Centralized trash script — always uses ~/.local/share/Trash/
# regardless of source partition. Follows freedesktop .trashinfo format
# so files can be restored by any trash-spec tool.

set -euo pipefail

TRASH_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/Trash"
TRASH_FILES="$TRASH_DIR/files"
TRASH_INFO="$TRASH_DIR/info"

mkdir -p "$TRASH_FILES" "$TRASH_INFO"

for item in "$@"; do
  [ -e "$item" ] || continue

  abs_path="$(realpath "$item")"
  base_name="$(basename "$abs_path")"
  dest_name="$base_name"
  counter=1

  # Handle name collisions in trash
  while [ -e "$TRASH_FILES/$dest_name" ]; do
    dest_name="${base_name%.*}_${counter}"
    [ "${base_name}" != "${base_name%.*}" ] && dest_name="${dest_name}.${base_name##*.}"
    counter=$((counter + 1))
  done

  # Move file (cp+rm for cross-device, mv for same device)
  if mv "$abs_path" "$TRASH_FILES/$dest_name" 2>/dev/null; then
    :
  else
    cp -a "$abs_path" "$TRASH_FILES/$dest_name"
    rm -rf "$abs_path"
  fi

  # Write .trashinfo metadata
  cat > "$TRASH_INFO/$dest_name.trashinfo" <<EOF
[Trash Info]
Path=$abs_path
DeletionDate=$(date -u +%Y-%m-%dT%H:%M:%S)
EOF
done
