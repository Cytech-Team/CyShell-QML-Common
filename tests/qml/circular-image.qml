import QtQuick
import Quickshell
import qs.CyCommon.Widgets

ShellRoot {
    id: root

    property int phase: 0
    property string staticPath: Quickshell.env("CY_CIRCULAR_IMAGE_STATIC") || ""
    property string animatedPath: Quickshell.env("CY_CIRCULAR_IMAGE_ANIMATED") || ""
    property bool sawAnimatedReset: false
    property bool sawErrorReset: false

    CyCircularImage {
        id: image
        width: 64
        height: 64
        imageSource: root.staticPath
        fallbackIcon: "image"

        onProbeSettledChanged: {
            if (!probeSettled && root.phase === 2)
                root.sawAnimatedReset = true;
            if (!probeSettled && root.phase === 3)
                root.sawErrorReset = true;
            if (probeSettled)
                Qt.callLater(root.handleProbeSettled);
        }
        onImageStatusChanged: Qt.callLater(root.handleImageStatus)
    }

    function equal(actual, expected, label) {
        if (actual !== expected)
            throw new Error(label + ": " + actual + " != " + expected);
    }

    function probeObject(item) {
        if (item.objectName === "cyCircularImageProbe")
            return item;
        for (const child of item.children || []) {
            const found = probeObject(child);
            if (found)
                return found;
        }
        return null;
    }

    function handleProbeSettled() {
        try {
            const probe = probeObject(image);
            equal(!!probe, true, "probe object exists");

            if (phase === 0) {
                equal(image.isAnimated, false, "static image classification");
                equal(probe.source.toString(), "", "static probe releases its source");
                phase = 1;
                handleImageStatus();
                return;
            }

            if (phase === 2) {
                equal(image.isAnimated, true, "animated image classification");
                equal(probe.source.toString(), animatedPath, "animated probe keeps its source");
                equal(probe.frameCount > 1, true, "animated fixture has multiple frames");
                equal(image.activeImage, probe, "animated probe remains active");
                phase = 3;
                image.imageSource = animatedPath + ".missing";
                equal(sawErrorReset, true, "failed replacement resets classification");
                return;
            }

            if (phase === 3) {
                equal(image.isAnimated, false, "failed image is not animated");
                equal(probe.source.toString(), "", "failed probe releases its source");
                equal(image.imageStatus === Image.Ready, false, "failed image uses fallback state");
                equal(image.fallbackIcon, "image", "fallback icon remains configured");
                console.log("PASS circular image probe releases static and error resources");
                Qt.quit();
            }
        } catch (error) {
            fail(error);
        }
    }

    function handleImageStatus() {
        if (phase !== 1 || image.imageStatus !== Image.Ready)
            return;
        try {
            const probe = probeObject(image);
            equal(image.activeImage === probe, false, "static image takes over from probe");
            equal(image.activeImage.status, Image.Ready, "static image loads after probe release");
            equal(image.imageSource, staticPath, "static source is unchanged");
            phase = 2;
            image.imageSource = animatedPath;
            equal(sawAnimatedReset, true, "animated source resets classification");
        } catch (error) {
            fail(error);
        }
    }

    function fail(error) {
        console.error(error, error.stack);
        Qt.exit(1);
    }
}
