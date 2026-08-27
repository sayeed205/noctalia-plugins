# Workspace

A bar-only workspace switcher for Niri, Hyprland, and Sway, with one clickable
button per workspace.

## Plugin

| Field | Value |
| --- | --- |
| ID | `sayeed/workspace` |
| Entries | Bar widget: `workspace-bar` |

## Requirements

One supported compositor command should be available on `PATH`: `niri`,
`hyprctl`, or `swaymsg`. The plugin detects the available command at runtime.

## Usage

Enable the plugin and add the `Workspace` bar widget from Noctalia's bar
configuration. Click a workspace button to focus it.

## Notes

The widget auto-detects Niri, Hyprland, or Sway and polls the compositor's
native IPC once per second. Other compositors stay dormant until an adapter is
added. It has no filesystem or network access. The compositor commands are
optional because only the command for the active compositor is needed.
