pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Clavis.Files
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common

Item {
    id: root
    required property string entryKey
    property real maximumWidth: 600
    property real maximumHeight: 600
    property bool contextMenu: false
    property string edge: "bottom"
    property real anchorOffset: width / 2
    property point sourceCenter: Qt.point(anchorOffset, height + 32)
    property real iconSize: 64
    property bool labelsLeft: true
    readonly property var entry: {
        const revision = DockService.revision;
        return DockService.entryFor(entryKey);
    }
    property string browsingUrl: ""
    readonly property string currentUrl: browsingUrl || (entry && entry.url || "")
    property var history: []
    property bool confirmEmpty: false
    property var menuSurfaces: []
    readonly property bool fan: !contextMenu && !!entry && entry.view === "fan"
    readonly property bool list: !contextMenu && !!entry && entry.view === "list"
    readonly property bool hovered: fan ? fanView.hovered : list ? menuSurfaces.some(item => item
                                                                                             && item.menuHovered) :
                                                                   hover.hovered
    readonly property bool directoryAvailable: !!directory.item && directory.item.available
    readonly property int count: directory.item ? directory.item.count : 0
    property bool fanPresented: false
    property bool closing: false
    readonly property int fanCount: fanView.geometry.count
    readonly property real fanIconInset: fanView.geometry.iconInset
    readonly property var fanItems: fanView.tiles
    readonly property var inputItems: !visible ? [] : list ? menuSurfaces : fan ? [fanView] : [root]
    readonly property var blurBackgroundItems: !visible || fan ? [] : list ? menuSurfaces : bubble.blurItems
    readonly property var blurRegions: visible && fan ? fanView.blurRegions : []
    property real progress: 0
    readonly property int gridColumns: Math.max(1, Math.floor(grid.width / 106))
    readonly property int gridRows: Math.max(1, Math.min(4, Math.ceil(count / gridColumns)))
    signal dismissed
    width: fan ? fanView.implicitWidth : Math.min(maximumWidth, contextMenu ? 300 : list ? 360 : 460)
    height: fan ? fanView.implicitHeight : list ? Math.min(maximumHeight, (Math.max(1, count) + 1) * 34 + 28) :
                                                  contextMenu ? Math.min(maximumHeight, menuColumn.height
                                                                         + 26) : Math.min(maximumHeight, 20 + (
                                                                                              edge === "bottom"
                                                                                              ? bubble.tailSize :
                                                                                                0) + header.implicitHeight
                                                                                          + footer.implicitHeight
                                                                                          + gridRows
                                                                                          * grid.cellHeight)
    onEntryKeyChanged: {
        browsingUrl = "";
        history = [];
        confirmEmpty = false;
    }
    onVisibleChanged: {
        resetFan();
        if (!visible) {
            confirmEmpty = false;
            history = [];
            browsingUrl = "";
        }
    }
    onCurrentUrlChanged: resetFan()
    onFanChanged: resetFan()
    function resetFan() {
        closing = false;
        opening.stop();
        progress = 0;
        fanPresented = false;
        Qt.callLater(root.presentFan);
    }
    function presentFan() {
        if (!root.visible || !root.fan || !directory.item || !directory.item.ready || fanPresented)
            return;
        // Start once after a complete listing; live changes use ListView's
        // normal model updates and do not replay the opening animation.
        fanPresented = true;
        opening.start();
    }
    function closeFan() {
        if (closing)
            return;
        opening.stop();
        closing = true;
        opening.start();
    }
    function reopenFan() {
        opening.stop();
        closing = false;
        opening.start();
    }
    function presentList() {
        if (root.visible && root.list && directory.item && directory.item.ready && nativeList.item &&
                !nativeList.item.visible)
            nativeList.item.open();
    }
    NumberAnimation {
        id: opening
        target: root
        property: "progress"
        to: root.closing ? 0 : 1
        duration: root.closing ? 180 : 260
        easing.type: Easing.OutCubic
        onFinished: {
            if (root.closing)
                root.dismissed();
        }
    }
    HoverHandler {
        id: hover
        enabled: !root.fan && !root.list
    }
    function open(info) {
        if (!DesktopFiles.info(info.url).available) {
            DockService.fileError = qsTranslate("DockService", "This file or folder is unavailable.");
            return;
        }
        if (info.isDirectory) {
            history = history.concat([currentUrl]);
            browsingUrl = String(info.url);
        } else {
            ApplicationService.openUrl(info.url);
            dismissed();
        }
    }
    Loader {
        id: directory
        active: root.visible && !root.contextMenu && !!root.entry && root.entry.kind === "folder"
        onLoaded: Qt.callLater(root.presentFan)
        sourceComponent: DockFolderModel {
            folder: root.currentUrl
            sort: root.entry.sort
        }
    }
    Connections {
        target: directory.item
        function onReadyChanged() {
            Qt.callLater(root.presentFan);
            Qt.callLater(root.presentList);
        }
        function onRevisionChanged() {
            Qt.callLater(root.presentFan);
        }
    }
    DockBubbleSurface {
        id: bubble
        anchors.fill: parent
        visible: !root.fan && !root.list
        edge: root.edge
        anchorOffset: root.anchorOffset
    }
    Loader {
        id: nativeList
        active: root.visible && root.list
        onLoaded: Qt.callLater(root.presentList)
        sourceComponent: DockFolderMenu {
            parent: root
            x: 0
            y: 0
            width: root.width
            sharedModel: directory.item
            folderUrl: root.currentUrl
            sort: root.entry.sort
            maximumHeight: root.maximumHeight
            onSurfacesChanged: root.menuSurfaces = surfaces()
            onClosed: {
                if (root.visible && root.list)
                    root.dismissed();
            }
            onFileActivated: info => {
                ApplicationService.openUrl(info.url);
                root.dismissed();
            }
        }
    }
    DockFolderFan {
        id: fanView
        anchors.fill: parent
        visible: root.fan && root.fanPresented
        enabled: !root.closing
        model: root.fanPresented && directory.item ? directory.item.model : null
        count: root.fanPresented ? root.count : 0
        edge: root.edge
        labelsLeft: root.labelsLeft
        maximumWidth: root.maximumWidth
        maximumHeight: root.maximumHeight
        iconSize: root.iconSize
        sourceCenter: root.sourceCenter
        progress: root.progress
        canOpen: root.directoryAvailable
        canGoBack: root.history.length > 0
        actionText: root.history.length && directory.item ? directory.item.info.name : !root.directoryAvailable
                                                            ? qsTr("Folder is unavailable") : root.count
                                                              ? qsTr("Open in File Manager") : qsTr(
                                                                    "Folder is empty")
        onActivated: info => root.open(info)
        onOpenRequested: {
            ApplicationService.openUrl(root.currentUrl);
            root.dismissed();
        }
        onBackRequested: {
            root.browsingUrl = root.history[root.history.length - 1];
            root.history = root.history.slice(0, -1);
        }
    }
    Item {
        visible: !root.contextMenu && !root.fan && !root.list
        x: bubble.bodyX + 10
        y: 10
        width: bubble.bodyWidth - 20
        height: bubble.bodyHeight - 20
        StyledMenuItem {
            id: header
            width: parent.width
            implicitHeight: 34
            text: directory.item ? directory.item.info.name || "" : ""
            iconName: root.history.length ? "arrow_back" : "folder"
            enabled: true
            onTriggered: {
                if (!root.history.length)
                    return;
                root.browsingUrl = root.history[root.history.length - 1];
                root.history = root.history.slice(0, -1);
            }
        }
        GridView {
            id: grid
            anchors {
                left: parent.left
                right: parent.right
                top: header.bottom
                bottom: footer.top
            }
            clip: true
            cellWidth: width / root.gridColumns
            cellHeight: 112
            model: root.visible && !root.contextMenu && !root.fan && !root.list && directory.item
                   ? directory.item.model : null
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: StyledScrollBar {}
            delegate: DockFileTile {
                width: grid.cellWidth
                height: grid.cellHeight
                onActivated: info => root.open(info)
            }
            InlineBusyIndicator {
                anchors.centerIn: parent
                busy: !!directory.item && directory.item.loading
            }
            Text {
                anchors.centerIn: parent
                visible: root.count === 0 && !(directory.item && directory.item.loading)
                text: root.directoryAvailable ? qsTr("Folder is empty") : qsTr("Folder is unavailable")
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Fonts.ui
            }
        }
        StyledMenuItem {
            id: footer
            anchors.bottom: parent.bottom
            width: parent.width
            implicitHeight: 36
            text: qsTr("Open in File Manager")
            iconName: "open_in_new"
            enabled: root.directoryAvailable
            onTriggered: {
                ApplicationService.openUrl(root.currentUrl);
                root.dismissed();
            }
        }
    }
    readonly property var choices: {
        if (confirmEmpty)
            return [
                        {
                            heading: qsTr("Permanently delete all items in Trash?")
                        },
                        {
                            label: qsTr("Cancel"),
                            action: "cancel"
                        },
                        {
                            label: qsTr("Empty Trash"),
                            action: "empty",
                            destructive: true
                        }
                    ];
        let result = [];
        if (!entry)
            return result;
        if (entry.kind === "folder") {
            result.push({
                            heading: qsTr("Sort by")
                        });
            const sorts = [["name", qsTr("Name")], ["modified", qsTr("Date Modified")], ["created", qsTr(
                                                                                             "Date Created")],
                           ["kind", qsTr("Kind")], ["size", qsTr("Size")]];
            for (const option of sorts)
                result.push({
                                label: option[1],
                                option: "sort",
                                value: option[0]
                            });
            result.push({
                            heading: qsTr("Display as")
                        });
            result.push({
                            label: qsTr("Folder"),
                            option: "display",
                            value: "folder"
                        });
            result.push({
                            label: qsTr("Stack"),
                            option: "display",
                            value: "stack"
                        });
            result.push({
                            heading: qsTr("View content as")
                        });
            for (const option of [["fan", qsTr("Fan")], ["grid", qsTr("Grid")], ["list", qsTr("List")]])
                result.push({
                                label: option[1],
                                option: "view",
                                value: option[0]
                            });
        }
        result.push({
                        label: entry.kind === "trash" ? qsTr("Open Trash") : entry.kind === "file" ? qsTr(
                                                                                                         "Open") : qsTr(
                                                                                                         "Open in File Manager"),
                        action: "open"
                    });
        if (entry.kind === "trash")
            result.push({
                            label: qsTr("Empty Trash…"),
                            action: "confirm",
                            destructive: true
                        });
        else
            result.push({
                            label: qsTr("Remove from Dock"),
                            action: "remove"
                        });
        return result;
    }
    Flickable {
        visible: root.contextMenu
        x: bubble.bodyX + 8
        y: 8
        width: Math.max(0, bubble.bodyWidth - 16)
        height: Math.max(0, bubble.bodyHeight - 16)
        contentHeight: menuColumn.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: StyledScrollBar {}
        Column {
            id: menuColumn
            width: parent.width
            spacing: 2
            InlineStatusBanner {
                visible: DockService.fileError !== ""
                width: parent.width
                tone: "error"
                message: DockService.fileError
            }
            StyledMenuItem {
                visible: DockService.fileError !== ""
                width: parent.width
                implicitHeight: visible ? 30 : 0
                text: qsTr("Dismiss")
                onTriggered: DockService.fileError = ""
            }
            Text {
                visible: !!root.entry && root.entry.kind === "trash" && !DesktopFiles.trashAvailable
                width: parent.width - 16
                x: 8
                text: qsTr("Trash is unavailable. Install or enable GVfs.")
                wrapMode: Text.Wrap
                color: Appearance.colors.colOnSurfaceVariant
                font.family: Fonts.ui
                font.pixelSize: 12
            }
            Repeater {
                model: root.choices
                delegate: Column {
                    required property var modelData
                    width: menuColumn.width
                    Rectangle {
                        visible: !!modelData.heading
                        width: parent.width - 16
                        x: 8
                        height: 1
                        color: Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.16)
                    }
                    Text {
                        visible: !!parent.modelData.heading
                        text: parent.modelData.heading || ""
                        width: parent.width - 16
                        x: 8
                        topPadding: 8
                        bottomPadding: 6
                        wrapMode: Text.Wrap
                        font.family: Fonts.ui
                        font.pixelSize: 12
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                    StyledMenuItem {
                        readonly property var choice: parent.modelData
                        visible: !choice.heading
                        width: parent.width
                        implicitHeight: visible ? 30 : 0
                        text: choice.label || ""
                        checkable: !!choice.option
                        checked: !!root.entry && !!choice.option && root.entry[choice.option] === choice.value
                        destructive: !!choice.destructive
                        enabled: choice.action !== "confirm" && choice.action !== "empty"
                                 || DesktopFiles.trashAvailable && DesktopFiles.trashCount > 0 &&
                                 !DesktopFiles.busy
                        onTriggered: {
                            if (choice.option) {
                                DockService.folderOption(root.entryKey, choice.option, choice.value);
                                root.dismissed();
                            } else if (choice.action === "confirm")
                                root.confirmEmpty = true;
                            else if (choice.action === "cancel")
                                root.confirmEmpty = false;
                            else {
                                if (choice.action === "empty")
                                    DesktopFiles.emptyTrash();
                                if (choice.action === "remove")
                                    DockService.unpin(root.entryKey);
                                if (choice.action === "open")
                                    DockService.activate(root.entryKey);
                                root.dismissed();
                            }
                        }
                    }
                }
            }
        }
    }
}
