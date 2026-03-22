#!/usr/bin/env bash
# Toggle-able keybind cheatsheet generated live from Hyprland

# Toggle: if already open, kill it
if pkill -f "fuzzel --dmenu --prompt Keybinds"; then
  exit 0
fi

# Map dispatcher names to human-readable descriptions
describe() {
  local dispatcher="$1" arg="$2"
  case "$dispatcher" in
    exec)                          echo "$arg" ;;
    killactive)                    echo "Kill window" ;;
    fullscreen)                    echo "Fullscreen" ;;
    togglefloating)                echo "Toggle floating" ;;
    movefocus)                     echo "Focus $arg" ;;
    swapwindow)                    echo "Swap window $arg" ;;
    resizeactive)                  echo "Resize window" ;;
    togglesplit)                   echo "Toggle split direction" ;;
    pin)                           echo "Pin floating window" ;;
    togglegroup)                   echo "Toggle group (tabbed)" ;;
    changegroupactive)             echo "Cycle group windows" ;;
    togglespecialworkspace)        echo "Toggle scratchpad" ;;
    movetoworkspace)
      case "$arg" in
        special:*) echo "Move to scratchpad" ;;
        *)         echo "Move window to workspace $arg" ;;
      esac ;;
    focusworkspaceoncurrentmonitor) echo "Go to workspace $arg" ;;
    workspace)                      echo "Go to workspace $arg" ;;
    movecurrentworkspacetomonitor)  echo "Workspace to monitor $arg" ;;
    movewindow)                     echo "Move window (drag)" ;;
    resizewindow)                   echo "Resize window (drag)" ;;
    *)                              echo "$dispatcher $arg" ;;
  esac
}

# Decode modifier bitmask to readable string
decode_mods() {
  local mask="$1" result=""
  (( mask & 64 )) && result+="Super + "
  (( mask & 4 ))  && result+="Ctrl + "
  (( mask & 8 ))  && result+="Alt + "
  (( mask & 1 ))  && result+="Shift + "
  echo "${result% + }"
}

# Format a key name nicely
format_key() {
  local key="$1"
  case "$key" in
    mouse:272) echo "LMB" ;;
    mouse:273) echo "RMB" ;;
    grave)     echo "\`" ;;
    comma)     echo "<" ;;
    period)    echo ">" ;;
    Return)    echo "Enter" ;;
    *)         echo "$key" ;;
  esac
}

{
  # Regular binds
  hyprctl binds -j | jq -r '.[] | "\(.modmask)\t\(.key)\t\(.dispatcher)\t\(.arg)\t\(.mouse)"' |
  while IFS=$'\t' read -r mask key dispatcher arg mouse; do
    mods=$(decode_mods "$mask")
    fkey=$(format_key "$key")

    if [ -n "$mods" ]; then
      combo="$mods + $fkey"
    else
      combo="$fkey"
    fi

    desc=$(describe "$dispatcher" "$arg")
    printf "%-30s  %s\n" "$combo" "$desc"
  done
} | sort -t'+' -k1,1 | fuzzel --dmenu --prompt "Keybinds > " --width 50 --lines 35
