pragma ComponentBehavior: Bound

import QtQuick
import qs.CyCommon.Widgets
import qs.CyCommon.Common

CyActionButton {
    id: customButtonKeyboard
    circular: false
    buttonSize: Style.iconButtonSize
    focusPolicy: Qt.TabFocus
    Accessible.name: text
    property bool isShift: false
    color: Style.chipSurface

    property bool isIcon: text === "keyboard_hide" || text === "Backspace" || text === "Enter"

    CyIcon {
        anchors.centerIn: parent
        name: {
            if (parent.text === "keyboard_hide")
                return "keyboard_hide";
            if (parent.text === "Backspace")
                return "backspace";
            if (parent.text === "Enter")
                return "keyboard_return";
            return "";
        }
        size: 20
        color: Style.surfaceText
        visible: parent.isIcon
    }

    StyledText {
        id: contentItem
        anchors.centerIn: parent
        text: parent.text
        color: Style.surfaceText
        font.pixelSize: Style.fontSizeXLarge
        font.weight: Style.fontWeight
        visible: !parent.isIcon
    }
}
