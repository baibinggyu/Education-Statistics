import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import FluentUI

// 组队 Team Up Page
Item {
    RowLayout {
        anchors.fill: parent
        spacing: 24

        // Left: Control panel
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
                    text: "当前组队"
                    font.pixelSize: 16
                    font.bold: true
                }

                FluText {
                    text: "5 组，共 15 人\n规则：随机分组 / 每组 3 人"
                    font.pixelSize: 11
                    textColor: "#8ea1ad"
                }

                FluDivider { Layout.fillWidth: true }

                FluText {
                    text: "随机组队规则"
                    font.pixelSize: 12
                    font.bold: true
                    textColor: "#b3c0c8"
                }

                RowLayout {
                    FluText {
                        text: "每组人数"
                        font.pixelSize: 11
                        Layout.preferredWidth: 70
                    }
                    FluSpinBox {
                        Layout.fillWidth: true
                        from: 2
                        to: 8
                        value: 3
                    }
                }

                RowLayout {
                    FluText {
                        text: "分组模式"
                        font.pixelSize: 11
                        Layout.preferredWidth: 70
                    }
                    FluComboBox {
                        Layout.fillWidth: true
                        model: ["随机分组", "强配弱平衡"]
                    }
                }

                RowLayout {
                    FluToggleSwitch { checked: true }
                    FluText {
                        text: "参考当前成绩进行分组"
                        font.pixelSize: 11
                    }
                }

                FluText {
                    text: "强配弱平衡：将高分与低分学生搭配组队，确保每组整体水平均衡"
                    font.pixelSize: 10
                    textColor: "#6a7882"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                RowLayout {
                    spacing: 10
                    FluFilledButton {
                        text: "生成组队"
                        Layout.fillWidth: true
                        font.pixelSize: 12
                    }
                    FluButton {
                        text: "保存到历史"
                        Layout.fillWidth: true
                        font.pixelSize: 12
                    }
                }

                FluDivider { Layout.fillWidth: true }

                FluText {
                    text: "历史组队"
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
                        spacing: 4
                        model: [
                            "第1组 - 3人 - 2024-03-15",
                            "第2组 - 3人 - 2024-03-15",
                            "第3组 - 4人 - 2024-03-08"
                        ]
                        delegate: FluText {
                            required property string modelData
                            width: ListView.view.width
                            text: modelData
                            font.pixelSize: 11
                            textColor: "#b3c0c8"
                            padding: 6
                        }
                    }
                }
            }
        }

        // Right: Team cards area
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            FluText {
                text: "当前队组"
                font.pixelSize: 18
                font.bold: true
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.vertical: FluScrollBar {}

                FluStaggeredLayout {
                    width: parent.width
                    itemWidth: 280
                    rowSpacing: 14
                    colSpacing: 14
                    model: [
                            {
                                name: "第1组",
                                count: 3,
                                members: [
                                    { n: "张三", r: "组长" },
                                    { n: "李四", r: "成员" },
                                    { n: "王五", r: "成员" }
                                ]
                            },
                            {
                                name: "第2组",
                                count: 3,
                                members: [
                                    { n: "赵同学", r: "组长" },
                                    { n: "钱同学", r: "成员" },
                                    { n: "孙同学", r: "成员" }
                                ]
                            },
                            {
                                name: "第3组",
                                count: 3,
                                members: [
                                    { n: "周同学", r: "组长" },
                                    { n: "吴同学", r: "成员" },
                                    { n: "郑同学", r: "成员" }
                                ]
                            },
                            {
                                name: "第4组",
                                count: 3,
                                members: [
                                    { n: "陈同学", r: "组长" },
                                    { n: "刘同学", r: "成员" },
                                    { n: "黄同学", r: "成员" }
                                ]
                            },
                            {
                                name: "第5组",
                                count: 3,
                                members: [
                                    { n: "杨同学", r: "组长" },
                                    { n: "朱同学", r: "成员" },
                                    { n: "马同学", r: "成员" }
                                ]
                            }
                        ]

                        delegate: FluFrame {
                            required property var modelData
                            width: 280
                            height: 220
                            radius: 16

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 10

                                RowLayout {
                                    FluText {
                                        text: modelData.name
                                        font.pixelSize: 14
                                        font.bold: true
                                    }
                                    Item { Layout.fillWidth: true }
                                    FluFrame {
                                        radius: 8
                                        color: "#0f766e"
                                        padding: 6
                                        FluText {
                                            text: modelData.count + "人"
                                            font.pixelSize: 10
                                            textColor: "#ffffff"
                                        }
                                    }
                                }

                                FluText {
                                    text: "当前共 " + modelData.count + " 名成员"
                                    font.pixelSize: 10
                                    textColor: "#8fa1ab"
                                }

                                FluFrame {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 10
                                    color: Qt.rgba(21/255, 25/255, 31/255, 1)

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 6

                                        Repeater {
                                            model: modelData.members
                                            delegate: RowLayout {
                                                required property var modelData
                                                Rectangle {
                                                    width: 24; height: 24
                                                    radius: 12
                                                    color: "#0f766e"
                                                    FluText {
                                                        anchors.centerIn: parent
                                                        text: modelData.n.charAt(0)
                                                        font.pixelSize: 11
                                                        textColor: "#ffffff"
                                                    }
                                                }
                                                FluText {
                                                    text: modelData.n
                                                    font.pixelSize: 11
                                                }
                                                Item { Layout.fillWidth: true }
                                                FluText {
                                                    text: modelData.r
                                                    font.pixelSize: 9
                                                    textColor: "#6a7882"
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
    }
}
