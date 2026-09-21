pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common
import "../../Common/functions/DockLayout.js" as DockLayout

PanelWindow {
    id: root

    required property string edge
    readonly property bool horizontal: edge === "bottom"
    readonly property real axisLength: horizontal ? width : height
    readonly property real availableLength: Math.max(80, axisLength - 32)
    readonly property real edgeOffset: 8
    readonly property var kinds: {
        const revision = DockService.revision;
        const result = [];
        for (let i = 0; i < DockService.model.count; ++i)
            result.push(DockService.model.get(i).kind);
        return result;
    }
    readonly property real magnification: DockService.magnification ? DockService.magnificationScale : 1
    readonly property var baseLayout: DockLayout.layout(kinds, DockService.iconSize, availableLength,
                                                        magnification, 16, NaN, DockLayout.sectionBoundary(
                                                            kinds, DockService.pinnedEntries.length))
    readonly property real scrollOffset: horizontal ? icons.contentX - icons.originX : icons.contentY
                                                      - icons.originY
    readonly property real pointerInBase: pointerAxis - (axisLength - Math.min(baseLayout.baseLength,
                                                                               availableLength)) / 2
                                          + scrollOffset
    readonly property bool dragInside: dragKey !== "" && insideDropBand(dragPoint)
    readonly property int previewSource: dragKey ? DockService.rowIndex(dragKey) : externalOver
                                                   ? DockService.rowIndex(externalSourceKey) : -1
    readonly property var preview: DockLayout.previewOrder(kinds, previewSource, dragInside || externalOver
                                                           ? insertion : -1, draggedEntry ? draggedEntry.kind :
                                                                                            externalKind)
    readonly property var layout: DockLayout.layout(preview.kinds, baseLayout.size, availableLength,
                                                    magnification, 16, dragInside || externalOver || (
                                                        !dragKey && magnificationActive) ? pointerInBase : NaN,
                                                    DockLayout.sectionBoundary(preview.kinds,
                                                                               DockService.pinnedEntries.length,
                                                                               preview.order))
    readonly property var slotsByIndex: {
        const result = [];
        for (let i = 0; i < preview.order.length; ++i) {
            if (preview.order[i] >= 0)
                result[preview.order[i]] = layout.slots[i];
        }
        return result;
    }
    readonly property real bandLength: Math.min(availableLength, Math.max(96, layout.length))
    readonly property real bandThickness: baseLayout.size * magnification + 36
    readonly property real restingThickness: baseLayout.size + 22
    readonly property bool shown: !DockService.autoHide || revealed || DockService.externalDragActive
                                  || dragKey !== "" || popupKey !== "" || dragGhost.active
    readonly property bool interacting: bandHover.hovered || edgeHover.hovered || popup.hovered
                                        || dropArea.containsDrag || dragKey !== ""
                                        || DockService.externalDragActive || dragGhost.active
    property bool revealed: false
    property real pointerAxis: 0
    property bool magnificationActive: false
    property string hoverKey: ""
    property string pendingPopupKey: ""
    property string popupKey: ""
    property bool contextMenu: false
    property real popupAxis: axisLength / 2
    property real popupCross: 0
    property string dragKey: ""
    property bool dragCancelled: false
    property point dragPoint: Qt.point(0, 0)
    property point dropPoint: Qt.point(0, 0)
    property int insertion: -1
    property bool externalOver: false
    property string externalKind: "app"
    property string externalSourceKey: ""
    property point dragGrabOffset: Qt.point(0, 0)
    readonly property var draggedEntry: {
        return dragKey && dragGhost.entry ? dragGhost.entry : null;
    }
    readonly property bool removeOnRelease: !!draggedEntry && draggedEntry.pinned
                                            && DockLayout.removalDistance(edge, dragPoint.x, dragPoint.y,
                                                                          width, height, edgeOffset)
                                            > bandThickness + 48

    function updateInteraction() {
        if (interacting) {
            revealed = true;
            hideTimer.stop();
            closeTimer.stop();
        } else {
            if (revealed || popupKey)
                hideTimer.restart();
            if (popupKey)
                closeTimer.restart();
            hoverTimer.stop();
        }
    }
    function hoverEntry(key) {
        if (WindowPreviewService.suspended || dragKey || dragGhost.active || DockService.externalDragActive
                || contextMenu)
            return;
        hoverKey = key;
        closeTimer.stop();
        // Changing the layer-shell input region or animating the icon slots
        // can deliver leave/enter again without a different app being hovered.
        // Keep that preview and its capture session alive across re-entry.
        if (popupKey === key) {
            pendingPopupKey = "";
            hoverTimer.stop();
            return;
        }
        if (pendingPopupKey === key && hoverTimer.running)
            return;
        pendingPopupKey = key;
        hoverTimer.restart();
    }
    function leaveEntry(key) {
        if (hoverKey !== key)
            return;
        hoverKey = "";
        pendingPopupKey = "";
        hoverTimer.stop();
    }
    function showPopup(key, context) {
        if (WindowPreviewService.suspended)
            return;
        const entry = DockService.entryFor(key);
        if (!entry || (!context && entry.kind !== "app"))
            return;
        hoverTimer.stop();
        const slot = slotForKey(key);
        popupAxis = slot ? (axisLength - bandLength) / 2 + slot.start + slot.span / 2 - scrollOffset :
                           pointerAxis;
        // Anchor to visible artwork / tray, not the oversized interaction band.
        // Snapshot the edge so the popup stays put when the pointer moves into
        // it and the dock's hover magnification subsequently settles down.
        const trayStart = glass.mapToItem(content, 0, 0);
        const trayEnd = glass.mapToItem(content, glass.width, glass.height);
        popupCross = horizontal ? trayStart.y : edge === "left" ? trayEnd.x : trayStart.x;
        for (let i = 0; i < iconItems.count; ++i) {
            const item = iconItems.itemAt(i);
            if (!item || item.entryKey !== key)
                continue;
            const artwork = item.artworkItem;
            const start = artwork.mapToItem(content, 0, 0);
            const end = artwork.mapToItem(content, artwork.width, artwork.height);
            popupAxis = horizontal ? (start.x + end.x) / 2 : (start.y + end.y) / 2;
            popupCross = horizontal ? Math.min(popupCross, start.y) : edge === "left" ? Math.max(popupCross,
                                                                                                 end.x) : Math.min(
                                                                                            popupCross,
                                                                                            start.x);
            break;
        }
        popupKey = key;
        contextMenu = context;
        if (context)
            content.forceActiveFocus();
    }
    function dismissPopup() {
        popupKey = "";
        contextMenu = false;
        pendingPopupKey = "";
        hoverTimer.stop();
        updateInteraction();
    }
    // Hit testing stays in the unchanged model's coordinate system. Animated
    // neighbours and the provisional gap must not move their own thresholds.
    function insertionAt(point) {
        const origin = (axisLength - Math.min(baseLayout.baseLength, availableLength)) / 2;
        const coordinate = (horizontal ? point.x : point.y) - origin + scrollOffset;
        const candidate = Math.min(DockService.pinnedEntries.length, DockLayout.insertionIndex(
                                       baseLayout.slots, coordinate));
        if (insertion >= 0 && Math.abs(candidate - insertion) === 1) {
            const crossed = baseLayout.slots[Math.min(candidate, insertion)];
            if (crossed && Math.abs(coordinate - crossed.center) < 6)
                return insertion;
        }
        return candidate;
    }
    function insideDropBand(point) {
        const major = horizontal ? point.x : point.y;
        return major >= 0 && major <= axisLength && DockLayout.removalDistance(edge, point.x, point.y, width, height,
                                                                               edgeOffset) <= bandThickness
                + 24;
    }
    function slotForKey(key) {
        const revision = DockService.revision;
        return slotsByIndex[DockService.rowIndex(key)] || null;
    }
    function copyEntry(entry) {
        const value = {};
        for (const role of ["key", "kind", "name", "icon", "symbol", "pinned", "focused", "launching",
                            "available", "windowCount"])
            value[role] = entry[role];
        return value;
    }
    function syncVisualEntries() {
        const wanted = new Set();
        for (let i = 0; i < DockService.model.count; ++i) {
            const entry = DockService.model.get(i);
            wanted.add(entry.key);
            let found = -1;
            for (let j = 0; j < visualEntries.count; ++j) {
                if (visualEntries.get(j).key === entry.key) {
                    found = j;
                    break;
                }
            }
            const row = copyEntry(entry);
            row.retiring = false;
            if (found < 0)
                visualEntries.append(row);
            else
                visualEntries.set(found, row);
        }
        for (let i = 0; i < visualEntries.count; ++i) {
            if (!wanted.has(visualEntries.get(i).key))
                visualEntries.setProperty(i, "retiring", true);
        }
    }
    function removeRetired() {
        for (let i = visualEntries.count - 1; i >= 0; --i) {
            const item = iconItems.itemAt(i);
            if (visualEntries.get(i).retiring && item && item.presence === 0)
                visualEntries.remove(i);
        }
    }
    function moveDrag(key, point, offset, size) {
        if (dragCancelled)
            return;
        if (dragKey !== key) {
            const entry = DockService.entryFor(key);
            if (!entry)
                return;
            dragGrabOffset = offset;
            dragGhost.begin(copyEntry(entry), Qt.point(point.x - offset.x, point.y - offset.y), size);
            dragKey = key;
            dismissPopup();
            content.forceActiveFocus();
        }
        dragPoint = point;
        pointerAxis = horizontal ? point.x : point.y;
        insertion = insertionAt(point);
        dragGhost.follow(Qt.point(point.x - dragGrabOffset.x, point.y - dragGrabOffset.y));
        dragGhost.removalArmed = removeOnRelease;
        revealed = true;
    }
    function finishDrag(key, point) {
        if (dragCancelled || dragKey !== key) {
            cancelDrag();
            dragCancelled = false;
            return;
        }
        dragPoint = point;
        const entry = DockService.entryFor(key);
        let removed = false;
        if (removeOnRelease)
            removed = DockService.unpin(key);
        else if (entry && insideDropBand(point)) {
            const target = insertionAt(point);
            if (entry.pinned)
                DockService.movePinned(key, target);
            else if (entry.desktopId)
                DockService.pin(entry.desktopId, target);
        }
        dragKey = "";
        insertion = -1;
        if (removed)
            dragGhost.remove();
        else
            Qt.callLater(root.landGhost);
        dragCancelled = false;
        updateInteraction();
    }
    function landGhost() {
        if (!dragGhost.active || dragKey)
            return;
        const slot = slotForKey(dragGhost.entry.key);
        if (!slot) {
            dragGhost.remove();
            return;
        }
        const major = (axisLength - bandLength) / 2 + slot.start + slot.span / 2 - scrollOffset;
        const cross = horizontal ? height - edgeOffset - 12 - slot.size / 2 : edge === "left" ? edgeOffset
                                                                                                + 10 + slot.size
                                                                                                / 2 : width
                                                                                                - edgeOffset
                                                                                                - 10 - slot.size
                                                                                                / 2;
        dragGhost.land(horizontal ? Qt.point(major, cross) : Qt.point(cross, major), slot.size);
    }
    function cancelDrag() {
        if (!dragKey)
            return;
        dragKey = "";
        insertion = -1;
        Qt.callLater(root.landGhost);
        updateInteraction();
    }
    function scrollBy(amount) {
        if (horizontal)
            icons.contentX = Math.max(icons.originX, Math.min(icons.originX + Math.max(0, icons.contentWidth
                                                                                       - icons.width),
                                                              icons.contentX + amount));
        else
            icons.contentY = Math.max(icons.originY, Math.min(icons.originY + Math.max(0, icons.contentHeight
                                                                                       - icons.height),
                                                              icons.contentY + amount));
    }

    ListModel {
        id: visualEntries
    }
    Connections {
        target: DockService
        function onRevisionChanged() {
            root.syncVisualEntries();
        }
    }
    Connections {
        target: WindowPreviewService
        function onSuspendedChanged() {
            if (WindowPreviewService.suspended)
                root.dismissPopup();
        }
    }
    Component.onCompleted: root.syncVisualEntries()

    // The surface supplies animation/drag space; only the visible interaction
    // regions accept input. Its exclusive zone is always the resting dock.
    implicitWidth: screen ? screen.width : 1280
    implicitHeight: screen ? screen.height : 720
    color: "transparent"
    anchors.left: horizontal || edge === "left"
    anchors.right: horizontal || edge === "right"
    anchors.top: !horizontal
    anchors.bottom: true
    exclusiveZone: DockService.autoHide ? 0 : restingThickness + edgeOffset
    WlrLayershell.namespace: "clavis-shell-dock"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusionMode: ExclusionMode.Normal
    WlrLayershell.keyboardFocus: dragKey || contextMenu ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onInteractingChanged: updateInteraction()
    onShownChanged: {
        if (!shown)
            dismissPopup();
    }

    // Region changes can briefly reset HoverHandler during popup creation.
    // Preserve the last scene position and absorb that transient leave.
    Timer {
        id: magnificationExit
        interval: 80
        onTriggered: {
            if (!bandHover.hovered)
                root.magnificationActive = false;
        }
    }
    Timer {
        id: hideTimer
        interval: 650
        onTriggered: {
            if (!root.interacting) {
                root.revealed = false;
                root.dismissPopup();
            }
        }
    }
    Timer {
        id: closeTimer
        interval: 350
        onTriggered: {
            if (!root.interacting)
                root.dismissPopup();
        }
    }
    Timer {
        id: hoverTimer
        interval: 450
        onTriggered: {
            if (root.pendingPopupKey && root.pendingPopupKey === root.hoverKey && bandHover.hovered && !root.dragKey &&
                    !dragGhost.active)
                root.showPopup(root.pendingPopupKey, false);
        }
    }
    Timer {
        interval: 40
        repeat: true
        running: (root.dragKey !== "" || dropArea.containsDrag) && root.layout.overflow
        onTriggered: {
            const position = root.dragKey ? root.dragPoint : root.dropPoint;
            const local = icons.mapFromItem(content, position.x, position.y);
            const coordinate = root.horizontal ? local.x : local.y;
            if (coordinate < 28)
                root.scrollBy(-12);
            else if (coordinate > root.bandLength - 28)
                root.scrollBy(12);
            root.insertion = root.insertionAt(position);
        }
    }

    Item {
        id: content
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: event => {
            root.dragCancelled = true;
            root.cancelDrag();
            root.dismissPopup();
            event.accepted = true;
        }

        Item {
            id: edgeTrigger
            width: root.horizontal ? Math.max(96, Math.min(root.availableLength, root.baseLayout.baseLength)) :
                                     3
            height: root.horizontal ? 3 : Math.max(96, Math.min(root.availableLength,
                                                                root.baseLayout.baseLength))
            x: root.horizontal ? (parent.width - width) / 2 : root.edge === "left" ? 0 : parent.width - width
            y: root.horizontal ? parent.height - height : (parent.height - height) / 2
            HoverHandler {
                id: edgeHover
                onHoveredChanged: {
                    if (hovered)
                        root.revealed = true;
                }
            }
            DropArea {
                anchors.fill: parent
                onEntered: drag => {
                    if (drag.formats.indexOf("application/x-clavis-dock") >= 0 || drag.hasUrls) {
                        root.revealed = true;
                        drag.accepted = true;
                    } else {
                        drag.accepted = false;
                    }
                }
            }
        }

        Item {
            id: band
            width: root.horizontal ? root.bandLength : root.bandThickness
            height: root.horizontal ? root.bandThickness : root.bandLength
            x: root.horizontal ? (parent.width - width) / 2 : root.edge === "left" ? root.edgeOffset :
                                                                                     parent.width - width
                                                                                     - root.edgeOffset
            y: root.horizontal ? parent.height - height - root.edgeOffset : (parent.height - height) / 2
            opacity: root.shown ? 1 : 0
            visible: opacity > 0
            enabled: root.shown
            // Animate the centered tray with its slots, including app arrival
            // and removal; otherwise its origin would jump by half an icon.
            Behavior on width {
                enabled: root.horizontal
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on height {
                enabled: !root.horizontal
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }
            transform: Translate {
                x: root.horizontal ? 0 : root.shown ? 0 : root.edge === "left" ? -band.width
                                                                                 - root.edgeOffset :
                                                                                 band.width + root.edgeOffset
                y: root.horizontal && !root.shown ? band.height + root.edgeOffset : 0
                Behavior on x {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                }
            }

            HoverHandler {
                id: bandHover
                onHoveredChanged: {
                    if (hovered) {
                        magnificationExit.stop();
                        root.magnificationActive = true;
                    } else {
                        magnificationExit.restart();
                    }
                }
                onPointChanged: {
                    if (hovered)
                        root.pointerAxis = root.horizontal ? point.scenePosition.x : point.scenePosition.y;
                }
            }

            Rectangle {
                id: glass
                x: root.horizontal ? 0 : root.edge === "left" ? 0 : parent.width - width
                y: root.horizontal ? parent.height - height : 0
                width: root.horizontal ? parent.width : root.restingThickness
                height: root.horizontal ? root.restingThickness : parent.height
                radius: 20
                color: BlurService.backgroundColor(Appearance.colors.colSurfaceContainer)
                border.color: Appearance.applyAlpha(Appearance.colors.colOutlineVariant, 0.65)
                border.width: 1
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    onClicked: {
                        const entry = DockService.model.count ? DockService.model.get(0) : null;
                        if (entry)
                            root.showPopup(entry.key, true);
                        else
                            ControlCenterService.openSearch("general.dock");
                    }
                }
            }

            Flickable {
                id: icons
                anchors.fill: parent
                contentWidth: root.horizontal ? root.layout.length : width
                contentHeight: root.horizontal ? height : root.layout.length
                clip: true
                interactive: false
                boundsBehavior: Flickable.StopAtBounds
                onContentWidthChanged: root.scrollBy(0)
                onContentHeightChanged: root.scrollBy(0)

                Rectangle {
                    visible: root.layout.divider >= 0
                    width: root.horizontal ? 2 : root.restingThickness - 20
                    height: root.horizontal ? root.restingThickness - 20 : 2
                    x: root.horizontal ? root.layout.divider - width / 2 : glass.x + 10
                    y: root.horizontal ? glass.y + 10 : root.layout.divider - height / 2
                    radius: 1
                    color: Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.4)
                    Behavior on x {
                        NumberAnimation {
                            duration: 160
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on y {
                        NumberAnimation {
                            duration: 160
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Repeater {
                    id: iconItems
                    model: visualEntries
                    delegate: DockItem {
                        id: dockItem
                        required property string key
                        required property bool retiring
                        property bool appeared: false
                        // Position is keyed by application, never by the order
                        // in which presentation objects happened to be created.
                        property var lastSlot: ({
                                                    start: 12,
                                                    span: 0,
                                                    size: root.baseLayout.size
                                                })
                        readonly property var slot: root.slotForKey(key) || lastSlot
                        onSlotChanged: {
                            if (!retiring && root.slotForKey(key))
                                lastSlot = slot;
                        }
                        entryKey: key
                        edge: root.edge
                        x: root.horizontal ? slot.start : 0
                        y: root.horizontal ? 0 : slot.start
                        width: root.horizontal ? slot.span : icons.width
                        height: root.horizontal ? icons.height : slot.span
                        iconSize: slot.size
                        restingIconSize: root.baseLayout.size
                        contextActive: root.contextMenu && root.popupKey === key
                        showTooltip: !root.contextMenu && root.popupKey === key && (windowCount === 0 ||
                                                                                    !DockService.showThumbnails)
                                     && kind === "app" && !WindowPreviewService.suspended
                        dragged: key === root.dragKey || (dragGhost.entry && dragGhost.entry.key === key) || (
                                     root.externalOver && root.externalSourceKey === key)
                        enabled: !retiring
                        presence: appeared && !retiring ? 1 : 0
                        Component.onCompleted: appeared = true
                        onPresenceChanged: {
                            if (retiring && presence === 0)
                                Qt.callLater(root.removeRetired);
                        }
                        onRetiringChanged: {
                            if (retiring)
                                Qt.callLater(root.removeRetired);
                        }
                        Behavior on presence {
                            NumberAnimation {
                                duration: 160
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on x {
                            enabled: dockItem.appeared
                            NumberAnimation {
                                duration: 160
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on y {
                            enabled: dockItem.appeared
                            NumberAnimation {
                                duration: 160
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on width {
                            enabled: root.horizontal
                            NumberAnimation {
                                duration: 120
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on height {
                            enabled: !root.horizontal
                            NumberAnimation {
                                duration: 120
                                easing.type: Easing.OutCubic
                            }
                        }
                        onPressStarted: {
                            root.dragCancelled = false;
                            root.dismissPopup();
                        }
                        onHovered: key => root.hoverEntry(key)
                        onHoverLeft: key => root.leaveEntry(key)
                        onActivated: key => {
                            root.dragCancelled = false;
                            DockService.activate(key);
                            root.dismissPopup();
                        }
                        onContextRequested: key => root.showPopup(key, true)
                        onDragMoved: (key, position, offset, size) => root.moveDrag(key, position, offset,
                                                                                    size)
                        onDragReleased: (key, position) => root.finishDrag(key, position)
                        onDragCancelled: {
                            root.cancelDrag();
                            root.dragCancelled = false;
                        }
                    }
                }
                ScrollBar.horizontal: StyledScrollBar {
                    visible: root.horizontal && root.layout.overflow
                }
                ScrollBar.vertical: StyledScrollBar {
                    visible: !root.horizontal && root.layout.overflow
                }
                WheelHandler {
                    target: null
                    onWheel: event => {
                        const delta = event.pixelDelta.y || event.pixelDelta.x || event.angleDelta.y
                              || event.angleDelta.x;
                        root.scrollBy(-delta);
                        event.accepted = true;
                    }
                }
            }

            DropArea {
                id: dropArea
                anchors.fill: parent
                onEntered: drag => {
                    // Foreign file data is validated on drop. In-process app
                    // drags can already preview their existing grouped identity.
                    drag.accepted = drag.formats.indexOf(DockService.dragMimeType) >= 0 || drag.hasUrls;
                    if (!drag.accepted)
                        return;
                    root.externalKind = drag.source && drag.source.spaceTemplate ? "spacer" : "app";
                    root.externalSourceKey = root.externalKind === "app" && drag.source
                            && typeof drag.source.desktopId === "string" ? "app:"
                                                                           + drag.source.desktopId.replace(
                                                                               /\.desktop$/, "") : "";
                    root.dropPoint = band.mapToItem(content, drag.x, drag.y);
                    root.pointerAxis = root.horizontal ? root.dropPoint.x : root.dropPoint.y;
                    root.insertion = root.insertionAt(root.dropPoint);
                    root.externalOver = true;
                    root.dismissPopup();
                    root.revealed = true;
                }
                onPositionChanged: drag => {
                    root.dropPoint = band.mapToItem(content, drag.x, drag.y);
                    root.pointerAxis = root.horizontal ? root.dropPoint.x : root.dropPoint.y;
                    root.insertion = root.insertionAt(root.dropPoint);
                }
                onExited: {
                    root.externalOver = false;
                    root.externalSourceKey = "";
                    root.insertion = -1;
                }
                onDropped: drop => {
                    const text = drop.getDataAsString(DockService.dragMimeType);
                    const incoming = DockService.dropEntries(text, drop.urls);
                    const before = new Set();
                    for (let i = 0; i < DockService.model.count; ++i)
                        before.add(DockService.model.get(i).key);
                    const accepted = DockService.acceptDrop(text, drop.urls, root.insertion);
                    let landingEntry = null;
                    if (accepted && incoming.length === 1) {
                        if (incoming[0].kind === "app")
                            landingEntry = DockService.entryFor("app:" + incoming[0].desktopId);
                        else {
                            for (let i = 0; i < DockService.model.count; ++i) {
                                const candidate = DockService.model.get(i);
                                if (!before.has(candidate.key)) {
                                    landingEntry = candidate;
                                    break;
                                }
                            }
                        }
                    }
                    if (landingEntry)
                        dragGhost.begin(root.copyEntry(landingEntry), root.dropPoint, root.baseLayout.size);
                    root.externalOver = false;
                    root.externalSourceKey = "";
                    root.insertion = -1;
                    if (accepted) {
                        drop.accept(Qt.CopyAction);
                        if (landingEntry)
                            Qt.callLater(root.landGhost);
                    }
                    root.updateInteraction();
                }
            }

            Text {
                anchors.centerIn: glass
                visible: DockService.model.count === 0
                text: qsTr("Drop apps here")
                font.family: Fonts.ui
                font.pixelSize: 12
                color: Appearance.colors.colOnSurfaceVariant
            }
        }

        DockPreviewPopup {
            id: popup
            visible: root.popupKey !== "" && !!entry && (root.contextMenu || (DockService.showThumbnails
                                                                              && windows.length > 0))
            entryKey: root.popupKey
            maximumWidth: root.horizontal ? Math.max(0, root.width - 32) : Math.max(0, (root.edge === "left"
                                                                                        ? root.width
                                                                                          - root.popupCross :
                                                                                          root.popupCross)
                                                                                    - 24)
            contextMenu: root.contextMenu
            edge: root.edge
            anchorOffset: root.popupAxis - (root.horizontal ? x : y)
            readonly property real dockGap: root.contextMenu ? 4 : 8
            maximumHeight: root.horizontal ? Math.max(0, root.popupCross - dockGap - 16) : Math.max(0, root.height
                                                                                                    - 32)
            x: root.horizontal ? Math.max(16, Math.min(root.width - width - 16, root.popupAxis - (
                                                           root.contextMenu ? 26 : width / 2))) : root.edge
                                 === "left" ? root.popupCross + dockGap : root.popupCross - width - dockGap
            y: root.horizontal ? root.popupCross - height - dockGap : Math.max(16, Math.min(root.height
                                                                                            - height - 16,
                                                                                            root.popupAxis - (
                                                                                                root.contextMenu
                                                                                                ? 26 : height
                                                                                                  / 2)))
            onDismissed: root.dismissPopup()
        }

        DockDragVisual {
            id: dragGhost
            onActiveChanged: root.updateInteraction()
        }
    }

    mask: Region {
        Region {
            item: root.shown ? band : null
        }
        Region {
            item: edgeTrigger
        }
        Region {
            item: popup.visible ? popup : null
        }
    }
    CompositorBlurRegion {
        targetWindow: root
        backgroundItem: glass
        additionalBackgroundItems: popup.visible ? popup.blurBackgroundItems : []
        blurEnabled: root.shown
        radius: 20
    }
}
