pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property string desktop: (Quickshell.env("XDG_CURRENT_DESKTOP") || "").split(":")[0].toLowerCase()

    readonly property bool supportsMinimize: true

}
