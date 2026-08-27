# Workspace

A bar-only workspace switcher for Niri, with one clickable button per workspace.

## Plugin

| Field | Value |
| --- | --- |
| ID | `sayeed/workspace` |
| Entries | Bar widget: `workspace-bar` |

## Requirements

The `niri` command must be installed and available on `PATH`.

## Usage

Install `niri` and enable the plugin. Add the `Workspace` bar widget from
Noctalia's bar configuration. Click a workspace button to focus it.

## Notes

The widget reads Niri's workspace state through `niri msg` and listens to its
event stream. It is intended for Niri and has no filesystem or network access.
