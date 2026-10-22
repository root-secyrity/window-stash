#!/usr/bin/env bash
# windows.sh — the list the panel renders.
# Prints a JSON array; one object per window the widget can act on:
#   {addr, cls, title, ws, wsname, stashed}
# Excluded on purpose: unmapped windows, fullscreen windows (they misbehave with
# special workspaces) and other special workspaces (Ryoku's own overlays).
set -uo pipefail

STASH_PREFIX="special:stash-"

hyprctl clients -j | jq -c --arg p "$STASH_PREFIX" '
  [ .[]
    | select(.mapped == true and .fullscreen == 0)
    | { addr: .address,
        cls: (.class // ""),
        title: (.title // ""),
        ws: (.workspace.id // 0),
        wsname: (.workspace.name // ""),
        stashed: ((.workspace.name // "") | startswith($p)) }
    | select(.stashed or ((.wsname | startswith("special:")) | not))
    | .title = (if .title == "" then .cls else .title end)
  ]
  | sort_by([ .stashed, .ws, (.title | ascii_downcase) ])
'
