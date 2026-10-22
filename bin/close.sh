#!/usr/bin/env bash
# close.sh <address> — close one window, the same as its own close button.
#
# The dispatch is verified: hyprctl answers "ok" and exits 0 even for an address
# that is not there, so a silent no-op must never be reported as success.
set -uo pipefail

addr="${1:?window address required}"

still_there() {
    hyprctl clients -j 2>/dev/null \
        | jq -e --arg a "$addr" 'any(.[]; .address == $a)' >/dev/null 2>&1
}

if ! still_there; then
    echo "close-failed"
    exit 1
fi

hyprctl dispatch "hl.dsp.window.close({ window = \"address:$addr\" })" >/dev/null

# A close is asynchronous: give the client up to a second to leave the list.
for _ in 1 2 3 4 5 6 7 8 9 10; do
    if ! still_there; then
        echo "closed"
        exit 0
    fi
    sleep 0.1
done

echo "close-failed"
exit 1
