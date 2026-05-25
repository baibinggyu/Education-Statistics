import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import FluentUI
import EduStat.Backend 1.0

// 发布公告 Course Announcements Page
Item {
    required property ApiClient requiredApiClient
    required property string requiredCourseUuid

    property var announcementsData: ([])

    Component.onCompleted: {
        if (requiredCourseUuid) requiredApiClient.fetchAnnouncements(requiredCourseUuid)
    }

    onVisibleChanged: {
        if (visible && requiredCourseUuid) requiredApiClient.fetchAnnouncements(requiredCourseUuid)
    }

    onRequiredCourseUuidChanged: {
        if (visible && requiredCourseUuid) requiredApiClient.fetchAnnouncements(requiredCourseUuid)
    }

    Connections {
        target: requiredApiClient
        function onAnnouncementListReset() { announcementsData = [] }
        function onAnnouncementListed(uuid, title, content, annType, pinned, authorName, createdAt) {
            announcementsData.push({
                uuid: uuid, title: title, content: content,
                annType: annType, pinned: pinned,
                authorName: authorName, createdAt: createdAt
            })
            announcementsDataChanged()
        }
        function onAnnouncementPublished(uuid, title) {
            requiredApiClient.fetchAnnouncements(requiredCourseUuid)
        }
        function onAnnouncementPublishError(msg) {
            console.log("Publish announcement error:", msg)
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 24

        // Left: Publish form
        FluFrame {
            Layout.preferredWidth: 420
            Layout.fillHeight: true
            radius: 12

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 16

                FluText {
                    text: "发布公告"
                    font.pixelSize: 16
                    font.bold: true
                }

                FluText {
                    text: "针对当前课程发布教学公告，选课学生将在首页收到通知。"
                    font.pixelSize: 11
                    textColor: "#8ea1ad"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                FluDivider { Layout.fillWidth: true }

                FluText {
                    text: "公告标题"
                    font.pixelSize: 12
                    textColor: "#b3c0c8"
                }
                FluTextBox {
                    id: titleInput
                    Layout.fillWidth: true
                    placeholderText: "请输入公告标题"
                }

                FluText {
                    text: "公告内容"
                    font.pixelSize: 12
                    textColor: "#b3c0c8"
                }
                FluMultilineTextBox {
                    id: contentInput
                    Layout.fillWidth: true
                    Layout.preferredHeight: 200
                    placeholderText: "请输入公告内容..."
                    wrapMode: Text.WordWrap
                }

                FluText {
                    text: "公告类型"
                    font.pixelSize: 12
                    textColor: "#b3c0c8"
                }
                FluComboBox {
                    id: typeCombo
                    Layout.fillWidth: true
                    model: ["课程通知", "作业提醒", "考试安排", "资料更新", "其他"]
                    currentIndex: 0
                }

                RowLayout {
                    FluToggleSwitch { id: pinnedSwitch; checked: false }
                    FluText {
                        text: "置顶公告"
                        font.pixelSize: 11
                    }
                }

                RowLayout {
                    FluToggleSwitch { id: notifySwitch; checked: true }
                    FluText {
                        text: "发送课程消息通知"
                        font.pixelSize: 11
                    }
                }

                Item { Layout.fillHeight: true }

                FluFilledButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    text: "发 布 公 告"
                    font.pixelSize: 14
                    font.bold: true
                    onClicked: {
                        var t = titleInput.text.trim()
                        var c = contentInput.text.trim()
                        if (!t || !c) return
                        requiredApiClient.publishAnnouncement(
                            requiredCourseUuid, t, c,
                            typeCombo.model[typeCombo.currentIndex],
                            pinnedSwitch.checked, notifySwitch.checked)
                        titleInput.text = ""
                        contentInput.text = ""
                    }
                }
            }
        }

        // Right: Announcement list
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            FluText {
                text: "已发布公告"
                font.pixelSize: 18
                font.bold: true
            }

            ScrollView {
                id: announcementScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.vertical: FluScrollBar {}

                ColumnLayout {
                    width: announcementScroll.availableWidth
                    spacing: 10

                    Repeater {
                        model: announcementsData

                        delegate: FluFrame {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            radius: 10
                            padding: 16
                            implicitHeight: contentCol.implicitHeight + 32

                            ColumnLayout {
                                id: contentCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    FluFrame {
                                        visible: modelData.pinned
                                        radius: 4
                                        color: "#0f766e"
                                        padding: 4
                                        FluText {
                                            text: "置顶"
                                            font.pixelSize: 9
                                            textColor: "#ffffff"
                                        }
                                    }
                                    FluFrame {
                                        radius: 4
                                        color: FluTheme.dark ? Qt.rgba(255,255,255,0.1) : Qt.rgba(0,0,0,0.06)
                                        padding: 4
                                        FluText {
                                            text: modelData.annType
                                            font.pixelSize: 9
                                            textColor: "#8ea1ad"
                                        }
                                    }
                                    Item { Layout.fillWidth: true }
                                    FluText {
                                        text: modelData.createdAt ? modelData.createdAt.substring(0, 10) : ""
                                        font.pixelSize: 10
                                        textColor: "#8ea1ad"
                                    }
                                }

                                FluText {
                                    Layout.fillWidth: true
                                    text: modelData.title
                                    font.pixelSize: 14
                                    font.bold: true
                                    wrapMode: Text.WordWrap
                                }

                                FluText {
                                    Layout.fillWidth: true
                                    text: modelData.content
                                    font.pixelSize: 11
                                    textColor: "#8ea1ad"
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }

                    // Empty placeholder — must use Layout.alignment, NOT anchors
                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        visible: announcementsData.length === 0
                        text: "暂无公告"
                        color: "#53636d"
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
