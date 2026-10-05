import QtQuick
import qs.CyCommon.Widgets
import qs.CyCommon.Common

CyActionButton {
    radius: Style.buttonRadius(width, height, buttonSize, pressed, circular)
    shapeDuration: LockMetrics.effectsDuration
    shapeCurve: Style.expressiveCurves.expressiveEffects
    stateDuration: LockMetrics.effectsDuration
    stateCurve: Style.expressiveCurves.expressiveEffects
}
