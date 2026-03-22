#!/usr/bin/env bash
# Stream Deck+ dial → PipeWire virtual channel volume control
# Usage:
#   sd-vol <channel> <ticks>    — rotate: adjust volume (positive = up, negative = down)
#   sd-vol <channel> toggle     — press: mute/unmute
#
# Channel names: System, Game, Chat, Music, Browser
# OpenDeck "Dial rotate" passes %d (signed tick count) as the second arg.

CHANNEL="$1"
ACTION="$2"

if [ -z "$CHANNEL" ] || [ -z "$ACTION" ]; then
  echo "Usage: $0 <channel_name> <ticks|toggle>"
  exit 1
fi

# Ensure PipeWire session access (needed when called from Flatpak sandbox)
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

# Find the sink ID by node.name using pw-cli
SINK_ID=$(pw-cli ls Node 2>/dev/null | awk '/^\tid [0-9]/ { id = $2; gsub(/,/, "", id) } /node.name = "channel_'"${CHANNEL}"'"/ { print id; exit }')

if [ -z "$SINK_ID" ]; then
  echo "Channel 'channel_${CHANNEL}' not found"
  exit 1
fi

case "$ACTION" in
  toggle)
    wpctl set-mute "$SINK_ID" toggle
    ;;
  *)
    # Numeric ticks from OpenDeck dial rotation
    # Each tick = 2% volume change
    TICKS="$ACTION"
    if [ "$TICKS" -gt 0 ] 2>/dev/null; then
      AMOUNT=$((TICKS * 2))
      wpctl set-volume -l 1.5 "$SINK_ID" "${AMOUNT}%+"
    elif [ "$TICKS" -lt 0 ] 2>/dev/null; then
      AMOUNT=$(( -TICKS * 2 ))
      wpctl set-volume "$SINK_ID" "${AMOUNT}%-"
    fi
    ;;
esac
