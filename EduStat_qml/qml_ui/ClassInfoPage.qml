import QtQuick
import QtQuick.Layouts
import FluentUI

// 班级信息 Class Info Dashboard
Item {
    RowLayout {
        anchors.fill: parent
        spacing: 24

        // Left: main content area
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            // Header
            RowLayout {
                FluText {
                    text: "班级信息总览"
                    font.pixelSize: 18
                    font.bold: true
                }
                Item { Layout.fillWidth: true }
                FluFilledButton {
                    text: "刷新分析"
                    font.pixelSize: 12
                }
            }

            // Info hint
            FluFrame {
                Layout.fillWidth: true
                radius: 8
                padding: 12
                FluText {
                    anchors.fill: parent
                    text: "自动汇总当前课程的成绩分布、单元走势和班级构成；有网络时优先请求 DeepSeek 生成建议。"
                    font.pixelSize: 11
                    textColor: "#8ea1ad"
                    wrapMode: Text.WordWrap
                }
            }

            // 4 Stat cards
            RowLayout {
                Layout.fillWidth: true
                spacing: 14
                StatCard { title: "学生总数"; value: "156" }
                StatCard { title: "整体均分"; value: "82.5" }
                StatCard { title: "表现最强单元"; value: "第一章" }
                StatCard { title: "重点跟进单元"; value: "第四章" }
            }

            // Charts section
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 14

                // Left: bar + line stacked
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 14
                    ChartCard {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredHeight: 220
                        title: "成绩段分布"
                        subtitle: "各分数段人数统计"
                    }
                    ChartCard {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredHeight: 200
                        title: "单元均分走势"
                        subtitle: "各单元平均分变化趋势"
                    }
                }

                // Right: pie
                ChartCard {
                    Layout.preferredWidth: 300
                    Layout.fillHeight: true
                    title: "班级构成"
                    subtitle: "师范一班 · 二班 · 三班"
                }
            }
        }

        // Right: AI Analysis panel
        FluFrame {
            Layout.preferredWidth: 360
            Layout.minimumWidth: 300
            Layout.fillHeight: true
            radius: 12

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                FluText {
                    text: "教学分析建议"
                    font.pixelSize: 15
                    font.bold: true
                }

                FluFrame {
                    Layout.fillWidth: true
                    radius: 6
                    color: Qt.rgba(20/255, 23/255, 28/255, 1)
                    padding: 10
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 4
                        FluText {
                            text: "分析来源：等待刷新"
                            font.pixelSize: 11
                            textColor: "#8ea1ad"
                        }
                        FluText {
                            text: "网络状态：等待检测"
                            font.pixelSize: 11
                            textColor: "#8ea1ad"
                        }
                    }
                }

                FluFrame {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 6
                    color: Qt.rgba(20/255, 23/255, 28/255, 1)
                    padding: 12
                    FluText {
                        anchors.fill: parent
                        text: "点击「刷新分析」按钮后，此处将展示 AI 生成的教学分析建议..."
                        font.pixelSize: 11
                        textColor: "#7f8c96"
                        wrapMode: Text.WordWrap
                    }
                }

                FluText {
                    text: "提示词预览"
                    font.pixelSize: 12
                    font.bold: true
                    textColor: "#b3c0c8"
                }

                FluFrame {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 90
                    radius: 6
                    color: Qt.rgba(20/255, 23/255, 28/255, 1)
                    padding: 10
                    FluText {
                        anchors.fill: parent
                        text: "分析以下班级数据，给出教学建议...\n(提示词将在刷新时生成)"
                        font.pixelSize: 10
                        textColor: "#6a7882"
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }

    // ========= COMPONENTS ==========

    component StatCard: FluFrame {
        required property string title
        required property string value

        Layout.fillWidth: true
        Layout.preferredHeight: 90
        radius: 14
        padding: 0

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 6
            FluText {
                text: title
                font.pixelSize: 11
                textColor: "#8ea1ad"
            }
            FluText {
                text: value
                font.pixelSize: 22
                font.bold: true
                textColor: "#f8fbfc"
            }
        }
    }

    component ChartCard: FluFrame {
        required property string title
        property string subtitle: ""

        radius: 12
        padding: 16

        ColumnLayout {
            anchors.fill: parent
            spacing: 10
            FluText {
                text: title
                font.pixelSize: 13
                font.bold: true
            }
            FluText {
                visible: subtitle !== ""
                text: subtitle
                font.pixelSize: 10
                textColor: "#53636d"
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 6
                color: Qt.rgba(25/255, 29/255, 35/255, 1)
                FluText {
                    anchors.centerIn: parent
                    text: "图表区域"
                    font.pixelSize: 13
                    textColor: "#53636d"
                }
            }
        }
    }
}
