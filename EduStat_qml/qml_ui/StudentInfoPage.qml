import QtQuick
import QtQuick.Layouts
import FluentUI

// 学生信息 Student Info Page
Item {
    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        // Title
        FluText {
            text: "学生信息"
            font.pixelSize: 18
            font.bold: true
        }

        // Toolbar
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            FluFilledButton {
                text: "+ 新增"
                font.pixelSize: 12
            }
            FluButton {
                text: "- 删除选中"
                font.pixelSize: 12
            }
            Item { Layout.preferredWidth: 20 }
            FluTextBox {
                id: searchBox
                Layout.fillWidth: true
                Layout.preferredWidth: 200
                placeholderText: "搜索学生姓名 / 学号..."
            }
            FluButton {
                text: "搜索"
                font.pixelSize: 12
            }
            FluButton {
                text: "导出"
                font.pixelSize: 12
            }
            FluButton {
                text: "导入学生信息"
                font.pixelSize: 12
            }
            FluButton {
                text: "保存"
                font.pixelSize: 12
            }
        }

        // Table
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
                            model: ["学号", "班级", "姓名", "第一章", "第二章", "第三章", "第四章"]
                            delegate: FluText {
                                Layout.fillWidth: true
                                text: modelData
                                font.pixelSize: 11
                                font.bold: true
                                horizontalAlignment: index >= 3 ? Text.AlignRight : Text.AlignLeft
                            }
                        }
                    }
                }

                // Table rows
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: 12

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

                            Repeater {
                                model: [
                                    "202400" + (index + 1),
                                    index < 5 ? "师范一班" : (index < 9 ? "师范二班" : "师范三班"),
                                    ["张同学","李同学","王同学","赵同学","钱同学","孙同学","周同学","吴同学","郑同学","陈同学","刘同学","黄同学"][index],
                                    (70 + Math.floor(Math.random() * 30)).toString(),
                                    (70 + Math.floor(Math.random() * 30)).toString(),
                                    (70 + Math.floor(Math.random() * 30)).toString(),
                                    (70 + Math.floor(Math.random() * 30)).toString()
                                ]
                                delegate: FluText {
                                    Layout.fillWidth: true
                                    text: modelData
                                    font.pixelSize: 11
                                    horizontalAlignment: index >= 3 ? Text.AlignRight : Text.AlignLeft
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
