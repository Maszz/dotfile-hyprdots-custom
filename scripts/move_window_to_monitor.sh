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
window_w=$(echo "$window_json" | jq -r '.size[0]')
window_h=$(echo "$window_json" | jq -r '.size[1]')
current_monitor_id=$(echo "$window_json" | jq -r '.monitor')
workspace_id=$(echo "$window_json" | jq -r '.workspace.id')

if [[ "$window_addr" == "null" || -z "$window_addr" ]]; then
    echo "No focused window"
    exit 1
fi

wx2=$((window_x + window_w))
wy2=$((window_y + window_h))

# Check if there's an adjacent window in the given direction within the same workspace.
# Uses axis-overlap so only geometrically adjacent windows count.
case "$direction" in
    l) adj_filter="(.at[0] + .size[0]) <= $window_x and .at[1] < $wy2 and (.at[1] + .size[1]) > $window_y" ;;
    r) adj_filter=".at[0] >= $wx2 and .at[1] < $wy2 and (.at[1] + .size[1]) > $window_y" ;;
    u) adj_filter="(.at[1] + .size[1]) <= $window_y and .at[0] < $wx2 and (.at[0] + .size[0]) > $window_x" ;;
    d) adj_filter=".at[1] >= $wy2 and .at[0] < $wx2 and (.at[0] + .size[0]) > $window_x" ;;
esac

adjacent=$(hyprctl clients -j | jq --argjson ws "$workspace_id" --arg addr "$window_addr" \
    "[.[] | select(.workspace.id == \$ws and .address != \$addr and ($adj_filter))] | length")

if [[ "$adjacent" -gt 0 ]]; then
    hyprctl dispatch swapwindow "$direction"
    exit 0
fi

# No adjacent window in this direction - find adjacent monitor and move there
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
