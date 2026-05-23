import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import FluentUI
import EduStat.Backend 1.0

// 课程资源 Course Resources Page
Item {
    required property ApiClient requiredApiClient
    required property string requiredCourseUuid

    property var videoResources: ([])
    property string selectedFilePath: ""
    property string selectedFileName: ""
    property string uploadStatus: ""
    property bool uploading: false
    property bool uploadDone: false
    property int uploadPercent: 0

    Component.onCompleted: {
        if (requiredCourseUuid) requiredApiClient.fetchCourseVideos(requiredCourseUuid)
    }

    Connections {
        target: requiredApiClient
        function onVideoListReset() { videoResources = [] }
        function onVideoListed(uuid, title, duration, fileSize, hasCover, status, createdAt) {
            videoResources.push({uuid: uuid, title: title, duration: duration,
                                 fileSize: fileSize, hasCover: hasCover,
                                 status: status, createdAt: createdAt})
            videoResourcesChanged()
        }
        function onVideoUploadProgress(stage, percent) {
            uploading = true
            uploadDone = false
            uploadPercent = percent >= 0 ? percent : uploadPercent
            if (stage === "compressing")
                uploadStatus = "正在压缩..."
            else if (stage === "uploading")
                uploadStatus = percent >= 0 ? "上传中 " + percent + "%" : "上传中..."
            else if (stage === "done")
                uploadStatus = "上传完成"
        }
        function onVideoUploadFinished(video) {
            uploading = false
            uploadDone = true
            uploadStatus = "上传成功: " + (video.title || "")
            if (requiredCourseUuid) requiredApiClient.fetchCourseVideos(requiredCourseUuid)
        }
        function onVideoUploadError(msg) {
            uploading = false
            uploadDone = false
            uploadStatus = "上传失败: " + msg
        }
        function onVideoDeleted(uuid) {
            // Remove from local list immediately
            var arr = []
            for (var i = 0; i < videoResources.length; i++) {
                if (videoResources[i].uuid !== uuid) arr.push(videoResources[i])
            }
            videoResources = arr
        }
        function onVideoDeleteError(msg) {
            console.log("Video delete error:", msg)
        }
    }

    function formatFileSize(bytes) {
        if (!bytes || bytes <= 0) return "--"
        if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + " KB"
        if (bytes < 1024 * 1024 * 1024) return (bytes / 1024 / 1024).toFixed(1) + " MB"
        return (bytes / 1024 / 1024 / 1024).toFixed(2) + " GB"
    }

    function formatDuration(seconds) {
        if (!seconds || seconds <= 0) return "--"
        var m = Math.floor(seconds / 60)
        var s = seconds % 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }

    FileDialog {
        id: fileDialog
        title: "选择视频文件"
        nameFilters: ["视频文件 (*.mp4 *.avi *.mov *.mkv *.webm *.flv)"]
        onAccepted: {
            selectedFilePath = fileDialog.selectedFile.toString()
            // Remove file:// prefix on Linux
            if (selectedFilePath.startsWith("file://"))
                selectedFilePath = selectedFilePath.substring(7)
            var parts = selectedFilePath.split("/")
            selectedFileName = parts[parts.length - 1]
            // Auto-fill title: strip extension from filename
            var lastDot = selectedFileName.lastIndexOf(".")
            var baseName = lastDot > 0 ? selectedFileName.substring(0, lastDot) : selectedFileName
            resourceNameField.text = baseName
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 24

        // Left: Upload area
        FluFrame {
            Layout.preferredWidth: 380
            Layout.fillHeight: true
            radius: 12

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 14

                FluText {
                    text: "上传资源"
                    font.pixelSize: 16
                    font.bold: true
                }

                FluText {
                    text: "选择本地视频文件，客户端将自动压缩后上传。\n压缩规格：1080p H.264，码率 1Mbps"
                    font.pixelSize: 11
                    textColor: "#8ea1ad"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                // Size limit hint
                FluFrame {
                    Layout.fillWidth: true
                    radius: 6
                    color: Qt.rgba(15/255, 118/255, 110/255, 0.15)
                    padding: 10

                    RowLayout {
                        FluText { text: "ⓘ"; font.pixelSize: 13; textColor: "#0f766e" }
                        FluText {
                            text: "限制：原始文件 ≤ 500MB，压缩后 ≤ 200MB。\n超出限制将被拒绝。"
                            font.pixelSize: 10
                            textColor: "#8ea1ad"
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }
                }

                FluDivider { Layout.fillWidth: true }

                // File selection
                FluText {
                    text: "选择视频文件"
                    font.pixelSize: 12
                    font.bold: true
                    textColor: "#b3c0c8"
                }

                // Drop zone + file info
                FluFrame {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 120
                    radius: 10
                    color: FluTheme.dark ? Qt.rgba(25/255, 29/255, 35/255, 1) : "#f5f5f5"

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        FluText {
                            text: selectedFileName ? selectedFileName : "未选择文件"
                            font.pixelSize: 12
                            textColor: selectedFileName ? "#d7e1e8" : "#53636d"
                            elide: Text.ElideRight
                            Layout.maximumWidth: 320
                        }

                        FluText {
                            visible: selectedFileName !== ""
                            text: "支持 MP4 / AVI / MOV / MKV / WebM / FLV"
                            font.pixelSize: 10
                            textColor: "#53636d"
                        }
                    }
                }

                FluFilledButton {
                    Layout.fillWidth: true
                    text: "选择文件"
                    font.pixelSize: 12
                    onClicked: fileDialog.open()
                }

                // Resource name
                FluText {
                    text: "资源名称"
                    font.pixelSize: 12
                    textColor: "#b3c0c8"
                }
                FluTextBox {
                    id: resourceNameField
                    Layout.fillWidth: true
                    placeholderText: "输入视频标题（可选，默认用文件名）"
                }

                // Upload button + progress
                FluText {
                    visible: uploadStatus !== ""
                    text: uploadStatus
                    font.pixelSize: 11
                    textColor: uploadStatus.includes("失败") ? "#ef4444"
                              : uploadStatus.includes("成功") ? "#22c55e"
                              : "#8ea1ad"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                FluFilledButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    text: uploadDone ? "上传完成 ✓ — 点此继续上传" :
                          uploading ? uploadStatus : "上传到当前课程"
                    font.pixelSize: 13
                    font.bold: true
                    enabled: selectedFilePath !== "" || uploadDone
                    onClicked: {
                        if (uploadDone) {
                            // 重置表单，准备下一次上传
                            uploadDone = false
                            uploadStatus = ""
                            selectedFilePath = ""
                            selectedFileName = ""
                            resourceNameField.text = ""
                            return
                        }
                        var title = resourceNameField.text.trim()
                        if (!title) title = selectedFileName
                        if (!title) title = "未命名视频"
                        uploadStatus = "正在压缩..."
                        uploading = true
                        requiredApiClient.uploadVideoFile(requiredCourseUuid, title, selectedFilePath)
                    }
                }
            }
        }

        // Right: Resource list
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            RowLayout {
                FluText {
                    text: "资源库"
                    font.pixelSize: 18
                    font.bold: true
                }
                Item { Layout.fillWidth: true }
                FluText {
                    text: videoResources.length + " 个视频"
                    font.pixelSize: 11
                    textColor: "#8ea1ad"
                }
                FluButton {
                    text: "刷新"
                    font.pixelSize: 11
                    onClicked: {
                        if (requiredCourseUuid) requiredApiClient.fetchCourseVideos(requiredCourseUuid)
                    }
                }
            }

            FluFrame {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 10

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 2
                    spacing: 0

                    // Table header
                    Rectangle {
                        Layout.fillWidth: true
                        height: 40
                        color: Qt.rgba(0,0,0,0.08)
                        radius: 8

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 0

                            FluText {
                                Layout.fillWidth: true
                                text: "视频名称"
                                font.pixelSize: 11
                                font.bold: true
                            }
                            FluText {
                                Layout.preferredWidth: 70
                                text: "时长"
                                font.pixelSize: 11
                                font.bold: true
                            }
                            FluText {
                                Layout.preferredWidth: 80
                                text: "大小"
                                font.pixelSize: 11
                                font.bold: true
                            }
                            FluText {
                                Layout.preferredWidth: 90
                                text: "状态"
                                font.pixelSize: 11
                                font.bold: true
                            }
                            FluText {
                                Layout.preferredWidth: 60
                                text: "操作"
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }
                    }

                    // Table rows
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: videoResources

                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: ListView.view.width
                            height: 40
                            color: index % 2 === 0 ? "transparent" : Qt.rgba(0,0,0,0.04)
                            radius: 4

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 0

                                FluText {
                                    Layout.fillWidth: true
                                    text: modelData.title
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                                FluText {
                                    Layout.preferredWidth: 70
                                    text: formatDuration(modelData.duration)
                                    font.pixelSize: 11
                                    textColor: "#8ea1ad"
                                }
                                FluText {
                                    Layout.preferredWidth: 80
                                    text: formatFileSize(modelData.fileSize)
                                    font.pixelSize: 11
                                    textColor: "#8ea1ad"
                                }
                                FluText {
                                    Layout.preferredWidth: 90
                                    text: modelData.status === "normal" ? "正常"
                                          : modelData.status === "processing" ? "处理中"
                                          : modelData.status || "--"
                                    font.pixelSize: 11
                                    textColor: modelData.status === "normal" ? "#22c55e" : "#8ea1ad"
                                }
                                FluButton {
                                    Layout.preferredWidth: 50
                                    text: "删除"
                                    font.pixelSize: 10
                                    textColor: "#ef4444"
                                    onClicked: {
                                        if (modelData.uuid) requiredApiClient.deleteVideo(modelData.uuid)
                                    }
                                }
                            }
                        }
                    }

                    // Empty state
                    FluText {
                        visible: videoResources.length === 0
                        Layout.alignment: Qt.AlignCenter
                        text: "该课程暂无视频资源，请上传第一个视频"
                        font.pixelSize: 13
                        textColor: "#53636d"
                    }
                }
            }
        }
    }
}
