import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.CyCommon.Common
import qs.CyCommon.Widgets

ShellRoot {
    id: root

    property QtObject theme: QtObject {
        property bool connectedSurfaceBlurEnabled: true
        property bool blurLayersActive: true
    }

    FloatingWindow {
        id: window
        visible: false
    }

    WindowBlur {
        id: blur
        targetWindow: window
        blurX: 10
        blurY: 20
        blurWidth: 200
        blurHeight: 100
        blurRadius: 16
        blurBottomRadius: 4
        clipEnabled: true
        clipX: 30
        clipY: 40
        clipWidth: 150
        clipHeight: 60
    }

    function equal(actual, expected, label) {
        if (actual !== expected)
            throw new Error(label + ": " + actual + " != " + expected);
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false;
        Style.theme = theme;
        Qt.callLater(run);
    }

    function run() {
        try {
            const allowed = Compositor.desktop !== "labwc";
            equal(blur.blurEnabled, true, "host blur preference");
            equal(blur._active, allowed, "LabWC guard");
            blur._apply();
            if (allowed) {
                const region = window.BackgroundEffect.blurRegion;
                equal(!!region, true, "published region");
                equal(region.x, 10, "region x");
                equal(region.y, 20, "region y");
                equal(region.width, 200, "region width");
                equal(region.height, 100, "region height");
                equal(region.radius, 16, "region radius");
                equal(region.regions[0].radius, 4, "bottom radius");
                const clip = region.regions[1];
                equal(clip.intersection, Intersection.Intersect, "clip intersection");
                equal(clip.x, 30, "clip x");
                equal(clip.width, 150, "clip width");
                blur._clear();
                equal(window.BackgroundEffect.blurRegion, null, "cleared region");
                blur.kick();
                equal(window.BackgroundEffect.blurRegion, region, "republished region");
                theme.blurLayersActive = false;
                equal(window.BackgroundEffect.blurRegion, null, "theme disables effect");
                theme.blurLayersActive = true;
                blur._runLifecycleKick();
                equal(window.BackgroundEffect.blurRegion, region, "theme restores effect");
                theme.connectedSurfaceBlurEnabled = false;
                equal(blur.blurEnabled, false, "connected surface preference");
                equal(window.BackgroundEffect.blurRegion, null, "preference clears effect");
            } else {
                equal(blur._effect(), null, "LabWC skips effect attachment");
                blur.kick();
                blur._runLifecycleKick();
                equal(blur._active, false, "LabWC stays inactive");
            }
            blur.targetWindow = null;
            blur._apply();
            blur._clear();
            blur.kick();
            blur._runLifecycleKick();
            equal(blur._active, false, "null target is inactive");
            console.log("PASS window blur geometry, enablement and compositor guard");
            Qt.quit();
        } catch (error) {
            console.error(error, error.stack);
            Qt.exit(1);
        }
    }
}
