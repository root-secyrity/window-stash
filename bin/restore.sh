#!/usr/bin/env bash
# restore.sh <address> — bring one stashed window back.
#
# The window's current workspace name carries its home: "special:stash-3" means
# it belongs on workspace 3. No state file, and it still works after a shell
# restart. Not silent: following the window hands keyboard focus back to it.
set -uo pipefail

addr="${1:?window address required}"

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
