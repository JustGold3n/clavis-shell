import QtQuick
import qs.Services

Item {
    id: root

    required property string desktopId
    required property Item iconItem
    property bool dragged: false
    property bool preparing: false
    property bool nativeDragActive: false
    property bool holdsDrag: false
    property var capturedImage: null

    anchors.fill: parent
    enabled: desktopId !== "" && DockService.enabled

    function resetGesture() {
        dragged = false;
    }

    function finish() {
        preparing = false;
        nativeDragActive = false;
        // A provider refresh can destroy this delegate. Release the source only
        // after Qt's platform drag has returned from its nested event loop.
        Qt.callLater(root.releaseDrag);
    }

    function releaseDrag() {
        capturedImage = null;
        holdsDrag = false;
        DockService.externalDragActive = false;
    }

    Drag.dragType: Drag.Automatic
    Drag.supportedActions: Qt.CopyAction
    Drag.proposedAction: Qt.CopyAction
    Drag.mimeData: ({
                        "application/x-clavis-dock": JSON.stringify({
                                                                        schemaVersion: 1,
                                                                        kind: "app",
                                                                        desktopId: root.desktopId
                                                                    })
                    })
    Drag.hotSpot.x: root.iconItem.width / 2
    Drag.hotSpot.y: root.iconItem.height / 2
    Drag.onDragStarted: root.nativeDragActive = true
    Drag.onDragFinished: root.finish()

    DragHandler {
        id: gesture

        target: null
        acceptedButtons: Qt.LeftButton
        onActiveChanged: {
            if (active) {
                root.dragged = true;
                root.preparing = true;
                root.holdsDrag = true;
                DockService.externalDragActive = true;
                const captured = root.iconItem.grabToImage(result => {
                    if (!gesture.active || !root.preparing)
                        return;
                    root.preparing = false;
                    root.capturedImage = result;
                    root.Drag.imageSource = result.url;
                    root.Drag.active = true;
                });
                if (!captured)
                    root.finish();
            } else if (!root.nativeDragActive) {
                root.preparing = false;
                root.Drag.active = false;
                root.finish();
            }
        }
    }

    Component.onDestruction: {
        if (root.holdsDrag)
            DockService.externalDragActive = false;
    }
}
