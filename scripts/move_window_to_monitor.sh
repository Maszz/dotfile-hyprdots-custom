#!/usr/bin/env bash
# Move focused window - swap within workspace if possible, else cross-monitor
# Usage: move_window_to_monitor.sh <l|r|u|d>

direction="$1"

if [[ -z "$direction" ]]; then
    echo "Usage: $0 <l|r|u|d>"
    exit 1
fi

window_json=$(hyprctl activewindow -j)
window_addr=$(echo "$window_json" | jq -r '.address')
window_x=$(echo "$window_json" | jq -r '.at[0]')
window_y=$(echo "$window_json" | jq -r '.at[1]')
current_workspace=$(echo "$window_json" | jq -r '.workspace.id')
current_monitor_id=$(echo "$window_json" | jq -r '.monitor')

if [[ "$window_addr" == "null" || -z "$window_addr" ]]; then
    echo "No focused window"
    exit 1
fi

clients_json=$(hyprctl clients -j)

# Check if there's a window in the target direction on the same workspace
case "$direction" in
    l) other_window=$(echo "$clients_json" | jq -r "[.[] | select(.workspace.id == $current_workspace and .address != \"$window_addr\" and .at[0] < $window_x)] | sort_by(.at[0]) | last | .address") ;;
    r) other_window=$(echo "$clients_json" | jq -r "[.[] | select(.workspace.id == $current_workspace and .address != \"$window_addr\" and .at[0] > $window_x)] | sort_by(.at[0]) | first | .address") ;;
    u) other_window=$(echo "$clients_json" | jq -r "[.[] | select(.workspace.id == $current_workspace and .address != \"$window_addr\" and .at[1] < $window_y)] | sort_by(.at[1]) | last | .address") ;;
    d) other_window=$(echo "$clients_json" | jq -r "[.[] | select(.workspace.id == $current_workspace and .address != \"$window_addr\" and .at[1] > $window_y)] | sort_by(.at[1]) | first | .address") ;;
esac

# If there's a window in that direction, swap with it
if [[ -n "$other_window" && "$other_window" != "null" ]]; then
    hyprctl dispatch swapwindow "$direction"
    exit 0
fi

# No window in that direction - move to adjacent monitor
monitors_json=$(hyprctl monitors -j)
current_mon_x=$(echo "$monitors_json" | jq -r ".[] | select(.id == $current_monitor_id) | .x")
current_mon_y=$(echo "$monitors_json" | jq -r ".[] | select(.id == $current_monitor_id) | .y")

case "$direction" in
    l) target_monitor=$(echo "$monitors_json" | jq -r "[.[] | select(.x < $current_mon_x)] | sort_by(.x) | last | .name") ;;
    r) target_monitor=$(echo "$monitors_json" | jq -r "[.[] | select(.x > $current_mon_x)] | sort_by(.x) | first | .name") ;;
    u) target_monitor=$(echo "$monitors_json" | jq -r "[.[] | select(.y < $current_mon_y)] | sort_by(.y) | last | .name") ;;
    d) target_monitor=$(echo "$monitors_json" | jq -r "[.[] | select(.y > $current_mon_y)] | sort_by(.y) | first | .name") ;;
esac

if [[ "$target_monitor" == "null" || -z "$target_monitor" ]]; then
    exit 0
fi

# Move window to active workspace on target monitor (with focus)
target_workspace=$(echo "$monitors_json" | jq -r ".[] | select(.name == \"$target_monitor\") | .activeWorkspace.id")
hyprctl dispatch movetoworkspace "$target_workspace"

# Position window on the edge closest to where it came from.
# The window lands at the end of the tiling layout after movetoworkspace,
# so swap exactly (number of other windows) times to reach the correct edge.
moved_addr=$(hyprctl activewindow -j | jq -r '.address')
other_count=$(hyprctl clients -j | jq "[.[] | select(.workspace.id == $target_workspace and .address != \"$moved_addr\")] | length")

case "$direction" in
    r) for i in $(seq 1 "$other_count"); do hyprctl dispatch swapwindow l; done ;;
    l) for i in $(seq 1 "$other_count"); do hyprctl dispatch swapwindow r; done ;;
    d) for i in $(seq 1 "$other_count"); do hyprctl dispatch swapwindow u; done ;;
    u) for i in $(seq 1 "$other_count"); do hyprctl dispatch swapwindow d; done ;;
esac
