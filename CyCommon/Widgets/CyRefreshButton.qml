import QtQuick
import qs.CyCommon.Common

CyActionButton {
    id: root

    property bool busy: false

    iconName: busy ? "" : "refresh"
    Accessible.name: tooltipText || I18n.tr("Refresh")
    enabled: !busy

    CySpinner {
        anchors.centerIn: parent
        size: root.iconSize
        strokeWidth: Style.spinnerStrokeWidth
        color: root.iconColor
        running: root.busy && root.visible
        visible: root.busy
    }
}
