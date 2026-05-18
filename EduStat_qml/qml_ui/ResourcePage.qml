import QtQuick
import QtQuick.Layouts
import FluentUI

// 课程资源 Course Resources Page
Item {
    RowLayout {
        anchors.fill: parent
        spacing: 24

        // Left: Upload area
        FluFrame {
            Layout.preferredWidth: 400
            Layout.fillHeight: true
            radius: 12

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 16

                FluText {
                    text: "上传资源"
                    font.pixelSize: 16
                    font.bold: true
                }

                FluText {
                    text: "上传课件、视频、文档等教学资源到当前课程"
                    font.pixelSize: 11
                    textColor: "#8ea1ad"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                FluDivider { Layout.fillWidth: true }

                // Drag / drop zone
                FluFrame {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 160
                    radius: 12
                    color: FluTheme.dark ? Qt.rgba(25/255, 29/255, 35/255, 1) : "#f5f5f5"

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 10
                        FluText {
                            text: "📁"
                            font.pixelSize: 36
                            Layout.alignment: Qt.AlignHCenter
                        }
                        FluText {
                            text: "拖拽文件到此处上传"
                            font.pixelSize: 13
                            textColor: "#8ea1ad"
                            Layout.alignment: Qt.AlignHCenter
                        }
                        FluText {
                            text: "支持 PDF / Word / PPT / MP4 / ZIP"
                            font.pixelSize: 10
                            textColor: "#53636d"
                            Layout.alignment: Qt.AlignHCenter
                        }
                        FluButton {
                            text: "选择文件"
                            font.pixelSize: 11
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }

                FluText {
                    text: "资源信息"
                    font.pixelSize: 12
                    font.bold: true
                    textColor: "#b3c0c8"
                }

                FluTextBox {
                    Layout.fillWidth: true
                    placeholderText: "资源名称"
                }
                FluTextBox {
                    Layout.fillWidth: true
                    placeholderText: "资源描述（选填）"
                    Layout.preferredHeight: 60
                }
                FluComboBox {
                    Layout.fillWidth: true
                    model: ["课件", "视频", "文档", "习题", "其他"]
                    currentIndex: 0
                }

                FluFilledButton {
                    Layout.fillWidth: true
                    text: "上传到当前课程"
                    font.pixelSize: 13
                }
            }
        }

        // Right: Resource list
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            RowLayout {
                FluText {
                    text: "资源库"
                    font.pixelSize: 18
                    font.bold: true
                }
                Item { Layout.fillWidth: true }
                FluTextBox {
                    Layout.preferredWidth: 220
                    placeholderText: "搜索资源..."
                }
                FluComboBox {
                    Layout.preferredWidth: 100
                    model: ["全部", "课件", "视频", "文档", "习题"]
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
                                text: "资源名称"
                                font.pixelSize: 11
                                font.bold: true
                            }
                            FluText {
                                Layout.preferredWidth: 80
                                text: "类型"
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
                                Layout.preferredWidth: 100
                                text: "上传时间"
                                font.pixelSize: 11
                                font.bold: true
                            }
                            FluText {
                                Layout.preferredWidth: 120
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
                        model: [
                            { name: "第一章课件.pptx", type: "课件", size: "12.5 MB", time: "2024-03-10" },
                            { name: "实验指导视频.mp4", type: "视频", size: "256 MB", time: "2024-03-08" },
                            { name: "课后习题集.pdf", type: "文档", size: "3.2 MB", time: "2024-03-05" },
                            { name: "模拟试题及答案.docx", type: "文档", size: "1.8 MB", time: "2024-03-01" },
                            { name: "第二章讲义.pdf", type: "课件", size: "8.7 MB", time: "2024-02-28" },
                            { name: "课堂录像-第三章.mp4", type: "视频", size: "512 MB", time: "2024-02-25" },
                            { name: "复习提纲.zip", type: "其他", size: "4.1 MB", time: "2024-02-20" }
                        ]

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
                                    text: modelData.name
                                    font.pixelSize: 11
                                }
                                FluText {
                                    Layout.preferredWidth: 80
                                    text: modelData.type
                                    font.pixelSize: 11
                                    textColor: "#0f766e"
                                }
                                FluText {
                                    Layout.preferredWidth: 80
                                    text: modelData.size
                                    font.pixelSize: 11
                                    textColor: "#8ea1ad"
                                }
                                FluText {
                                    Layout.preferredWidth: 100
                                    text: modelData.time
                                    font.pixelSize: 11
                                    textColor: "#8ea1ad"
                                }
                                FluButton {
                                    Layout.preferredWidth: 50
                                    text: "下载"
                                    font.pixelSize: 10
                                }
                                FluButton {
                                    Layout.preferredWidth: 50
                                    text: "删除"
                                    font.pixelSize: 10
                                    textColor: "#ef4444"
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
