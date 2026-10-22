pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Logic only, no UI. The window list comes from the window-manager seam
// (`ryoku wm state`), so it is the same call on Hyprland and on niri; close and
// focus go through `ryoku wm act`, the neutral action contract. Hiding is gated
// on the `specialWorkspace` capability, as Ryoku's own ryoku-workspace does.
Item {
    id: svc

    property var pluginApi
    readonly property var settings: pluginApi ? pluginApi.pluginSettings : null
    readonly property string pluginDir: pluginApi ? String(pluginApi.pluginDir) : ""

    property var windows: []
    property bool loaded: false
    property bool loadFailed: false // last `ryoku wm state` read did not parse
    property bool frozen: false     // panel open: no background poll
    property bool canHide: false    // specialWorkspace + fixed workspace model
    property bool capsRead: false
    property string pending: ""     // window id being acted on, "" when idle
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
        if (!svc.pluginDir || stateProc.running)
            return;
        stateProc.command = ["ryoku", "wm", "state"];
        stateProc.running = true;
    }

    // Capabilities decide what the panel may offer. Read once at start and again
    // whenever the panel opens, so a compositor switch at login is picked up.
    function readCaps() {
        if (capsProc.running)
            return;
        capsProc.command = ["ryoku", "wm", "caps"];
        capsProc.running = true;
    }

    // The panel freezes the list while it is open: a poll landing between the
    // pointer going down and coming up rebuilds every row, so the click can act
    // on a different window than the one under the pointer. Opening refreshes
    // once, and every action refreshes when it exits.
    function setPanelActive(on) {
        svc.frozen = on === true;
        if (svc.frozen) {
            svc.readCaps();
            svc.refresh();
        }
    }

    // action: "close", "focus", "stash", "restore".
    function act(addr, action) {
        if (!svc.pluginDir || svc.pending !== "" || !addr)
            return;
        if ((action === "stash" || action === "restore") && !svc.canHide) {
            svc.message = "This window manager has no scratchpad.";
            return;
        }
        svc.pending = addr;
        svc.message = "";
        if (action === "close")
            actionProc.command = ["ryoku", "wm", "act", "window.close", addr];
        else if (action === "focus")
            actionProc.command = ["ryoku", "wm", "act", "window.focus", addr];
        else if (action === "restore")
            actionProc.command = ["bash", svc.pluginDir + "/bin/restore.sh", addr];
        else if (action === "stash")
            actionProc.command = ["bash", svc.pluginDir + "/bin/stash.sh", addr];
        else
            return;
        actionProc.running = true;
    }

    onPluginDirChanged: {
        readCaps();
        refresh();
    }

    Component.onCompleted: {
        readCaps();
        refresh();
    }

    Timer {
        interval: svc.pollSeconds * 1000
        running: true
        repeat: true
        onTriggered: {
            if (svc.pending === "" && !svc.frozen)
                svc.refresh();
        }
    }

    // `ryoku wm caps` -> { supports: [...], workspaceModel: "fixed" | "dynamic" }
    Process {
        id: capsProc
        stdout: StdioCollector {
            onStreamFinished: {
                let ok = false;
                try {
                    const c = JSON.parse((text || "").trim());
                    ok = Array.isArray(c.supports)
                        && c.supports.indexOf("specialWorkspace") >= 0
                        && c.workspaceModel === "fixed";
                } catch (e) {
                    ok = false;
                }
                svc.canHide = ok;
                svc.capsRead = true;
            }
        }
    }

    // `ryoku wm state` -> { windows: [{ id, appId, title, workspace, ... }] }
    Process {
        id: stateProc
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = (text || "").trim();
                let rows = null;
                try {
                    const parsed = JSON.parse(raw);
                    if (parsed && Array.isArray(parsed.windows)) {
                        rows = [];
                        for (let i = 0; i < parsed.windows.length; i++) {
                            const w = parsed.windows[i];
                            const ws = String(w.workspace === undefined ? "" : w.workspace);
                            const isSpecial = ws.indexOf("special:") === 0;
                            const stashed = ws.indexOf("special:stash-") === 0;
                            // Other special workspaces are Ryoku's own overlays.
                            if (isSpecial && !stashed)
                                continue;
                            rows.push({
                                addr: String(w.id || ""),
                                cls: String(w.appId || ""),
                                title: String(w.title || ""),
                                ws: ws,
                                stashed: stashed
                            });
                        }
                        rows.sort(function (a, b) {
                            if (a.stashed !== b.stashed)
                                return a.stashed ? 1 : -1;
                            if (a.ws !== b.ws)
                                return a.ws < b.ws ? -1 : 1;
                            return a.title.toLowerCase() < b.title.toLowerCase() ? -1 : 1;
                        });
                    }
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
                } else if (out === "not-stashed") {
                    svc.message = "That window is not hidden.";
                } else if (out === "not-on-normal-workspace") {
                    svc.message = "That window cannot be hidden from here.";
                } else if (out === "no-scratchpad") {
                    svc.message = "This window manager has no scratchpad.";
                } else if (out === "stash-failed") {
                    svc.message = "The window could not be hidden.";
                } else if (out === "restore-failed") {
                    svc.message = "The window could not be shown.";
                } else if (out === "bad-window-id") {
                    svc.message = "That window id is not valid.";
                } else if (out !== "") {
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
