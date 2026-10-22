#!/usr/bin/env bash
# stash.sh <address> — hide one window by its address.
#
# It goes to the special workspace "special:stash-<its own workspace id>": the
# home workspace travels inside the name, so no state file is needed and the
# mapping survives a shell restart. Addressed by address, never by focus, which
# is exactly what makes Ryoku's own Super+H unreliable to reverse.
set -uo pipefail

# Hiding needs a compositor with special workspaces. Ask the seam for the
# capability, never for a compositor name, and stand down where it is absent -
# the same gate Ryoku's own ryoku-workspace helper uses.
if ! ryoku wm caps 2>/dev/null | grep -q '"specialWorkspace"'; then
    echo "no-scratchpad"
    exit 0
fi
if [[ $(ryoku wm status 2>/dev/null | sed -n 's/^Workspace model: //p' | tr -d '[:space:]') != fixed ]]; then
    echo "no-scratchpad"
    exit 0
fi

addr="${1:?window address required}"

# The id reaches a hyprctl dispatch string, so accept only the shape the seam
# reports (0x + hex). Nothing else is ever interpolated.
[[ $addr =~ ^0x[0-9a-fA-F]+$ ]] || { echo "bad-window-id"; exit 1; }

active_ws() { hyprctl activeworkspace -j 2>/dev/null | jq -r '.id' 2>/dev/null || echo 0; }

home=$(hyprctl clients -j 2>/dev/null \
    | jq -r --arg a "$addr" '.[]|select(.address==$a)|.workspace.id' 2>/dev/null || echo 0)
if [[ -z $home || $home -lt 1 ]]; then
    echo "not-on-normal-workspace"
    exit 1
fi

back=$(active_ws)
target="special:stash-$home"

hyprctl dispatch "hl.dsp.window.move({ workspace = \"$target\", window = \"address:$addr\", silent = true })" >/dev/null

# Verify the move landed before reporting it.
ws_now=$(hyprctl clients -j 2>/dev/null \
    | jq -r --arg a "$addr" '.[]|select(.address==$a)|.workspace.name' 2>/dev/null || echo "")
if [[ $ws_now != "$target" ]]; then
    echo "stash-failed"
    exit 1
fi

# A silent move still drags keyboard focus into the special workspace and shows
# it. Undo both, or the window stays on screen and typing goes somewhere
# invisible -- the sequence Ryoku's own ryoku-workspace helper settled on.
# Any monitor showing it counts, not only the focused one.
shown_anywhere() {
    hyprctl monitors -j 2>/dev/null \
        | jq -e --arg t "$target" 'any(.[]; .specialWorkspace.name == $t)' >/dev/null 2>&1
}

if shown_anywhere; then
    hyprctl dispatch "hl.dsp.workspace.toggle_special(\"stash-$home\")" >/dev/null
fi

if [[ $back -ge 1 ]]; then
    vis=$(hyprctl clients -j 2>/dev/null \
        | jq -r --argjson ws "$back" \
            '[.[]|select(.workspace.id==$ws)]|sort_by(.focusHistoryID)|.[0].address // empty' 2>/dev/null || true)
    [[ -n $vis ]] && hyprctl dispatch "hl.dsp.focus({ window = \"address:$vis\" })" >/dev/null
fi

echo "stashed"
