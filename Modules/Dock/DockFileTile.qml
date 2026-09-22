import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets.common

Item {
    id: root
    required property var fileInfo
    property bool compact: false
    property bool fan: false
    property bool verticalLabel: false
    property bool labelsLeft: true
    property real tileIconSize: compact ? 22 : 64
    signal activated(var info)
    readonly property bool hovered: pointer.containsMouse
    readonly property alias iconItem: artwork
    readonly property alias glassItem: background
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: fileInfo.name || ""
    Accessible.onPressAction: root.activated(fileInfo)
    Keys.onReturnPressed: root.activated(fileInfo)
    Keys.onSpacePressed: root.activated(fileInfo)
    implicitHeight: compact ? 34 : fan ? 68 : 112
    Rectangle {
        id: background
        y: root.verticalLabel ? parent.height - height : (parent.height - height) / 2
        width: root.fan && !root.verticalLabel ? parent.width - root.tileIconSize - 18 : parent.width
        height: root.fan ? 36 : parent.height
        x: root.fan && !root.verticalLabel && !root.labelsLeft ? root.tileIconSize + 18 : 0
        radius: root.fan ? height / 2 : 8
        color: root.fan ? BlurService.backgroundColor(Appearance.colors.colSurfaceContainer) :
                          pointer.containsMouse ? Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.12) :
                                                  "transparent"
        border.width: root.fan ? 1 : 0
        border.color: Appearance.applyAlpha(Appearance.colors.colOnSurface, 0.16)
    }
    DockFileIcon {
        id: artwork
        width: root.tileIconSize
        height: width
        info: root.fileInfo
        x: root.verticalLabel ? (parent.width - width) / 2 : root.compact ? 8 : root.fan ? (root.labelsLeft
                                                                                            ? parent.width
                                                                                              - width - 6 :
                                                                                              6) : (parent.width
                                                                                                    - width)
                                                                                           / 2
        y: root.verticalLabel ? 0 : root.compact || root.fan ? (parent.height - height) / 2 : 6
    }
    Text {
        x: root.compact ? 38 : root.fan && !root.verticalLabel && !root.labelsLeft ? root.tileIconSize + 28 :
                                                                                     10

        y: root.verticalLabel ? root.height - 36 : root.compact || root.fan ? 0 : root.tileIconSize + 12
        width: root.compact ? parent.width - 62 : root.fan && !root.verticalLabel ? parent.width
                                                                                    - root.tileIconSize - 38 :
                                                                                    parent.width - 20
        height: root.verticalLabel ? 36 : root.compact || root.fan ? parent.height : 32
        text: root.fileInfo.name || ""
        textFormat: Text.PlainText
        color: Appearance.colors.colOnSurface
        font.family: Fonts.ui
        font.pixelSize: 12
        horizontalAlignment: root.compact || root.fan ? Text.AlignLeft : Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideMiddle
        wrapMode: root.compact || root.fan ? Text.NoWrap : Text.Wrap
        maximumLineCount: 2
    }
    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: drag.dragged = false
        onClicked: {
            if (!drag.dragged)
                root.activated(root.fileInfo);
        }
        StyledToolTip {
            text: root.fileInfo.name || ""
            textFormat: Text.PlainText
        }
    }
    DockFileDrag {
        id: drag
        fileUrl: String(root.fileInfo.url || "")
        iconItem: artwork
    }
}
