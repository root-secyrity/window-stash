<p align="center">
  <h1 align="center"># Windows</h1>
  <p align="center">
    <img src="https://img.shields.io/badge/platform-Linux-blue" alt="Platform">
    <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
    <img src="https://img.shields.io/badge/QML-Qt6-orange" alt="QML">
  </p>
</p>

A Ryoku shell plugin (`window-stash`). It lists the open windows on the bar and
lets you park any of them out of sight with one click, bring it back to the
workspace it came from, or close it.

**Hyprland only.** The window list is read from `hyprctl`; on niri (the other
compositor Ryoku ships) there is no such command and the widget has nothing to
show.

![window-stash demo: the panel on the bar, HIDE, SHOW and CLOSE](assets/demo.gif)

## Why it exists

Hyprland 0.56 has **no `minimize` dispatcher** (`hl.dsp.window.*` has close, kill,
float, fullscreen, move, swap, pin … and no minimize). The working substitute is
the special workspace: move a window into one and it leaves the screen, move it
back and it returns.

Ryoku already ships that as a keybind, `Super+H` (`ryoku-workspace hide`), but it
acts on the **focused** window. A window parked in a special workspace cannot be
focused, so pressing `Super+H` again does not bring *it* back -- it parks whatever
is focused instead. Recovering a specific window means `Super+Alt+H`, focusing it,
`Super+H`, then hiding the scratchpad again.

This plugin removes the focus dependency: it addresses every window by its
`address`, so hide and show are symmetric and always act on the window you
clicked.

## How a window is parked

It goes to the special workspace named after its own workspace:
`special:stash-3` for a window that came from workspace 3. The home workspace
travels inside the name, so **no state file is needed** and the mapping survives a
shell restart -- unlike Ryoku's own helper, which restores to whatever workspace
is current.

## What it runs, reads and writes

| Item | Detail |
| --- | --- |
| Runs | `bin/windows.sh` (poll), `bin/stash.sh`, `bin/restore.sh`, `bin/close.sh` (on an explicit click) |
| External commands | `bash`, `hyprctl`, `jq` -- declared in `dependencies.commands` |
| Reads | `hyprctl clients -j`, `hyprctl monitors -j`, `hyprctl activeworkspace -j` |
| Writes | Nothing at all. No state file, no config, no cache. Settings go through `pluginApi.saveSetting` only |
| Network | None. `capabilities.network` is absent on purpose |
| Privileged | None. No `pkexec`, no `sudo` |
| Dispatchers used | `hl.dsp.window.move`, `hl.dsp.window.close`, `hl.dsp.workspace.toggle_special`, `hl.dsp.focus` |

### What the three buttons do

- **HIDE** parks the window in its own special workspace. It can be brought back
  with **SHOW**, which returns it to the workspace it came from.
- **CLOSE** ends the window, exactly like its own close button: a program with
  unsaved work will lose it. There is no confirmation step, on purpose -- the
  button is a direct action, not a dialog.

Every action is verified after the dispatch. `hyprctl` answers `ok` and exits 0
even for an address that no longer exists, so the scripts re-read the client list
and report a failure instead of a silent success.

### Scope of the list

Included: every mapped window. Excluded on purpose:

- **Fullscreen windows** (`fullscreen != 0`). They interact badly with special
  workspaces; hiding one can leave the screen in a broken state.
- **Other special workspaces** (Ryoku's own overlays such as the share bar), so
  the list stays about your normal windows.

## Where it sits on the bar

The bar order belongs to the rice, not to the plugin: `~/.config/ryoku/shell.json`
holds `qsbar.layout`, and applying a rice rewrites it. A rice that does not name
`window-stash` in its own layout therefore drops it to the front of the left
section. Put it back and keep it there with:

```
ryoku-shell bar move window-stash --section left --after memory
```

The clean fix is to include `window-stash` in the rice's layout (or to re-save
the rice after positioning it), so the next apply carries the position over.

## Settings

| key | type | default | description |
| --- | --- | --- | --- |
| `showLabel` | toggle | `true` | Show the `Windows` label beside the state mark |
| `poll` | int | `3` | Seconds between window-list refreshes (2-30) |

The list freezes while the panel is open, so a refresh can never rebuild the rows
between a click's press and release. It refreshes once when the panel opens and
once after each action.

## Build, check, install

```
ryoku plugin validate .
ryoku plugin add . --bar --yes
```

## Preview

`assets/preview-widget.png` is a real capture of the widget on the QS Bar: the
state mark and the `Windows` label sitting between the system readouts and the
music pill, cropped from a full-width bar screenshot and enlarged 3.2x.

## Reviews and updates

The plugin is community-made (`official` is false). Fixes ship as a new
`version` in `manifest.json`: Ryostore compares versions, so a change without a
version bump never reaches an installed copy.

## Author

root-sec <root-secyrity@users.noreply.github.com>: this plugin is community-made (`official`
is false).
