import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import FluentUI

// 学科管理 Subject Management Page
Item {
    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        // Header
        RowLayout {
            Layout.fillWidth: true
            FluText {
                text: "学科管理"
                font.pixelSize: 18
                font.bold: true
            }
            Item { Layout.fillWidth: true }
            FluText {
                text: "教师面板"
                font.pixelSize: 12
                textColor: "#8ea1ad"
            }
        }

        // Action bar
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            FluFilledButton {
                text: "+ 新增学科"
                font.pixelSize: 12
            }
            FluButton {
                text: "- 删除学科"
                font.pixelSize: 12
            }
        }

        // Subject cards area
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            FluStaggeredLayout {
                width: parent.width
                itemWidth: 280
                rowSpacing: 16
                colSpacing: 16
                model: [
                        { name: "电子技术基础", units: [
                            { name: "第一章", weight: "25%" },
                            { name: "第二章", weight: "25%" },
                            { name: "第三章", weight: "25%" },
                            { name: "第四章", weight: "25%" }
                        ], selected: true },
                        { name: "学科教学设计", units: [
                            { name: "第一章", weight: "30%" },
                            { name: "第二章", weight: "30%" },
                            { name: "第三章", weight: "40%" }
                        ], selected: false }
                    ]
                    delegate: SubjectCard {
                        subjectName: modelData.name
                        units: modelData.units
                        isSelected: modelData.selected
                    }
            }
        }
    }

    // Subject card component
    component SubjectCard: FluFrame {
        property string subjectName
        property var units: []
        property bool isSelected: false

        width: 280
        height: Math.min(400, 180 + units.length * 32)
        radius: 12
        border.color: isSelected ? Qt.rgba(15/255, 118/255, 110/255, 1) : "transparent"
        border.width: isSelected ? 2 : 0

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 8

            // Title row
            RowLayout {
                Layout.fillWidth: true
                FluText {
                    text: subjectName
                    font.pixelSize: 14
                    font.bold: true
                }
                Item { Layout.fillWidth: true }
                FluButton {
                    text: "X"
                    width: 28; height: 28
                    font.pixelSize: 11
                }
            }

            // Stats checkbox
            RowLayout {
                Layout.fillWidth: true
                FluToggleSwitch { id: statsSwitch; checked: true }
                FluText {
                    text: "统计分数"
                    font.pixelSize: 11
                }
            }

            FluDivider { Layout.fillWidth: true }

            // Unit table header
            RowLayout {
                Layout.fillWidth: true
                FluText {
                    text: "单元"
                    font.pixelSize: 11
                    font.bold: true
                    textColor: "#8ea1ad"
                    Layout.fillWidth: true
                }
                FluText {
                    text: "权重"
                    font.pixelSize: 11
                    font.bold: true
                    textColor: "#8ea1ad"
                    Layout.preferredWidth: 50
                }
            }

            // Unit rows
            Repeater {
                model: units
                delegate: RowLayout {
                    Layout.fillWidth: true
                    FluText {
                        text: modelData.name
                        font.pixelSize: 11
                        Layout.fillWidth: true
                    }
                    FluText {
                        text: modelData.weight
                        font.pixelSize: 11
                        Layout.preferredWidth: 50
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }
    }
}
