pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Clavis.Files
import qs.Common
import qs.Components
import qs.Services
import qs.Widgets.common
import "../../Common/functions/DockLayout.js" as DockLayout

Item {
    id: root
    required property string entryKey
    property real maximumWidth: 600
    property real maximumHeight: 600
    property bool contextMenu: false
    property string edge: "bottom"
    property real anchorOffset: width / 2
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
    readonly property bool hovered: fan ? fanItems.some(item => item.hovered) : list ? menuSurfaces.some(item
                                                                                                         => item.menuHovered) :
                                                                                       hover.hovered
    readonly property bool directoryAvailable: !!directory.item && directory.item.available
    readonly property int count: directory.item ? directory.item.count : 0
    readonly property var fanLayout: DockLayout.folderFan(edge, count, maximumWidth, maximumHeight,
                                                          labelsLeft)
    readonly property int fanCount: fanLayout.count
    readonly property var inputItems: !visible ? [] : list ? menuSurfaces : fan ? fanItems : [root]
    readonly property var blurBackgroundItems: !visible ? [] : list ? menuSurfaces : fan ? fanItems.map(item
                                                                                                        => item.glassItem
                                                                                                           || item) :
                                                                                           bubble.blurItems
    property var fanItems: []
    property real progress: 0
    signal dismissed
    width: fan ? fanLayout.width : Math.min(maximumWidth, contextMenu ? 300 : list ? 360 : 460)
    height: fan ? fanLayout.height : list ? Math.min(maximumHeight, (count + 2) * 34 + 18) : contextMenu
                                            ? Math.min(maximumHeight, menuColumn.height + 26) : Math.min(
                                                  maximumHeight, 400)
    onEntryKeyChanged: {
        browsingUrl = "";
        history = [];
        confirmEmpty = false;
    }
    onVisibleChanged: {
        if (visible) {
            progress = 0;
            opening.restart();
        } else {
            confirmEmpty = false;
            history = [];
            browsingUrl = "";
        }
    }
    NumberAnimation {
        id: opening
        target: root
        property: "progress"
        to: 1
        duration: 220
        easing.type: Easing.OutCubic
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
    function updateFanItems() {
        const items = [fanFooter];
        for (let i = 0; i < fanRows.count; ++i)
            if (fanRows.itemAt(i))
                items.push(fanRows.itemAt(i));
        fanItems = items;
    }
    Loader {
        id: directory
        active: root.visible && !root.contextMenu && !!root.entry && root.entry.kind === "folder"
        sourceComponent: DockFolderModel {
            folder: root.currentUrl
            sort: root.entry.sort
        }
    }
    Connections {
        target: directory.item
        function onLoadingChanged() {
            if (root.fan && directory.item && !directory.item.loading) {
                root.progress = 0;
                opening.restart();
            }
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
        onLoaded: item.popup()
        sourceComponent: DockFolderMenu {
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
    Item {
        id: fanContent
        anchors.fill: parent
        visible: root.fan
        Repeater {
            id: fanRows
            model: root.visible && root.fan ? root.fanCount : 0
            onItemAdded: Qt.callLater(root.updateFanItems)
            onItemRemoved: Qt.callLater(root.updateFanItems)
            DockFileTile {
                required property int index
                fileInfo: directory.item ? directory.item.get(index) : ({})
                fan: true
                labelsLeft: root.labelsLeft
                readonly property var slot: root.fanLayout.slots[index]
                verticalLabel: root.edge !== "bottom"
                width: slot.width
                height: slot.height
                x: root.edge === "bottom" ? slot.x : (root.edge === "left" ? -32 : root.width - 32) * (1 - root.progress)
                                            + slot.x * root.progress
                y: root.edge === "bottom" ? root.height - 64 + root.progress * (slot.y - root.height + 64) : (
                                                root.height / 2 - 32) * (1 - root.progress) + slot.y
                                            * root.progress
                opacity: root.progress
                scale: 0.7 + 0.3 * root.progress
                onActivated: info => root.open(info)
            }
        }
        Rectangle {
            id: fanFooter
            readonly property bool hovered: footerHover.hovered
            HoverHandler {
                id: footerHover
            }
            width: Math.max(0, Math.min(330, root.width - 48))
            height: 48
            y: root.edge === "bottom" ? 0 : parent.height - height
            x: root.labelsLeft ? root.width - width - 7 : 7
            radius: 24
            color: BlurService.backgroundColor(Appearance.colors.colSurfaceContainer)
            StyledMenuItem {
                anchors.fill: parent
                anchors.leftMargin: root.history.length ? 36 : 0
                text: !root.directoryAvailable ? qsTr("Folder is unavailable") : root.count ? qsTr(
                                                                                                  "Open in File Manager") :
                                                                                              qsTr("Folder is empty")
                iconName: "open_in_new"
                enabled: root.directoryAvailable
                onTriggered: {
                    ApplicationService.openUrl(root.currentUrl);
                    root.dismissed();
                }
            }
            StyledMenuItem {
                visible: root.history.length > 0
                width: 36
                height: parent.height
                iconName: "arrow_back"
                onTriggered: {
                    root.browsingUrl = root.history[root.history.length - 1];
                    root.history = root.history.slice(0, -1);
                }
            }
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
            cellWidth: width / Math.max(1, Math.floor(width / 106))
            cellHeight: 112
            model: directory.item ? directory.item.model : null
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
