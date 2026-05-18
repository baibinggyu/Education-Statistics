import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import FluentUI

// 发送消息 Send Message to Students Page
Item {
    RowLayout {
        anchors.fill: parent
        spacing: 20

        // Left: Student list
        FluFrame {
            Layout.preferredWidth: 320
            Layout.fillHeight: true
            radius: 12

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                FluText {
                    text: "选择学生"
                    font.pixelSize: 15
                    font.bold: true
                }

                RowLayout {
                    FluTextBox {
                        Layout.fillWidth: true
                        placeholderText: "搜索学生姓名/学号..."
                    }
                }

                FluComboBox {
                    Layout.fillWidth: true
                    model: ["全部学生", "未读消息", "近期活跃"]
                    currentIndex: 0
                }

                FluDivider { Layout.fillWidth: true }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    ScrollBar.vertical: FluScrollBar {}

                    ColumnLayout {
                        width: parent.width
                        spacing: 4

                        Repeater {
                            model: [
                                { name: "张同学", id: "2021001", unread: 3, selected: false },
                                { name: "李同学", id: "2021002", unread: 0, selected: true },
                                { name: "王同学", id: "2021003", unread: 1, selected: false },
                                { name: "赵同学", id: "2021004", unread: 0, selected: false },
                                { name: "刘同学", id: "2021005", unread: 0, selected: false },
                                { name: "陈同学", id: "2021006", unread: 2, selected: false },
                                { name: "杨同学", id: "2021007", unread: 0, selected: false },
                                { name: "黄同学", id: "2021008", unread: 0, selected: false },
                                { name: "周同学", id: "2021009", unread: 1, selected: false },
                                { name: "吴同学", id: "2021010", unread: 0, selected: false },
                                { name: "孙同学", id: "2021011", unread: 4, selected: false },
                                { name: "郑同学", id: "2021012", unread: 0, selected: false }
                            ]

                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                height: 48
                                radius: 8
                                color: {
                                    if (modelData.selected) return Qt.rgba(15/255, 118/255, 110/255, 0.2)
                                    if (mouseArea.containsMouse) return Qt.rgba(43/255, 50/255, 56/255, 1)
                                    return "transparent"
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 10

                                    Rectangle {
                                        width: 36; height: 36
                                        radius: 18
                                        color: "#0f766e"

                                        FluText {
                                            anchors.centerIn: parent
                                            text: modelData.name.charAt(0)
                                            font.pixelSize: 14
                                            font.bold: true
                                            textColor: "#ffffff"
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        FluText {
                                            text: modelData.name
                                            font.pixelSize: 12
                                        }
                                        FluText {
                                            text: "学号: " + modelData.id
                                            font.pixelSize: 9
                                            textColor: "#8ea1ad"
                                        }
                                    }

                                    Rectangle {
                                        visible: modelData.unread > 0
                                        width: 22; height: 18
                                        radius: 9
                                        color: "#ef4444"

                                        FluText {
                                            anchors.centerIn: parent
                                            text: modelData.unread
                                            font.pixelSize: 10
                                            textColor: "#ffffff"
                                        }
                                    }
                                }

                                MouseArea {
                                    id: mouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                }
                            }
                        }
                    }
                }
            }
        }

        // Right: Message composer
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            FluText {
                text: "发送消息"
                font.pixelSize: 18
                font.bold: true
            }

            // Recipient summary
            FluFrame {
                Layout.fillWidth: true
                radius: 8
                color: FluTheme.dark ? Qt.rgba(25/255, 29/255, 35/255, 1) : "#fafafa"
                padding: 12

                RowLayout {
                    anchors.fill: parent
                    spacing: 8

                    FluText {
                        text: "收件人:"
                        font.pixelSize: 11
                        textColor: "#8ea1ad"
                    }

                    FluFrame {
                        radius: 4
                        color: "#0f766e"
                        padding: 4
                        FluText {
                            text: "李同学 (2021002)"
                            font.pixelSize: 10
                            textColor: "#ffffff"
                        }
                    }

                    FluText {
                        text: "+ 选择更多"
                        font.pixelSize: 10
                        textColor: "#0f766e"
                    }

                    Item { Layout.fillWidth: true }

                    FluText {
                        text: "当前课程: 电子技术基础"
                        font.pixelSize: 10
                        textColor: "#53636d"
                        elide: Text.ElideRight
                        Layout.maximumWidth: 180
                    }
                }
            }

            // Message type
            RowLayout {
                spacing: 12
                FluText {
                    text: "消息类型"
                    font.pixelSize: 12
                    textColor: "#b3c0c8"
                }
                FluComboBox {
                    Layout.preferredWidth: 160
                    model: ["学习提醒", "作业通知", "考试安排", "课堂反馈", "其他"]
                    currentIndex: 0
                }
            }

            // Subject
            FluTextBox {
                Layout.fillWidth: true
                placeholderText: "消息主题（选填）"
            }

            // Content
            FluMultilineTextBox {
                Layout.fillWidth: true
                Layout.fillHeight: true
                placeholderText: "请输入消息内容..."
                wrapMode: Text.WordWrap
            }

            // Quick templates
            FluText {
                text: "快捷模板"
                font.pixelSize: 12
                font.bold: true
                textColor: "#b3c0c8"
            }

            FluFrame {
                Layout.fillWidth: true
                Layout.preferredHeight: 80
                radius: 8
                color: FluTheme.dark ? Qt.rgba(25/255, 29/255, 35/255, 1) : "#fafafa"
                padding: 8

                ScrollView {
                    anchors.fill: parent
                    clip: true
                    ScrollBar.horizontal: FluScrollBar {}

                    RowLayout {
                        height: parent.height
                        spacing: 8
                        Repeater {
                            model: [
                                { label: "作业催交", content: "同学你好，请尽快提交本周作业，截止时间即将到来。" },
                                { label: "课堂提醒", content: "提醒：明天上课请带好教材和实验报告。" },
                                { label: "成绩通知", content: "你的最近一次测验成绩已公布，请查看。" },
                                { label: "答疑邀请", content: "如有疑问，欢迎在课后到办公室找我答疑。" }
                            ]

                            delegate: FluFrame {
                                required property var modelData
                                Layout.preferredWidth: 140
                                Layout.fillHeight: true
                                radius: 6
                                color: FluTheme.dark ? Qt.rgba(25/255, 29/255, 35/255, 1) : "#fafafa"
                                padding: 10

                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: 4
                                    FluText {
                                        text: modelData.label
                                        font.pixelSize: 11
                                        font.bold: true
                                    }
                                    FluText {
                                        text: modelData.content
                                        font.pixelSize: 9
                                        textColor: "#8ea1ad"
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                        maximumLineCount: 2
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Bottom action row
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                FluToggleSwitch { checked: true }
                FluText {
                    text: "发送系统通知"
                    font.pixelSize: 11
                    textColor: "#8ea1ad"
                }

                Item { Layout.fillWidth: true }

                FluButton {
                    text: "预览"
                    font.pixelSize: 12
                    Layout.preferredWidth: 56
                }

                FluFilledButton {
                    Layout.preferredHeight: 38
                    Layout.preferredWidth: 120
                    text: "发送消息"
                    font.pixelSize: 12
                    font.bold: true
                }
            }

            // Recent sent messages
            FluFrame {
                Layout.fillWidth: true
                Layout.preferredHeight: 140
                radius: 10

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    FluText {
                        text: "最近发送"
                        font.pixelSize: 12
                        font.bold: true
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: [
                            { to: "张同学", content: "请尽快提交第三章实验报告", time: "10:30", type: "作业提醒" },
                            { to: "全班", content: "期末考试时间已公布，请查看课程公告", time: "昨天 14:20", type: "考试安排" },
                            { to: "王同学", content: "你的课后答疑安排在明天下午3点", time: "昨天 09:15", type: "其他" }
                        ]

                        delegate: RowLayout {
                            required property var modelData
                            width: ListView.view.width
                            height: 32
                            spacing: 10

                            FluFrame {
                                radius: 4
                                color: Qt.rgba(15/255, 118/255, 110/255, 0.15)
                                padding: 2
                                FluText {
                                    text: modelData.type
                                    font.pixelSize: 8
                                    textColor: "#0f766e"
                                }
                            }
                            FluText {
                                text: modelData.to
                                font.pixelSize: 11
                                font.bold: true
                            }
                            FluText {
                                Layout.fillWidth: true
                                text: modelData.content
                                font.pixelSize: 10
                                textColor: "#8ea1ad"
                                elide: Text.ElideRight
                            }
                            FluText {
                                text: modelData.time
                                font.pixelSize: 9
                                textColor: "#53636d"
                            }
                        }
                    }
                }
            }
        }
    }
}
