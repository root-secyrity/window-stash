import QtQuick
import Ryoku.PluginKit.Singletons

// The bar glyph: state mark plus the label, permanent (unlike the Ubisoft one,
// this must be reachable while nothing is hidden yet). Reading only -- its one
// click action opens the plugin panel.
Item {
    id: root

    property var pluginApi
    property var screen
    property bool active: false
    property string density: "glyph"
    property real s: 1
    property real widthBudget: 0

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property int stashed: service ? service.stashedCount : 0
    readonly property bool showLabel: service && service.settings
        ? (service.settings.showLabel ?? true) : true

    implicitWidth: row.implicitWidth
    implicitHeight: Math.max(row.implicitHeight, 18 * root.s)

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6 * root.s

        // Filled and accented while something is parked away, hollow when not.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.stashed > 0 ? "\u25CF" : "\u25CB"
            color: root.stashed > 0 ? Theme.accent : Theme.dim
            font.family: Theme.mono
            font.pixelSize: 12 * root.s
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showLabel
            text: root.stashed > 0 ? "Windows " + root.stashed : "Windows"
            color: root.stashed > 0 ? Theme.bright : Theme.dim
            font.family: Theme.font
            font.pixelSize: 13 * root.s
            elide: Text.ElideRight
            width: root.widthBudget > 0 ? Math.min(implicitWidth, root.widthBudget) : implicitWidth
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: if (root.pluginApi) root.pluginApi.togglePanel()
    }
}
