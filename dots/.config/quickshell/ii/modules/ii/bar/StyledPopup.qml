import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

LazyLoader {
    id: root

    property Item hoverTarget
    default property Item contentItem
    property real popupBackgroundMargin: 0
    property real xOffset: 0

    property bool popupHovered: false
    property bool shouldBeActive: false
    property bool hoverTargetContainsMouse: hoverTarget ? hoverTarget.containsMouse : false
    property QtObject closeTimerObject: null
    property bool clickToToggle: false

    active: shouldBeActive

    onHoverTargetContainsMouseChanged: {
        if (root.clickToToggle) return;
        if (hoverTargetContainsMouse) {
            if (root.closeTimerObject) root.closeTimerObject.stop();
            root.shouldBeActive = true;
        } else {
            if (root.closeTimerObject) root.closeTimerObject.start();
        }
    }

    Timer {
        id: closeTimer
        interval: 250
        onTriggered: {
            if (!popupHovered && !hoverTargetContainsMouse) {
                root.shouldBeActive = false;
            }
        }
        Component.onCompleted: {
            root.closeTimerObject = closeTimer;
        }
    }

    Connections {
        target: root.hoverTarget || null
        ignoreUnknownSignals: true
        function onClicked() {
            if (root.clickToToggle) {
                root.shouldBeActive = !root.shouldBeActive;
            }
        }
    }

    Component.onCompleted: {
        if (hoverTargetContainsMouse && !clickToToggle) {
            root.shouldBeActive = true;
        }
    }

    component: PanelWindow {
        id: popupWindow
        color: "transparent"

        anchors.left: !Config.options.bar.vertical || (Config.options.bar.vertical && !Config.options.bar.bottom)
        anchors.right: Config.options.bar.vertical && Config.options.bar.bottom
        anchors.top: Config.options.bar.vertical || (!Config.options.bar.vertical && !Config.options.bar.bottom)
        anchors.bottom: !Config.options.bar.vertical && Config.options.bar.bottom

        implicitWidth: popupBackground.implicitWidth + Appearance.sizes.elevationMargin * 2 + root.popupBackgroundMargin
        implicitHeight: popupBackground.implicitHeight + Appearance.sizes.elevationMargin * 2 + root.popupBackgroundMargin

        mask: Region {
            item: popupBackground
        }

        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        margins {
            left: {
                if (!Config.options.bar.vertical) {
                    let mapped = root.QsWindow?.mapFromItem(
                        root.hoverTarget, 
                        (root.hoverTarget.width - popupBackground.implicitWidth) / 2 + root.xOffset, 0
                    );
                    let calculatedX = mapped ? mapped.x : 0;
                    let screenWidth = (popupWindow && popupWindow.screen) ? popupWindow.screen.width : 1920;
                    let popupWidth = popupBackground.implicitWidth + Appearance.sizes.elevationMargin * 2 + root.popupBackgroundMargin;
                    let maxMargin = screenWidth - popupWidth - 10;
                    return Math.max(10, Math.min(calculatedX, maxMargin));
                }
                return Appearance.sizes.verticalBarWidth
            }
            top: {
                if (!Config.options.bar.vertical) return Appearance.sizes.barHeight;
                return root.QsWindow?.mapFromItem(
                    root.hoverTarget, 
                    (root.hoverTarget.height - popupBackground.implicitHeight) / 2, 0
                ).y;
            }
            right: Appearance.sizes.verticalBarWidth
            bottom: Appearance.sizes.barHeight
        }
        WlrLayershell.namespace: "quickshell:popup"
        WlrLayershell.layer: WlrLayer.Overlay

        StyledRectangularShadow {
            target: popupBackground
        }

        Rectangle {
            id: popupBackground
            readonly property real margin: 10
            anchors {
                fill: parent
                leftMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.left)
                rightMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.right)
                topMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.top)
                bottomMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.bottom)
            }
            implicitWidth: root.contentItem.implicitWidth + margin * 2
            implicitHeight: root.contentItem.implicitHeight + margin * 2
            color: Appearance.m3colors.m3surfaceContainer
            radius: Appearance.rounding.small
            children: [root.contentItem]

            border.width: 1
            border.color: Appearance.colors.colLayer0Border

            HoverHandler {
                id: popupHoverHandler
                onHoveredChanged: {
                    if (root.clickToToggle) return;
                    root.popupHovered = hovered;
                    if (!hovered && (!root.hoverTarget || !root.hoverTarget.containsMouse)) {
                        if (root.closeTimerObject) root.closeTimerObject.start();
                    } else if (hovered) {
                        if (root.closeTimerObject) root.closeTimerObject.stop();
                    }
                }
            }
        }
    }
}
