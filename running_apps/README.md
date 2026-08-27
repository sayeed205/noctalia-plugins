# Running Apps

A compact Noctalia bar widget that shows the windows on the active Hyprland
workspace and lets you focus one with a click.

## Plugin

| Field | Value |
| --- | --- |
| ID | `sayeed205/running_apps` |
| Entries | Bar widget: `running-apps-bar` |

## Requirements

Hyprland 0.56 or newer is supported directly. Older Hyprland configurations
using the legacy dispatcher syntax are supported as a fallback.

## Usage

Enable the plugin and add the `Running Apps` bar widget to the bar
configuration. Each icon represents a window on the active workspace; left
click an icon to focus that window.

## Notes

The widget polls Hyprland every 100 ms and uses Noctalia's XDG app-icon
resolver. It only reads local compositor state and does not access the network.
