import QtQuick
import QtQuick.Layouts
import FluentUI

// 增加学科 Add Subject Page
Item {
    RowLayout {
        anchors.fill: parent
        spacing: 24

        // Left: Unit table area (ratio 9)
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            // Header
            RowLayout {
                Layout.fillWidth: true
                FluText {
                    text: "增加学科"
                    font.pixelSize: 18
                    font.bold: true
                }
                Item { Layout.fillWidth: true }
                FluButton {
                    text: "← 返回"
                    font.pixelSize: 12
                }
            }

            // Unit table
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
                        height: 42
                        color: Qt.rgba(0,0,0,0.08)
                        radius: 8

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 0

                            Repeater {
                                model: ["单元", "权重", "满分"]
                                delegate: FluText {
                                    Layout.fillWidth: true
                                    text: modelData
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                            }
                        }
                    }

                    // Table rows
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: [
                            { name: "第一章", weight: "0.25", score: "100" },
                            { name: "第二章", weight: "0.25", score: "100" },
                            { name: "第三章", weight: "0.25", score: "100" },
                            { name: "第四章", weight: "0.25", score: "100" }
                        ]

                        delegate: Rectangle {
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
                                FluTextBox {
                                    Layout.fillWidth: true
                                    text: modelData.weight
                                    font.pixelSize: 11
                                    Layout.margins: 4
                                    Layout.preferredHeight: 30
                                }
                                FluTextBox {
                                    Layout.fillWidth: true
                                    text: modelData.score
                                    font.pixelSize: 11
                                    Layout.margins: 4
                                    Layout.preferredHeight: 30
                                }
                            }
                        }
                    }
                }
            }
        }

        // Right: Side panel (ratio 1)
        FluFrame {
            Layout.preferredWidth: 280
            Layout.minimumWidth: 240
            Layout.fillHeight: true
            radius: 12

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                FluText {
                    text: "基本信息"
                    font.pixelSize: 15
                    font.bold: true
                }

                // Subject ID
                FluText {
                    text: "学科编号"
                    font.pixelSize: 11
                    textColor: "#8ea1ad"
                }
                FluTextBox {
                    Layout.fillWidth: true
                    text: "auto-001"
                    readOnly: true
                }

                // Subject name
                FluText {
                    text: "学科名称"
                    font.pixelSize: 11
                    textColor: "#8ea1ad"
                }
                FluTextBox {
                    Layout.fillWidth: true
                    placeholderText: "请输入学科名称"
                }

                // Total weight
                FluText {
                    text: "权重总和"
                    font.pixelSize: 11
                    textColor: "#8ea1ad"
                }
                FluTextBox {
                    Layout.fillWidth: true
                    text: "1.00"
                    readOnly: true
                }

                FluDivider { Layout.fillWidth: true }

                // Action buttons
                FluFilledButton {
                    Layout.fillWidth: true
                    text: "添加单元行"
                    font.pixelSize: 12
                }
                FluButton {
                    Layout.fillWidth: true
                    text: "删除选中行"
                    font.pixelSize: 12
                }
                FluButton {
                    Layout.fillWidth: true
                    text: "按比例重整权重"
                    font.pixelSize: 12
                }

                Item { Layout.fillHeight: true }

                FluFilledButton {
                    Layout.fillWidth: true
                    text: "完成并退出"
                    font.pixelSize: 12
                }
            }
        }
    }
}
