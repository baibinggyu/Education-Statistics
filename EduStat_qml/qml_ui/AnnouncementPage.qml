import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import FluentUI

// 发布公告 Course Announcements Page
Item {
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
                    text: "针对当前课程「电子技术基础」发布教学公告，选课学生将在首页收到通知。"
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
                    Layout.fillWidth: true
                    placeholderText: "请输入公告标题"
                }

                FluText {
                    text: "公告内容"
                    font.pixelSize: 12
                    textColor: "#b3c0c8"
                }
                FluMultilineTextBox {
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
                    Layout.fillWidth: true
                    model: ["课程通知", "作业提醒", "考试安排", "资料更新", "其他"]
                    currentIndex: 0
                }

                RowLayout {
                    FluToggleSwitch { checked: true }
                    FluText {
                        text: "置顶公告"
                        font.pixelSize: 11
                    }
                }

                RowLayout {
                    FluToggleSwitch { checked: true }
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
                        model: [
                            {
                                title: "期末考试时间安排通知",
                                type: "考试安排",
                                content: "本学期电子技术基础期末考试定于第18周周三进行，请同学们提前做好复习准备。考试范围：第一章至第四章。",
                                date: "2024-03-15",
                                pinned: true
                            },
                            {
                                title: "第三章实验报告提交通知",
                                type: "作业提醒",
                                content: "请各位同学于本周五前提交第三章实验报告，逾期将扣除平时成绩。实验报告模板已上传至课程资源。",
                                date: "2024-03-12",
                                pinned: true
                            },
                            {
                                title: "第五章课件已更新",
                                type: "资料更新",
                                content: "第五章课件已上传至课程资源区，请同学们提前下载预习。主要内容包括放大电路的基本原理与分析。",
                                date: "2024-03-08",
                                pinned: false
                            },
                            {
                                title: "课代表推选结果公布",
                                type: "课程通知",
                                content: "经班级投票，决定由张同学担任本学期电子技术基础课代表，负责日常作业收发和师生沟通。",
                                date: "2024-03-01",
                                pinned: false
                            }
                        ]

                        delegate: FluFrame {
                            required property var modelData
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
                                            text: modelData.type
                                            font.pixelSize: 9
                                            textColor: "#8ea1ad"
                                        }
                                    }
                                    Item { Layout.fillWidth: true }
                                    FluText {
                                        text: modelData.date
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
                }
            }
        }
    }
}
