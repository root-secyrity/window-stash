pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Logic only, no UI. Polls bin/windows.sh for the open windows and runs
// bin/stash.sh or bin/restore.sh when the panel asks. Every action addresses a
// window by its address, never by focus.
Item {
    id: svc

    property var pluginApi
    readonly property var settings: pluginApi ? pluginApi.pluginSettings : null
    readonly property string pluginDir: pluginApi ? String(pluginApi.pluginDir) : ""

    property var windows: []
    property bool loaded: false
    property bool loadFailed: false // last windows.sh read did not parse
    property bool frozen: false     // panel open: no background poll
    property string pending: ""     // address being acted on, "" when idle
    property string message: ""

    readonly property int windowCount: svc.windows.length
    readonly property int stashedCount: {
        let n = 0;
        for (let i = 0; i < svc.windows.length; i++) {
            if (svc.windows[i].stashed === true)
                n++;
        }
        return n;
    }

    readonly property int pollSeconds: {
        const v = Number(svc.settings ? svc.settings.poll : 3);
        return (isFinite(v) && v >= 2 && v <= 30) ? Math.round(v) : 3;
    }

    function refresh() {
        if (!svc.pluginDir || listProc.running)
            return;
        listProc.command = ["bash", svc.pluginDir + "/bin/windows.sh"];
        listProc.running = true;
    }

    // The panel freezes the list while it is open: a poll landing between the
    // pointer going down and coming up rebuilds every row, so the click can act
    // on a different window than the one under the pointer. Opening refreshes
    // once, and every action refreshes when it exits.
    function setPanelActive(on) {
        svc.frozen = on === true;
        if (svc.frozen)
            svc.refresh();
    }

    // action: "stash" hides, "restore" brings it back, "close" closes it.
    function act(addr, action) {
        if (!svc.pluginDir || svc.pending !== "" || !addr)
            return;
        svc.pending = addr;
        svc.message = "";
        const script = action === "restore" ? "/bin/restore.sh"
                     : action === "close" ? "/bin/close.sh"
                     : "/bin/stash.sh";
        actionProc.command = ["bash", svc.pluginDir + script, addr];
        actionProc.running = true;
    }

    onPluginDirChanged: refresh()

    Component.onCompleted: refresh()

    Timer {
        interval: svc.pollSeconds * 1000
        running: true
        repeat: true
        onTriggered: {
            if (svc.pending === "" && !svc.frozen)
                svc.refresh();
        }
    }

    Process {
        id: listProc
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = (text || "").trim();
                let rows = null;
                try {
                    const parsed = JSON.parse(raw);
                    if (Array.isArray(parsed))
                        rows = parsed;
                } catch (e) {
                    rows = null;
                }
                // A failed or truncated read keeps the last good list: replacing
                // it with [] would flash "No windows to act on." mid-session.
                if (rows !== null) {
                    svc.windows = rows;
                    svc.loadFailed = false;
                } else {
                    svc.loadFailed = true;
                }
                svc.loaded = true;
            }
        }
    }

    Process {
        id: actionProc
        stdout: StdioCollector {
            onStreamFinished: {
                const out = (text || "").trim();
                if (out === "stashed") {
                    svc.message = "Window hidden.";
                } else if (out === "restored") {
                    svc.message = "Window shown on its own workspace.";
                } else if (out === "closed") {
                    svc.message = "Window closed.";
                } else if (out === "not-stashed") {
                    svc.message = "That window is not hidden.";
                } else if (out === "not-on-normal-workspace") {
                    svc.message = "That window cannot be hidden from here.";
                } else if (out === "close-failed") {
                    svc.message = "The window did not close.";
                } else if (out === "stash-failed") {
                    svc.message = "The window could not be hidden.";
                } else if (out === "restore-failed") {
                    svc.message = "The window could not be shown.";
                } else {
                    svc.message = out;
                }
            }
        }
        onExited: function(exitCode) {
            if (exitCode !== 0 && svc.message === "")
                svc.message = "The action did not complete.";
            svc.pending = "";
            svc.refresh();
        }
    }
}
