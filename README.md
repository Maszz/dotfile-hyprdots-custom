# Hyprland Custom Config

Personal customization layer for [illogical-impulse / end-4 hyprdots](https://github.com/end-4/dots-hyprland).

This directory sits at `~/.config/hypr/custom/` and is sourced by the base `hyprland.conf`. It overrides and extends the defaults without touching the upstream `hyprland/` directory.

## Setup

Clone this repo directly into place:

```bash
git clone https://github.com/Maszz/dotfile-hyprdots-custom.git ~/.config/hypr/custom
```

Then make scripts executable:

```bash
chmod +x ~/.config/hypr/custom/scripts/*.sh
```

## What's in here

| File | Purpose |
|------|---------|
| `general.conf` | Monitor layout, workspace bindings, keyboard layout |
| `keybinds.conf` | Extra and overridden keybindings |
| `rules.conf` | Window rules (workspace assignments, etc.) |
| `execs.conf` | Autostart apps |
| `env.conf` | Extra environment variables |
| `scripts/move_window_to_monitor.sh` | Cross-monitor window movement script |
| `scripts/__restore_video_wallpaper.sh` | Restore video wallpaper on startup |

## Monitor Setup

```
x=0              x=1440
┌────────────┐   ┌──────────────┐
│   DP-5     │   │    DP-4      │
│ 27" 2560x  │   │ 24" 1920x    │
│ 1440 (rot) │   │ 1080         │
│ portrait   │   │ landscape    │
│            │   │              │
│ WS 11–20   │   │ WS 1–10      │
└────────────┘   └──────────────┘
```

- **DP-5** — 27" portrait (rotated 90°), workspaces 11–20
- **DP-4** — 24" landscape, workspaces 1–10

## Keybindings

### Window Movement (Cross-Monitor Aware)

| Keybind | Action |
|---------|--------|
| `Super+Shift+Left` | Move window left (swap within workspace, or cross to left monitor) |
| `Super+Shift+Right` | Move window right (swap within workspace, or cross to right monitor) |
| `Super+Shift+Up` | Move window up (swap within workspace, or cross to upper monitor) |
| `Super+Shift+Down` | Move window down (swap within workspace, or cross to lower monitor) |

The script is position-aware:
- If there's a window in that direction on the same workspace → **swap** with it
- If the window is at the edge → **move across** to the adjacent monitor's active workspace, landing on the side closest to where it came from

### Other Bindings

| Keybind | Action |
|---------|--------|
| `Ctrl+Super+Z` | Switch to workspace group -10 |
| `Ctrl+Super+X` | Switch to workspace group +10 |
| `Super+;` | Shrink window width |
| `Super+'` | Expand window width |

## Window Rules

| App | Workspace |
|-----|-----------|
| Discord | 19 (DP-5, silent) |
| Thunderbird | 20 (DP-5, silent) |
