import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Widgets.common

Item {
    id: root

    readonly property bool isActive: root.visible && MediaManager.active
    property bool isPlaying: isActive && MediaManager.active && MediaManager.active.isPlaying

    property string artUrl: (isActive && MediaManager.active.trackArtUrl) ? MediaManager.active.trackArtUrl :
                                                                            ""

    property string title: (isActive && MediaManager.active.trackTitle) ? MediaManager.active.trackTitle :
                                                                          qsTr("No media")

    property string artist: (isActive && MediaManager.active.trackArtist) ? MediaManager.active.trackArtist :
                                                                            qsTr("Unknown artist")

    readonly property double currentPos: root.isActive ? MediaManager.currentPosition : 0

    readonly property bool hasDuration: isActive && Number.isFinite(MediaManager.active.length)
                                        && MediaManager.active.length > 0
    readonly property bool canSeek: hasDuration && MediaManager.active.canSeek
    readonly property double progress: hasDuration && Number.isFinite(root.currentPos) ? Math.max(0, Math.min(1,
                                                                                                              root.currentPos
                                                                                                              / MediaManager.active.length)) :
                                                                                         0
    readonly property bool caelestiaCover: PersonalizationConfig.keystoneMediaCoverStyle === "caelestia"
    readonly property real panelWidth: caelestiaCover || backgroundCover ? 640 : 540
    readonly property real panelHeight: caelestiaCover || backgroundCover ? 240 : 210
    readonly property bool backgroundCover: PersonalizationConfig.keystoneMediaCoverStyle === "background"
    readonly property bool coverColors: PersonalizationConfig.keystoneMediaColorStyle === "cover"
                                        && root.artUrl !== ""
    readonly property string paletteArtUrl: root.isActive && root.coverColors ? root.artUrl : ""
    readonly property color themePrimary: Appearance.colors.colPrimary
    readonly property color accentColor: coverColors ? MediaPalette.primary : Appearance.colors.colPrimary
    readonly property color onAccentColor: coverColors ? MediaPalette.onPrimary :
                                                         Appearance.colors.colOnPrimary
    readonly property color trackColor: coverColors ? MediaPalette.track : Appearance.colors.colLayer2Hover
    readonly property color surfaceColor: coverColors ? Qt.tint(Appearance.colors.colLayer0,
                                                                Appearance.applyAlpha(accentColor, 0.12)) :
                                                        Appearance.colors.colLayer0

    function updatePalette() {
        if (root.paletteArtUrl)
            MediaPalette.extract(root.paletteArtUrl, root.themePrimary);
    }

    function seek(position) {
        if (root.canSeek && Number.isFinite(position))
            MediaManager.active.position = Math.max(0, Math.min(1, position)) * MediaManager.active.length;
    }

    onPaletteArtUrlChanged: updatePalette()
    onThemePrimaryChanged: updatePalette()
    Component.onCompleted: updatePalette()

    // 对播放器列表进行重排序，让当前播放器排在第一位
    property var sortedPlayerList: {
        let activeP = MediaManager.active;
        let allP = MediaManager.list;

        if (!activeP || allP.length <= 1)
            return allP;

        // 创建副本并排序：将 active 移到最前
        let sorted = allP.slice();
        sorted.sort((a, b) => {
            if (a === activeP)
                return -1;
            if (b === activeP)
                return 1;
            return 0;
        });
        return sorted;
    }

    Component {
        id: sineProgress
        WaveProgressBar {
            progress: root.progress
            waveColor: root.accentColor
            trackColor: root.trackColor
            isPlaying: root.isPlaying
            waveAmplitude: 6
            waveFrequency: 0.05
            progressGap: 10
            seekMargin: 0
            onSeekRequested: position => root.seek(position)
        }
    }

    Component {
        id: materialProgress
        MaterialWaveProgressBar {
            progress: root.progress
            waveColor: root.accentColor
            trackColor: root.trackColor
            trackOpacity: 1
            isPlaying: root.isPlaying
            seekMargin: 0
            onSeekRequested: position => root.seek(position)
        }
    }

    // ==========================================
    // 全局布局
    // ==========================================
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 4
        anchors.bottomMargin: 12
        spacing: 24

        Item {
            Layout.preferredWidth: root.caelestiaCover || root.backgroundCover ? 180 : 120
            Layout.preferredHeight: root.caelestiaCover || root.backgroundCover ? 180 : 120
            Layout.alignment: root.caelestiaCover || root.backgroundCover ? Qt.AlignVCenter : Qt.AlignTop

            Loader {
                anchors.fill: parent
                active: !root.backgroundCover && root.visible
                sourceComponent: MediaCover {
                    artUrl: root.artUrl
                    playing: root.isPlaying
                    active: root.isActive
                    caelestia: root.caelestiaCover
                    accentColor: root.accentColor
                }
            }
        }

        // 右侧：信息与控制区
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            // 标题行（右侧留出空间给药丸）
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: root.title
                        color: Appearance.colors.colOnSurface
                        font.bold: true
                        font.pixelSize: 20
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Text {
                        text: root.artist
                        color: Appearance.colors.colOnSurfaceVariant
                        font.pixelSize: 14
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }

                // 为药丸预留空间
                Item {
                    Layout.preferredWidth: root.caelestiaCover || root.backgroundCover ? Math.max(80,
                                                                                                  pillRect.width
                                                                                                  + 8) : 80
                    Layout.fillHeight: true
                }
            }

            Item {
                Layout.fillHeight: true
            }

            Loader {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                active: root.visible
                enabled: root.canSeek
                sourceComponent: PersonalizationConfig.keystoneMediaProgressStyle === "material"
                                 ? materialProgress : sineProgress
            }

            // 底部控制按钮区（填满右侧列宽度，与标题行对齐）
            MediaControlBar {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 24
                isPlaying: root.isPlaying
                shuffleActive: MediaManager.active && MediaManager.active.shuffle
                shuffleEnabled: MediaManager.active && MediaManager.active.shuffleSupported
                previousEnabled: MediaManager.active
                playPauseEnabled: MediaManager.active
                nextEnabled: MediaManager.active
                loopEnabled: MediaManager.active && MediaManager.active.loopSupported
                loopMode: !MediaManager.active || MediaManager.active.loopState === MprisLoopState.None ? 0 : (
                                                                                                              MediaManager.active.loopState
                                                                                                              === MprisLoopState.Track
                                                                                                              ? 2 : 1)
                activeColor: root.accentColor
                inactiveColor: Appearance.colors.colOnSurface
                playingBg: root.accentColor
                playingFg: root.onAccentColor
                pausedBg: root.coverColors ? root.trackColor : Appearance.colors.colSecondaryContainer
                pausedFg: root.coverColors ? root.accentColor : Appearance.colors.colOnSecondaryContainer
                morphEnabled: true

                onShuffleClicked: if (MediaManager.active && MediaManager.active.shuffleSupported)
                                      MediaManager.active.shuffle = !MediaManager.active.shuffle
                onPreviousClicked: if (MediaManager.active)
                                       MediaManager.active.previous()
                onPlayPauseClicked: if (MediaManager.active)
                                        MediaManager.active.togglePlaying()
                onNextClicked: if (MediaManager.active)
                                   MediaManager.active.next()
                onLoopClicked: {
                    if (!MediaManager.active || !MediaManager.active.loopSupported)
                        return;

                    if (MediaManager.active.loopState === MprisLoopState.None)
                        MediaManager.active.loopState = MprisLoopState.Playlist;
                    else if (MediaManager.active.loopState === MprisLoopState.Playlist)
                        MediaManager.active.loopState = MprisLoopState.Track;
                    else
                        MediaManager.active.loopState = MprisLoopState.None;
                }
            }
        }
    }

    Rectangle {
        id: pillRect

        anchors.top: root.top
        anchors.right: root.right
        anchors.topMargin: 4
        anchors.rightMargin: 16
        z: 999

        property bool menuExpanded: false

        color: root.coverColors ? root.accentColor : Appearance.colors.colTertiary
        width: menuExpanded ? 110 : pillText.width + 24
        height: menuExpanded ? (30 * MediaManager.list.length + 12) : 26
        radius: menuExpanded ? 12 : 13
        scale: (!menuExpanded && pillMa.pressed) ? 0.94 : (!menuExpanded && pillMa.containsMouse ? 1.08 : 1.0)

        Behavior on width {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutQuint
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutQuint
            }
        }
        Behavior on radius {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutQuint
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }

        Text {
            id: pillText
            anchors.centerIn: parent
            text: MediaManager.getIdentity(MediaManager.active)
            color: root.coverColors ? root.onAccentColor : Appearance.colors.colOnTertiary
            font.pixelSize: 11
            font.weight: Font.DemiBold
            opacity: pillRect.menuExpanded ? 0.0 : 1.0
            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                }
            }
        }

        MouseArea {
            id: pillMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            visible: !pillRect.menuExpanded
            onClicked: {
                if (MediaManager.list.length > 1)
                    pillRect.menuExpanded = true;
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 0
            visible: pillRect.menuExpanded
            opacity: pillRect.menuExpanded ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.InQuad
                }
            }

            Repeater {
                model: root.sortedPlayerList

                delegate: Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    radius: 8
                    color: itemMa.containsMouse ? Qt.rgba(0, 0, 0, 0.08) : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: 100
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            text: MediaManager.getIdentity(modelData)
                            color: root.coverColors ? root.onAccentColor : Appearance.colors.colOnTertiary
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: itemMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            MediaManager.manualActive = modelData;
                            pillRect.menuExpanded = false;
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: pillRect.z - 1
        visible: pillRect.menuExpanded
        onClicked: pillRect.menuExpanded = false
    }
}
