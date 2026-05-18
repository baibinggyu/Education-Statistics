import QtQuick
import QtQuick.Layouts
import FluentUI

// 点名 Roll Call Page
Item {
    RowLayout {
        anchors.fill: parent
        spacing: 24

        // Left: Control panel
        FluFrame {
            Layout.preferredWidth: 300
            Layout.minimumWidth: 250
            Layout.fillHeight: true
            radius: 12

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                FluText {
                    text: "点名控制台"
                    font.pixelSize: 16
                    font.bold: true
                }

                FluText {
                    text: "随机抽取学生回答问题或进行课堂互动"
                    font.pixelSize: 11
                    textColor: "#8ea1ad"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                FluDivider { Layout.fillWidth: true }

                // Draw settings
                FluText {
                    text: "抽取设置"
                    font.pixelSize: 12
                    font.bold: true
                    textColor: "#b3c0c8"
                }

                // Number of students
                RowLayout {
                    Layout.fillWidth: true
                    FluText {
                        text: "抽取人数"
                        font.pixelSize: 11
                        Layout.preferredWidth: 70
                    }
                    FluSpinBox {
                        id: drawCount
                        Layout.fillWidth: true
                        from: 1
                        to: 15
                        value: 1
                    }
                }

                // Draw mode
                RowLayout {
                    Layout.fillWidth: true
                    FluText {
                        text: "抽取模式"
                        font.pixelSize: 11
                        Layout.preferredWidth: 70
                    }
                    FluComboBox {
                        id: drawMode
                        Layout.fillWidth: true
                        model: ["随机抽取", "尽量不重复", "只抽未点到"]
                    }
                }

                // Show class
                RowLayout {
                    Layout.fillWidth: true
                    FluToggleSwitch {
                        id: showClass
                        checked: true
                    }
                    FluText {
                        text: "结果里显示班级"
                        font.pixelSize: 11
                    }
                }

                FluText {
                    text: "随机抽取：完全随机；尽量不重复：降低近期被点过的概率；只抽未点到：本轮未点名过的学生"
                    font.pixelSize: 10
                    textColor: "#6a7882"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                // Action buttons
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    FluFilledButton {
                        text: "开始点名"
                        Layout.fillWidth: true
                        font.pixelSize: 12
                    }
                    FluButton {
                        text: "重置记录"
                        Layout.fillWidth: true
                        font.pixelSize: 12
                    }
                }

                FluDivider { Layout.fillWidth: true }

                // History
                FluText {
                    text: "本轮历史"
                    font.pixelSize: 12
                    font.bold: true
                    textColor: "#b3c0c8"
                }

                FluFrame {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 8
                    color: Qt.rgba(21/255, 24/255, 29/255, 1)

                    ListView {
                        anchors.fill: parent
                        anchors.margins: 8
                        model: ["张三 - 师范一班", "李四 - 师范二班", "王五 - 师范一班"]
                        delegate: FluText {
                            width: parent.width
                            text: modelData
                            font.pixelSize: 11
                            textColor: "#b3c0c8"
                            padding: 4
                        }
                    }
                }
            }
        }

        // Right: Result area
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            FluText {
                text: "点名结果"
                font.pixelSize: 18
                font.bold: true
            }

            // Summary
            FluText {
                text: "已抽取 3 人 | 模式：随机抽取"
                font.pixelSize: 12
                textColor: "#8ea1ad"
            }

            // Highlight result
            FluFrame {
                Layout.fillWidth: true
                Layout.preferredHeight: 160
                radius: 16
                color: "#0f766e"
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    FluText {
                        text: "本轮主结果"
                        font.pixelSize: 12
                        textColor: Qt.rgba(1,1,1,0.7)
                        Layout.alignment: Qt.AlignHCenter
                    }
                    FluText {
                        text: "张同学"
                        font.pixelSize: 32
                        font.bold: true
                        textColor: "#ffffff"
                        Layout.alignment: Qt.AlignHCenter
                    }
                    FluText {
                        text: "2024001 | 师范一班"
                        font.pixelSize: 13
                        textColor: Qt.rgba(1,1,1,0.7)
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            // Detail list
            FluFrame {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 12

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 8

                    FluText {
                        text: "本次抽取详情"
                        font.pixelSize: 13
                        font.bold: true
                    }

                    Repeater {
                        model: [
                            { name: "张同学", id: "2024001", cls: "师范一班" },
                            { name: "李同学", id: "2024012", cls: "师范二班" },
                            { name: "王同学", id: "2024008", cls: "师范一班" }
                        ]
                        delegate: RowLayout {
                            Layout.fillWidth: true
                            FluText {
                                text: modelData.name
                                font.pixelSize: 12
                                Layout.preferredWidth: 100
                            }
                            FluText {
                                text: modelData.id
                                font.pixelSize: 12
                                textColor: "#8ea1ad"
                                Layout.preferredWidth: 120
                            }
                            FluText {
                                text: modelData.cls
                                font.pixelSize: 12
                                textColor: "#8ea1ad"
                            }
                        }
                    }
                }
            }
        }
    }
}
