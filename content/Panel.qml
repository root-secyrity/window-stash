pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.PluginKit.Singletons

// The bar panel: every open window, one row each, with the single action that
// applies to it. Mirrors the ubisoft-connect panel's shape: title, state line,
// the list, a caption. The host sizes the card to implicitHeight.
Item {
    id: root

    property var pluginApi
    property string density: "full"
    property real s: 1
    property real widthBudget: 360
    property bool active: false

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property var windows: service ? service.windows : []
    readonly property int total: service ? service.windowCount : 0
    readonly property int stashed: service ? service.stashedCount : 0
    readonly property string pending: service ? service.pending : ""
    readonly property string message: service ? service.message : ""
    readonly property bool canHide: service ? service.canHide : false

    implicitWidth: root.widthBudget
    implicitHeight: col.implicitHeight + 24 * root.s

    // Freeze the list while the panel is open: a background poll that rebuilds
    // the rows under the pointer is how a click lands on the wrong window.
    onActiveChanged: if (root.service) root.service.setPanelActive(root.active)

    // A panel can be taken down without flipping active back; unfreeze here so
    // the bar's state mark keeps updating after it closes.
    Component.onDestruction: if (root.service) root.service.setPanelActive(false)

    Column {
        id: col
        x: 12 * root.s
        y: 12 * root.s
        width: root.width - 24 * root.s
        spacing: 10 * root.s

        Text {
            text: "Windows"
            color: Theme.bright
            font.family: Theme.display
            font.pixelSize: 16 * root.s
        }

        Text {
            text: root.total + (root.total === 1 ? " window" : " windows")
                + (root.stashed > 0 ? "  \u00b7  " + root.stashed + " hidden" : "")
            color: root.stashed > 0 ? Theme.accent : Theme.dim
            font.family: Theme.mono
            font.pixelSize: 11 * root.s
        }

        Text {
            width: parent.width
            visible: root.total === 0
            text: (service && service.loadFailed)
                ? "Could not read the window list."
                : "No windows to act on."
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 11 * root.s
        }

        Item {
            width: parent.width
            height: Math.min(rows.implicitHeight, 260 * root.s)
            visible: root.total > 0

            Flickable {
                id: flick
                anchors.fill: parent
                contentHeight: rows.implicitHeight
                clip: true
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: rows
                    width: flick.width
                    spacing: 4 * root.s

                    Repeater {
                        model: root.windows

                        delegate: Item {
                            id: rowItem
                            required property var modelData

                            readonly property bool isStashed: modelData.stashed === true
                            readonly property string label: (modelData.cls || "") !== ""
                                ? modelData.cls + "  \u00b7  " + modelData.title
                                : modelData.title

                            width: rows.width
                            height: 30 * root.s

                            Text {
                                id: dot
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 12 * root.s
                                text: rowItem.isStashed ? "\u25CB" : "\u25CF"
                                color: rowItem.isStashed ? Theme.dim : Theme.accent
                                font.family: Theme.mono
                                font.pixelSize: 10 * root.s
                            }

                            Text {
                                anchors.left: dot.right
                                anchors.leftMargin: 6 * root.s
                                anchors.right: actionButton.left
                                anchors.rightMargin: 8 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                text: rowItem.label
                                color: rowItem.isStashed ? Theme.dim : Theme.bright
                                font.family: Theme.font
                                font.pixelSize: 11 * root.s
                                elide: Text.ElideRight
                            }

                            // Clicking the row's name focuses that window through
                            // the seam (window.focus), so a stashed or buried
                            // window comes back without touching HIDE.
                            MouseArea {
                                anchors.left: dot.right
                                anchors.right: root.canHide ? actionButton.left : closeButton.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.rightMargin: 8 * root.s
                                enabled: root.pending === ""
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: if (root.service)
                                    root.service.act(rowItem.modelData.addr, "focus")
                            }

                            // CLOSE sits right-most, the stash action beside it.
                            Rectangle {
                                id: closeButton
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: closeLabel.implicitWidth + 20 * root.s
                                height: 22 * root.s
                                radius: Theme.radius
                                color: closeArea.pressed ? Theme.accent : "transparent"
                                border.width: 1
                                border.color: closeArea.containsMouse ? Theme.accent : Theme.dim

                                Text {
                                    id: closeLabel
                                    anchors.centerIn: parent
                                    text: "CLOSE"
                                    color: (closeArea.containsMouse || closeArea.pressed)
                                        ? Theme.accent : Theme.bright
                                    font.family: Theme.mono
                                    font.pixelSize: 10 * root.s
                                }

                                MouseArea {
                                    id: closeArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: root.pending === ""
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: if (root.service)
                                        root.service.act(rowItem.modelData.addr, "close")
                                }
                            }

                            Rectangle {
                                id: actionButton
                                anchors.right: closeButton.left
                                anchors.rightMargin: 6 * root.s
                                visible: root.canHide
                                anchors.verticalCenter: parent.verticalCenter
                                width: btnLabel.implicitWidth + 20 * root.s
                                height: 22 * root.s
                                radius: Theme.radius
                                color: btnArea.pressed ? Theme.accent : "transparent"
                                border.width: 1
                                border.color: btnArea.containsMouse ? Theme.accent : Theme.dim

                                Text {
                                    id: btnLabel
                                    anchors.centerIn: parent
                                    text: rowItem.isStashed ? "SHOW" : "HIDE"
                                    color: (btnArea.containsMouse || btnArea.pressed)
                                        ? Theme.accent : Theme.bright
                                    font.family: Theme.mono
                                    font.pixelSize: 10 * root.s
                                }

                                MouseArea {
                                    id: btnArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: root.pending === ""
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: if (root.service)
                                        root.service.act(rowItem.modelData.addr,
                                                         rowItem.isStashed ? "restore" : "stash")
                                }
                            }
                        }
                    }
                }
            }
        }

        Text {
            width: parent.width
            visible: root.message !== ""
            text: root.message
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 11 * root.s
            wrapMode: Text.WordWrap
        }

        Text {
            width: parent.width
            text: root.canHide
                ? "HIDE parks a window out of sight. SHOW returns it to its own workspace. CLOSE ends it."
                : "This window manager has no scratchpad, so HIDE is left out. Click a row to focus it; CLOSE ends it."
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 10 * root.s
            wrapMode: Text.WordWrap
        }
    }
}
