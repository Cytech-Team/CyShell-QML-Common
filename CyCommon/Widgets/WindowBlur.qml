import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.CyCommon.Common

Item {
    id: root

    visible: false

    required property var targetWindow
    property bool blurEnabled: Style.connectedSurfaceBlurEnabled
    property real blurX: 0
    property real blurY: 0
    property real blurWidth: 0
    property real blurHeight: 0
    property real blurRadius: 0
    property real blurBottomRadius: blurRadius
    property bool clipEnabled: false
    property real clipX: blurX
    property real clipY: blurY
    property real clipWidth: blurWidth
    property real clipHeight: blurHeight

    // CyShell LabWC does not advertise ext-background-effect-v1.
    readonly property bool _backgroundEffectsAllowed: Compositor.desktop !== "labwc"
    readonly property bool _active: blurEnabled && Style.blurLayersActive && _backgroundEffectsAllowed && !!targetWindow
    readonly property bool _windowVisible: targetWindow?.visible ?? false
    readonly property real _windowWidth: targetWindow?.width ?? 0
    readonly property real _windowHeight: targetWindow?.height ?? 0

    Region {
        id: blurRegion
        x: root.blurX
        y: root.blurY
        width: root.blurWidth
        height: root.blurHeight
        radius: root.blurRadius

        Region {
            readonly property bool needed: root.blurBottomRadius < root.blurRadius
            x: root.blurX
            y: root.blurY + root.blurRadius
            width: needed ? root.blurWidth : 0
            height: needed ? Math.max(0, root.blurHeight - root.blurRadius) : 0
            radius: root.blurBottomRadius
        }

        Region {
            intersection: Intersection.Intersect
            x: root.clipEnabled ? root.clipX : root.blurX
            y: root.clipEnabled ? root.clipY : root.blurY
            width: root.clipEnabled ? root.clipWidth : root.blurWidth
            height: root.clipEnabled ? root.clipHeight : root.blurHeight
        }
    }

    function _effect() {
        if (!_backgroundEffectsAllowed || !targetWindow)
            return null;
        return targetWindow.BackgroundEffect ?? null;
    }

    function _apply() {
        const effect = _effect();
        if (!effect)
            return;
        effect.blurRegion = _active ? blurRegion : null;
    }

    function _clear() {
        const effect = _effect();
        if (!effect)
            return;
        effect.blurRegion = null;
    }

    // Republish after wl_surface remaps and geometry changes.
    function kick() {
        const effect = _effect();
        if (!effect)
            return;
        effect.blurRegion = null;
        effect.blurRegion = _active ? blurRegion : null;
    }

    function _scheduleSettleKick() {
        if (_active && _windowVisible)
            settleTimer.restart();
    }

    function _scheduleLifecycleKick() {
        if (_active)
            lifecycleTimer.restart();
    }

    function _runLifecycleKick() {
        if (!_active)
            return;
        if (_windowVisible) {
            kick();
            return;
        }
        _apply();
    }

    onBlurXChanged: _scheduleSettleKick()
    onBlurYChanged: _scheduleSettleKick()
    onBlurWidthChanged: _scheduleSettleKick()
    onBlurHeightChanged: _scheduleSettleKick()
    onBlurRadiusChanged: _scheduleSettleKick()
    onBlurBottomRadiusChanged: _scheduleSettleKick()
    onClipEnabledChanged: _scheduleSettleKick()
    onClipXChanged: _scheduleSettleKick()
    onClipYChanged: _scheduleSettleKick()
    onClipWidthChanged: _scheduleSettleKick()
    onClipHeightChanged: _scheduleSettleKick()

    Timer {
        id: settleTimer
        interval: 16
        onTriggered: {
            if (!root._active || !root._windowVisible)
                return;
            root.kick();
            settleRepeatTimer.restart();
        }
    }

    Timer {
        id: settleRepeatTimer
        interval: 96
        onTriggered: {
            if (!root._active || !root._windowVisible)
                return;
            root.kick();
        }
    }

    Timer {
        id: lifecycleTimer
        interval: 0
        onTriggered: root._runLifecycleKick()
    }

    on_ActiveChanged: {
        if (!_active) {
            _clear();
            return;
        }
        _scheduleLifecycleKick();
    }

    onTargetWindowChanged: {
        lifecycleTimer.stop();
        _apply();
    }

    Connections {
        target: root.targetWindow ?? null
        ignoreUnknownSignals: true
        function onResourcesLost() {
            root._clear();
            root._scheduleLifecycleKick();
        }
        function onWindowConnected() {
            root._scheduleLifecycleKick();
        }
    }

    on_WindowVisibleChanged: {
        if (!_windowVisible) {
            _clear();
            return;
        }
        _scheduleLifecycleKick();
    }
    on_WindowWidthChanged: _scheduleSettleKick()
    on_WindowHeightChanged: _scheduleSettleKick()

    Component.onCompleted: _scheduleLifecycleKick()
    Component.onDestruction: {
        lifecycleTimer.stop();
        _clear();
    }
}
