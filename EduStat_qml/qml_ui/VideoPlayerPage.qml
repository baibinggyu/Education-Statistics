import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtMultimedia
import FluentUI
import EduStat.Backend 1.0

// 视频播放 Video Player Page
Item {
    id: videoPlayerRoot
    required property ApiClient requiredApiClient
    required property string requiredCourseUuid

    property var videosData: ([])
    property var currentVideo: ({})
    property bool playing: false
    property bool fullscreen: false  // 视频最大化（隐藏左侧列表）
    property double playbackSpeed: 1.0
    property bool seeking: false
    property bool showControls: true

    // Available playback speeds
    property var speedsList: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    Component.onCompleted: {
        if (requiredCourseUuid) requiredApiClient.fetchCourseVideos(requiredCourseUuid)
    }

    onRequiredCourseUuidChanged: {
        if (visible && requiredCourseUuid) requiredApiClient.fetchCourseVideos(requiredCourseUuid)
    }

    onVisibleChanged: {
        if (visible && requiredCourseUuid) requiredApiClient.fetchCourseVideos(requiredCourseUuid)
    }

    // ---- helpers ----
    function formatDuration(totalSec) {
        // Always takes seconds (API duration or ms/1000 from MediaPlayer)
        if (!totalSec || totalSec <= 0) return "00:00"
        var sec = Math.floor(totalSec)
        var h = Math.floor(sec / 3600)
        var m = Math.floor((sec % 3600) / 60)
        var s = sec % 60
        var pad = function(n) { return n < 10 ? "0" + n : "" + n }
        if (h > 0)
            return pad(h) + ":" + pad(m) + ":" + pad(s)
        return pad(m) + ":" + pad(s)
    }

    function formatFileSize(bytes) {
        if (!bytes || bytes <= 0) return ""
        if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(0) + " KB"
        if (bytes < 1024 * 1024 * 1024) return (bytes / 1024 / 1024).toFixed(0) + " MB"
        return (bytes / 1024 / 1024 / 1024).toFixed(1) + " GB"
    }

    function streamUrl(videoUuid) {
        return requiredApiClient.serverUrl + "/api/videos/" + videoUuid
               + "/stream?token=" + encodeURIComponent(requiredApiClient.token)
    }

    function selectVideo(video) {
        currentVideo = video
        if (video.uuid) requiredApiClient.fetchVideoDetail(video.uuid)
    }

    function openPlayer() {
        if (!currentVideo.uuid) return
        playing = true
        showControls = true
        mediaPlayer.stop()
        mediaPlayer.source = streamUrl(currentVideo.uuid)
        mediaPlayer.playbackRate = playbackSpeed
        mediaPlayer.play()
    }

    function closePlayer() {
        playing = false
        mediaPlayer.stop()
        mediaPlayer.source = ""
        if (fullscreen) toggleFullscreen()
    }

    function toggleFullscreen() {
        fullscreen = !fullscreen
    }

    function seekTo(frac) {
        if (mediaPlayer.seekable)
            mediaPlayer.position = frac * mediaPlayer.duration
    }

    function cycleSpeed() {
        var idx = speedsList.indexOf(playbackSpeed)
        idx = (idx + 1) % speedsList.length
        playbackSpeed = speedsList[idx]
        mediaPlayer.playbackRate = playbackSpeed
    }

    // ---- auto-hide controls ----
    Timer {
        id: controlsTimer
        interval: 3000
        repeat: false
        onTriggered: { if (playing) showControls = false }
    }

    function pokeControls() {
        showControls = true
        controlsTimer.restart()
    }

    // ---- Connections ----
    Connections {
        target: requiredApiClient
        function onVideoListReset() { videosData = [] }
        function onVideoListed(uuid, title, duration, fileSize, hasCover, status, createdAt) {
            videosData.push({uuid: uuid, title: title, duration: duration,
                             fileSize: fileSize, hasCover: hasCover,
                             status: status, createdAt: createdAt})
            videosDataChanged()
        }
        function onVideoDetailFetched(detail) {
            currentVideo = Object.assign(currentVideo, detail)
        }
        function onVideoUploadFinished(video) {
            requiredApiClient.fetchCourseVideos(requiredCourseUuid)
        }
        function onVideoUploadError(msg) {
            console.log("Upload error:", msg)
        }
    }

    // ---- Video upload dialog ----
    FileDialog {
        id: uploadFileDialog
        title: "选择视频文件"
        nameFilters: ["视频文件 (*.mp4 *.mkv *.webm *.mov *.avi)", "所有文件 (*)"]
        fileMode: FileDialog.OpenFile
        onAccepted: {
            var path = uploadFileDialog.selectedFile.toString()
            if (path.startsWith("file://")) path = path.substring(7)
            var fileName = path.split("/").pop().split(".").slice(0, -1).join(".")
            requiredApiClient.uploadVideoFile(requiredCourseUuid, fileName, path, false)
        }
    }

    // ---- MediaPlayer ----
    MediaPlayer {
        id: mediaPlayer
        videoOutput: videoOut
        audioOutput: AudioOutput { id: audioOut; volume: sliderVolume.value / 100 }
        playbackRate: playbackSpeed
        onErrorOccurred: function(error, errorMsg) {
            console.log("MediaPlayer error:", error, errorMsg)
            videoPlayerRoot.playing = false
        }
        onPlaybackStateChanged: {
            if (playbackState === MediaPlayer.StoppedState && playing) {
                playing = false
            }
        }
        onPositionChanged: {
            if (!seeking && duration > 0)
                progressSlider.value = position / duration
        }
    }

    // ---- Main layout: left sidebar + right player ----
    RowLayout {
        anchors.fill: parent
        spacing: fullscreen ? 0 : 12

        // ============================================================
        // Left sidebar — video list (hidden when fullscreen)
        // ============================================================
        FluFrame {
            Layout.preferredWidth: fullscreen ? 0 : 220
            Layout.fillHeight: true
            radius: 10
            visible: !fullscreen

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    FluText {
                        text: "视频列表"
                        font.pixelSize: 13
                        font.bold: true
                    }
                    FluText {
                        text: videosData.length + " 个"
                        font.pixelSize: 9
                        textColor: "#8ea1ad"
                    }
                    Item { Layout.fillWidth: true }
                    FluButton {
                        text: "+"
                        font.pixelSize: 12
                        font.bold: true
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        onClicked: uploadFileDialog.open()
                    }
                }

                // Video list
                ListView {
                    id: videoListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 6
                    model: videosData

                    delegate: FluFrame {
                        required property var modelData
                        required property int index
                        width: videoListView.width - 2
                        height: 62
                        radius: 8
                        color: currentVideo.uuid === modelData.uuid
                            ? Qt.rgba(15/255, 118/255, 110/255, 0.25)
                            : FluTheme.dark ? Qt.rgba(25/255, 29/255, 35/255, 1) : "#fafafa"

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                selectVideo(modelData)
                                openPlayer()
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            Rectangle {
                                Layout.preferredWidth: 56
                                Layout.preferredHeight: 38
                                radius: 4
                                color: "#0f766e"
                                FluText {
                                    anchors.centerIn: parent
                                    text: "▶"
                                    font.pixelSize: 16
                                    textColor: "#ffffff"
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                FluText {
                                    Layout.fillWidth: true
                                    text: modelData.title
                                    font.pixelSize: 11
                                    font.bold: true
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }
                                FluText {
                                    text: formatDuration(modelData.duration) +
                                          (modelData.fileSize ? " · " + formatFileSize(modelData.fileSize) : "")
                                    font.pixelSize: 9
                                    textColor: "#8ea1ad"
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    Label {
                        anchors.centerIn: parent
                        visible: videosData.length === 0
                        text: "暂无视频"
                        color: "#53636d"
                        font.pixelSize: 12
                    }
                }
            }
        }

        // ============================================================
        // Right side — video player and controls
        // ============================================================
        FluFrame {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 12

            Rectangle {
                id: playerContainer
                anchors.fill: parent
                anchors.margins: 2
                color: "#000000"
                radius: 10

                VideoOutput {
                    id: videoOut
                    anchors.fill: parent
                    visible: playing && mediaPlayer.hasVideo
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: playing
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (mediaPlayer.playbackState === MediaPlayer.PlayingState)
                            mediaPlayer.pause()
                        else
                            mediaPlayer.play()
                        pokeControls()
                    }
                    onPositionChanged: pokeControls()
                }

                // ---- Placeholder when no video playing ----
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 16
                    visible: !playing

                    Rectangle {
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 80
                        radius: 40
                        color: Qt.rgba(15/255, 118/255, 110/255, 0.2)
                        Layout.alignment: Qt.AlignHCenter
                        FluText {
                            anchors.centerIn: parent
                            text: "▶"
                            font.pixelSize: 32
                            textColor: "#0f766e"
                        }
                    }
                    FluText {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.maximumWidth: 400
                        text: currentVideo.title || "选择视频开始播放"
                        font.pixelSize: currentVideo.title ? 18 : 15
                        textColor: currentVideo.title ? "#edf6f4" : "#555555"
                        elide: Text.ElideRight
                    }
                    FluText {
                        Layout.alignment: Qt.AlignHCenter
                        visible: currentVideo.duration !== undefined
                        text: "时长 " + formatDuration(currentVideo.duration) +
                              (currentVideo.fileSize ? " · " + formatFileSize(currentVideo.fileSize) : "")
                        font.pixelSize: 12
                        textColor: "#8ea1ad"
                    }
                    FluFilledButton {
                        Layout.alignment: Qt.AlignHCenter
                        visible: currentVideo.uuid !== undefined
                        text: "▶  开始播放"
                        font.pixelSize: 14
                        font.bold: true
                        Layout.preferredHeight: 44
                        Layout.preferredWidth: 160
                        onClicked: openPlayer()
                    }
                }

                // ---- Playback controls overlay ----
                Item {
                    anchors.fill: parent
                    anchors.margins: 2
                    visible: playing

                    // Bottom gradient
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 90
                        gradient: Gradient {
                            GradientStop { position: 0; color: "transparent" }
                            GradientStop { position: 1; color: Qt.rgba(0,0,0,0.75) }
                        }
                        opacity: showControls ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 300 } }
                    }

                    // Top bar: title + close button
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 40
                        gradient: Gradient {
                            GradientStop { position: 0; color: Qt.rgba(0,0,0,0.7) }
                            GradientStop { position: 1; color: "transparent" }
                        }
                        opacity: showControls ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 300 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            FluText {
                                text: currentVideo.title || ""
                                font.pixelSize: 12
                                textColor: "#edf6f4"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            FluText {
                                text: {
                                    var s = playbackSpeed
                                    return s !== 1.0 ? s.toFixed(2).replace(/0+$/, "").replace(/\.$/, "") + "\u00D7" : ""
                                }
                                font.pixelSize: 11
                                textColor: "#0f766e"
                                font.bold: true
                            }
                            // Close (stop) — was in bottom bar, now in top bar
                            FluButton {
                                text: "\u2715"
                                width: 30; height: 30
                                font.pixelSize: 14
                                onClicked: closePlayer()
                            }
                        }
                    }

                    // Bottom controls bar
                    ColumnLayout {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 12
                        spacing: 2
                        opacity: showControls ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 300 } }

                        // Progress / seek slider (step 0.01 = 两位小数)
                        FluSlider {
                            id: progressSlider
                            Layout.fillWidth: true
                            from: 0; to: 1; value: 0; stepSize: 0.01
                            tooltipEnabled: false
                            onPressedChanged: {
                                seeking = pressed
                                if (!pressed && mediaPlayer.seekable)
                                    mediaPlayer.position = value * mediaPlayer.duration
                            }
                        }

                        // Button row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            // Play / Pause
                            FluButton {
                                id: playPauseBtn
                                text: mediaPlayer.playbackState === MediaPlayer.PlayingState ? "\u23F8" : "\u25B6"
                                font.pixelSize: 16
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 34
                                onClicked: {
                                    if (mediaPlayer.playbackState === MediaPlayer.PlayingState)
                                        mediaPlayer.pause()
                                    else
                                        mediaPlayer.play()
                                }
                            }

                            // Time: HH:MM:SS / HH:MM:SS
                            FluText {
                                text: formatDuration(progressSlider.value * mediaPlayer.duration / 1000) +
                                      " / " + formatDuration(mediaPlayer.duration / 1000)
                                font.pixelSize: 11
                                textColor: "#b3c0c8"
                                Layout.preferredWidth: 160
                            }

                            Item { Layout.fillWidth: true }

                            // Speed cycle button
                            FluButton {
                                text: {
                                    var s = playbackSpeed
                                    return s.toFixed(2).replace(/0+$/, "").replace(/\.$/, "") + "\u00D7"
                                }
                                font.pixelSize: 10
                                Layout.preferredWidth: 44
                                Layout.preferredHeight: 28
                                onClicked: cycleSpeed()
                            }

                            // Volume mute toggle
                            FluButton {
                                text: sliderVolume.value === 0 ? "\uD83D\uDD07" : "\uD83D\uDD0A"
                                font.pixelSize: 14
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 30
                                onClicked: {
                                    sliderVolume.value = sliderVolume.value === 0 ? 80 : 0
                                }
                            }

                            // Volume slider
                            FluSlider {
                                id: sliderVolume
                                Layout.preferredWidth: 80
                                from: 0; to: 100; value: 80
                            }

                            // Fullscreen toggle — was in top bar, now in bottom bar
                            FluButton {
                                text: fullscreen ? "\u2635" : "\u26F6"
                                width: 30; height: 30
                                font.pixelSize: 14
                                onClicked: toggleFullscreen()
                            }
                        }
                    }
                }
            }
        }
    }
}
