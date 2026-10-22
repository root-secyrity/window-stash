#!/usr/bin/env bash
# restore.sh <address> — bring one stashed window back.
#
# The window's current workspace name carries its home: "special:stash-3" means
# it belongs on workspace 3. No state file, and it still works after a shell
# restart. Not silent: following the window hands keyboard focus back to it.
set -uo pipefail

# Same capability gate as stash.sh: no scratchpad, nothing to restore from.
if ! ryoku wm caps 2>/dev/null | grep -q '"specialWorkspace"'; then
    echo "no-scratchpad"
    exit 0
fi
if [[ $(ryoku wm status 2>/dev/null | sed -n 's/^Workspace model: //p' | tr -d '[:space:]') != fixed ]]; then
    echo "no-scratchpad"
    exit 0
fi

addr="${1:?window address required}"

# Same id guard as stash.sh: only the shape the seam reports.
[[ $addr =~ ^0x[0-9a-fA-F]+$ ]] || { echo "bad-window-id"; exit 1; }

wsname=$(hyprctl clients -j 2>/dev/null \
    | jq -r --arg a "$addr" '.[]|select(.address==$a)|.workspace.name' 2>/dev/null || echo "")

home="${wsname#special:stash-}"
if [[ $wsname != special:stash-* || ! $home =~ ^[0-9]+$ ]]; then
    echo "not-stashed"
    exit 1
fi

hyprctl dispatch "hl.dsp.window.move({ workspace = $home, window = \"address:$addr\" })" >/dev/null

# Verify the move landed before reporting it.
ws_now=$(hyprctl clients -j 2>/dev/null \
    | jq -r --arg a "$addr" '.[]|select(.address==$a)|.workspace.id' 2>/dev/null || echo "")
if [[ $ws_now != "$home" ]]; then
    echo "restore-failed"
    exit 1
fi

echo "restored"
