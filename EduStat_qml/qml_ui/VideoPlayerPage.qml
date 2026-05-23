import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import FluentUI
import EduStat.Backend 1.0

// 视频播放 Video Player Page
Item {
    required property ApiClient requiredApiClient
    required property string requiredCourseUuid



    property var videosData: ([])
    property var currentVideo: ({})

    VideoPlayerProxy { id: videoProxy }

    Component.onCompleted: {
        if (requiredCourseUuid) requiredApiClient.fetchCourseVideos(requiredCourseUuid)
    }

    function formatDuration(seconds) {
        if (!seconds || seconds <= 0) return "00:00"
        var m = Math.floor(seconds / 60)
        var s = seconds % 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }

    function selectVideo(video) {
        currentVideo = video
        if (video.uuid) requiredApiClient.fetchVideoDetail(video.uuid)
    }

    function openPlayer() {
        var url = requiredApiClient.serverUrl + "/api/videos/" + currentVideo.uuid + "/stream"
        // Pass token via query param for auth (server reads Authorization header)
        // For streaming via QMediaPlayer, we need to use a direct URL approach
        // Since the existing VideoPlayer::loadfile handles URLs, we pass the stream endpoint
        videoProxy.open(url)
    }

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
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        FluText {
            text: "视频播放"
            font.pixelSize: 18
            font.bold: true
        }

        // Video preview / info area
        FluFrame {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 12

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 2
                spacing: 0

                // Preview area
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#000000"
                    radius: 10

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 16

                        FluText {
                            Layout.alignment: Qt.AlignHCenter
                            text: currentVideo.title || "选择下方视频开始播放"
                            font.pixelSize: currentVideo.title ? 18 : 16
                            textColor: currentVideo.title ? "#ffffff" : "#555555"
                        }

                        FluText {
                            Layout.alignment: Qt.AlignHCenter
                            visible: currentVideo.duration !== undefined
                            text: "时长 " + formatDuration(currentVideo.duration) +
                                  " · " + (currentVideo.fileSize ? (currentVideo.fileSize / 1024 / 1024).toFixed(0) + " MB" : "")
                            font.pixelSize: 12
                            textColor: "#8ea1ad"
                        }

                        FluFilledButton {
                            Layout.alignment: Qt.AlignHCenter
                            visible: currentVideo.uuid !== undefined
                            text: "▶  打开播放器"
                            font.pixelSize: 15
                            font.bold: true
                            Layout.preferredHeight: 48
                            Layout.preferredWidth: 200
                            onClicked: openPlayer()
                        }
                    }
                }
            }
        }

        // Video list
        FluFrame {
            Layout.fillWidth: true
            Layout.preferredHeight: 160
            radius: 10

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    FluText {
                        text: "视频列表"
                        font.pixelSize: 13
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    FluText {
                        text: videosData.length + " 个视频"
                        font.pixelSize: 10
                        textColor: "#8ea1ad"
                    }
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    ScrollBar.vertical: FluScrollBar {}

                    FluStaggeredLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        itemWidth: 190
                        colSpacing: 12
                        rowSpacing: 8
                        Repeater {
                            model: videosData

                            delegate: FluFrame {
                                required property var modelData
                                radius: 8
                                height: 64
                                color: currentVideo.uuid === modelData.uuid
                                    ? Qt.rgba(15/255, 118/255, 110/255, 0.3)
                                    : FluTheme.dark ? Qt.rgba(25/255, 29/255, 35/255, 1) : "#fafafa"
                                padding: 10

                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 8
                                    Rectangle {
                                        Layout.preferredWidth: 40
                                        Layout.preferredHeight: 40
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
                                            text: modelData.title
                                            font.pixelSize: 11
                                            font.bold: true
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }
                                        FluText {
                                            text: formatDuration(modelData.duration) +
                                                  " · " + (modelData.fileSize ? (modelData.fileSize / 1024 / 1024).toFixed(0) + "MB" : "")
                                            font.pixelSize: 9
                                            textColor: "#8ea1ad"
                                        }
                                    }
                                    FluIconButton {
                                        Layout.preferredWidth: 28
                                        Layout.preferredHeight: 28
                                        iconSource: FluentIcons.Play
                                        onClicked: {
                                            selectVideo(modelData)
                                            openPlayer()
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        selectVideo(modelData)
                                        openPlayer()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
