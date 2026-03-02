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
current_monitor_id=$(echo "$window_json" | jq -r '.monitor')

if [[ "$window_addr" == "null" || -z "$window_addr" ]]; then
    echo "No focused window"
    exit 1
fi

# Try swapwindow first - let Hyprland decide if there's an adjacent window
hyprctl dispatch swapwindow "$direction"
sleep 0.05

# Check if the window actually moved
window_json_after=$(hyprctl activewindow -j)
window_x_after=$(echo "$window_json_after" | jq -r '.at[0]')
window_y_after=$(echo "$window_json_after" | jq -r '.at[1]')

# If position changed, swap happened within workspace - done
if [[ "$window_x" != "$window_x_after" || "$window_y" != "$window_y_after" ]]; then
    exit 0
fi

# Position didn't change - window is at the edge, find adjacent monitor.
#
# Detection is direction-aware with axis-overlap:
#   l/r → target must overlap on the Y axis (share a horizontal band)
#   u/d → target must overlap on the X axis (share a vertical band)
#
# This prevents e.g. pressing "d" from a tall left monitor from jumping
# to a shorter right monitor that starts lower on the Y axis.

monitors_json=$(hyprctl monitors -j)

# Compute current monitor's actual bounds (swap w/h for 90°/270° rotation)
cm=$(echo "$monitors_json" | jq ".[] | select(.id == $current_monitor_id)")
cm_x=$(echo "$cm" | jq -r '.x')
cm_y=$(echo "$cm" | jq -r '.y')
cm_w=$(echo "$cm" | jq -r '.width')
cm_h=$(echo "$cm" | jq -r '.height')
cm_t=$(echo "$cm" | jq -r '.transform')

if [[ "$cm_t" == "1" || "$cm_t" == "3" ]]; then
    tmp=$cm_w; cm_w=$cm_h; cm_h=$tmp
fi

cm_x2=$((cm_x + cm_w))   # right edge
cm_y2=$((cm_y + cm_h))   # bottom edge

# For each candidate monitor, actual width/height accounts for rotation.
# jq expression: (if transform 1|3 then swap w/h else keep end)
dim='(if (.transform == 1 or .transform == 3) then {w: .height, h: .width} else {w: .width, h: .height} end)'

case "$direction" in
    r)
        target_monitor=$(echo "$monitors_json" | jq -r \
            --argjson cur "$current_monitor_id" \
            --argjson cx2 "$cm_x2" \
            --argjson cy  "$cm_y"  \
            --argjson cy2 "$cm_y2" \
            "[.[] | . as \$m | $dim as \$d | select(
                \$m.id != \$cur and
                \$m.x >= \$cx2 and
                \$m.y < \$cy2 and (\$m.y + \$d.h) > \$cy
            )] | sort_by(.x) | first | .name")
        ;;
    l)
        target_monitor=$(echo "$monitors_json" | jq -r \
            --argjson cur "$current_monitor_id" \
            --argjson cx  "$cm_x"  \
            --argjson cy  "$cm_y"  \
            --argjson cy2 "$cm_y2" \
            "[.[] | . as \$m | $dim as \$d | select(
                \$m.id != \$cur and
                (\$m.x + \$d.w) <= \$cx and
                \$m.y < \$cy2 and (\$m.y + \$d.h) > \$cy
            )] | sort_by(.x) | last | .name")
        ;;
    d)
        target_monitor=$(echo "$monitors_json" | jq -r \
            --argjson cur "$current_monitor_id" \
            --argjson cx  "$cm_x"  \
            --argjson cx2 "$cm_x2" \
            --argjson cy2 "$cm_y2" \
            "[.[] | . as \$m | $dim as \$d | select(
                \$m.id != \$cur and
                \$m.y >= \$cy2 and
                \$m.x < \$cx2 and (\$m.x + \$d.w) > \$cx
            )] | sort_by(.y) | first | .name")
        ;;
    u)
        target_monitor=$(echo "$monitors_json" | jq -r \
            --argjson cur "$current_monitor_id" \
            --argjson cx  "$cm_x"  \
            --argjson cx2 "$cm_x2" \
            --argjson cy  "$cm_y"  \
            "[.[] | . as \$m | $dim as \$d | select(
                \$m.id != \$cur and
                (\$m.y + \$d.h) <= \$cy and
                \$m.x < \$cx2 and (\$m.x + \$d.w) > \$cx
            )] | sort_by(.y) | last | .name")
        ;;
esac

if [[ "$target_monitor" == "null" || -z "$target_monitor" ]]; then
    exit 0
fi

# Move window to active workspace on target monitor (with focus)
target_workspace=$(echo "$monitors_json" | jq -r ".[] | select(.name == \"$target_monitor\") | .activeWorkspace.id")
hyprctl dispatch movetoworkspace "$target_workspace"

# Position window on the edge closest to where it came from.
# Swap exactly (number of other windows on target) times to reach the correct edge.
moved_addr=$(hyprctl activewindow -j | jq -r '.address')
other_count=$(hyprctl clients -j | jq "[.[] | select(.workspace.id == $target_workspace and .address != \"$moved_addr\")] | length")

case "$direction" in
    r) for i in $(seq 1 "$other_count"); do hyprctl dispatch swapwindow l; done ;;
    l) for i in $(seq 1 "$other_count"); do hyprctl dispatch swapwindow r; done ;;
    d) for i in $(seq 1 "$other_count"); do hyprctl dispatch swapwindow u; done ;;
    u) for i in $(seq 1 "$other_count"); do hyprctl dispatch swapwindow d; done ;;
esac
