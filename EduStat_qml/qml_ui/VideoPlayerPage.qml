import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import FluentUI

// 视频播放 Video Player Page
Item {
    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        FluText {
            text: "视频播放"
            font.pixelSize: 18
            font.bold: true
        }

        // Video area
        FluFrame {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 12

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 2
                spacing: 0

                // Video display
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#000000"
                    radius: 10

                    FluText {
                        anchors.centerIn: parent
                        text: "视频播放区域"
                        font.pixelSize: 20
                        textColor: "#444444"
                    }

                    // Play overlay
                    Rectangle {
                        anchors.centerIn: parent
                        width: 64; height: 64
                        radius: 32
                        color: Qt.rgba(255,255,255,0.2)
                        FluText {
                            anchors.centerIn: parent
                            text: "▶"
                            font.pixelSize: 24
                            textColor: "#ffffff"
                        }
                    }

                    // Smart subtitle overlay
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 20
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(parent.width * 0.85, 600)
                        height: subtitleRow.implicitHeight + 24
                        radius: 8
                        color: Qt.rgba(0, 0, 0, 0.75)

                        ColumnLayout {
                            id: subtitleRow
                            anchors.centerIn: parent
                            width: parent.width - 24
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Rectangle {
                                    width: 8; height: 8
                                    radius: 4
                                    color: "#22c55e"

                                    SequentialAnimation on color {
                                        running: true; loops: Animation.Infinite
                                        PropertyAnimation { from: "#22c55e"; to: "#4ade80"; duration: 800 }
                                        PropertyAnimation { from: "#4ade80"; to: "#22c55e"; duration: 800 }
                                    }
                                }

                                FluText {
                                    text: "AI 智能字幕"
                                    font.pixelSize: 9
                                    textColor: "#22c55e"
                                }

                                Item { Layout.fillWidth: true }

                                FluText {
                                    text: "中文"
                                    font.pixelSize: 9
                                    textColor: "#8ea1ad"
                                }
                            }

                            FluText {
                                Layout.fillWidth: true
                                text: "现在我们来看第三章的重点内容——放大电路的基本工作原理。首先我们要理解三极管的三个工作区域..."
                                font.pixelSize: 14
                                textColor: "#ffffff"
                                wrapMode: Text.WordWrap
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }

                // Controls bar
                Rectangle {
                    Layout.fillWidth: true
                    height: 100
                    color: FluTheme.dark ? Qt.rgba(24/255, 27/255, 32/255, 1) : "#f0f0f0"
                    radius: 8

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 10

                        // Progress row
                        RowLayout {
                            spacing: 10
                            FluText {
                                text: "00:00"
                                font.pixelSize: 11
                                textColor: "#8ea1ad"
                                Layout.preferredWidth: 36
                            }
                            FluSlider {
                                Layout.fillWidth: true
                                from: 0; to: 100; value: 30
                            }
                            FluText {
                                text: "03:42"
                                font.pixelSize: 11
                                textColor: "#8ea1ad"
                                Layout.preferredWidth: 36
                            }
                        }

                        // Controls row
                        RowLayout {
                            spacing: 6

                            // Playback group
                            FluIconButton {
                                text: "⏮"
                                font.pixelSize: 14
                            }
                            FluIconButton {
                                text: "⏯"
                                font.pixelSize: 16
                            }
                            FluIconButton {
                                text: "⏭"
                                font.pixelSize: 14
                            }

                            Rectangle {
                                width: 1; height: 20
                                color: Qt.rgba(255,255,255,0.1)
                            }

                            // Volume group
                            FluIconButton {
                                text: "🔊"
                                font.pixelSize: 12
                            }
                            FluSlider {
                                Layout.preferredWidth: 80
                                from: 0; to: 100; value: 70
                            }

                            Item { Layout.fillWidth: true }

                            // Right-side controls
                            FluText {
                                text: "倍速"
                                font.pixelSize: 10
                                textColor: "#8ea1ad"
                            }
                            FluComboBox {
                                Layout.preferredWidth: 72
                                model: ["0.5x","0.75x","1.0x","1.25x","1.5x","2.0x"]
                                currentIndex: 2
                            }

                            Rectangle {
                                width: 1; height: 20
                                color: Qt.rgba(255,255,255,0.1)
                            }

                            FluText {
                                text: "画质"
                                font.pixelSize: 10
                                textColor: "#8ea1ad"
                            }
                            FluComboBox {
                                Layout.preferredWidth: 76
                                model: ["1080P", "720P", "480P", "自动"]
                                currentIndex: 0
                            }

                            FluIconButton {
                                text: "⛶"
                                font.pixelSize: 14
                            }
                        }
                    }
                }

                // Smart subtitle settings
                FluFrame {
                    Layout.fillWidth: true
                    radius: 8
                    color: FluTheme.dark ? Qt.rgba(25/255, 29/255, 35/255, 1) : "#fafafa"
                    padding: 12

                    GridLayout {
                        anchors.fill: parent
                        columns: 6
                        rowSpacing: 8
                        columnSpacing: 12

                        FluText {
                            text: "智能字幕"
                            font.pixelSize: 12
                            font.bold: true
                            Layout.alignment: Qt.AlignVCenter
                        }

                        FluComboBox {
                            Layout.preferredWidth: 100
                            model: ["中文", "English", "日本語"]
                            currentIndex: 0
                        }

                        FluComboBox {
                            Layout.preferredWidth: 90
                            model: ["标准", "小号", "大号"]
                            currentIndex: 0
                        }

                        FluToggleSwitch { checked: true }

                        FluText {
                            text: "AI实时生成"
                            font.pixelSize: 10
                            textColor: "#22c55e"
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item { Layout.fillWidth: true }

                        FluText {
                            text: "字幕将实时生成并显示在视频区域底部"
                            font.pixelSize: 10
                            textColor: "#8ea1ad"
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }
            }
        }

        // Video list
        FluFrame {
            Layout.fillWidth: true
            Layout.preferredHeight: 160
            radius: 10

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                FluText {
                    text: "视频列表"
                    font.pixelSize: 13
                    font.bold: true
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    ScrollBar.vertical: FluScrollBar {}

                    FluStaggeredLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        itemWidth: 190
                        colSpacing: 12
                        rowSpacing: 8
                        Repeater {
                            model: [
                                { chapter: "第一章 导论", duration: "45:20" },
                                { chapter: "第二章 基础理论", duration: "52:10" },
                                { chapter: "第三章 进阶应用", duration: "38:45" },
                                { chapter: "第四章 综合案例", duration: "61:30" },
                                { chapter: "第五章 实验演示", duration: "32:15" },
                                { chapter: "第六章 习题讲解", duration: "28:50" }
                            ]

                            delegate: FluFrame {
                                required property var modelData
                                radius: 8
                                height: 64
                                color: FluTheme.dark ? Qt.rgba(25/255, 29/255, 35/255, 1) : "#fafafa"
                                padding: 10

                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 8
                                    Rectangle {
                                        Layout.preferredWidth: 42; Layout.fillHeight: true
                                        radius: 4
                                        color: "#0f766e"
                                        FluText {
                                            anchors.centerIn: parent
                                            text: "▶"
                                            font.pixelSize: 14
                                            textColor: "#ffffff"
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        FluText {
                                            text: modelData.chapter
                                            font.pixelSize: 11
                                            font.bold: true
                                            Layout.fillWidth: true
                                            wrapMode: Text.WordWrap
                                        }
                                        FluText {
                                            text: modelData.duration
                                            font.pixelSize: 9
                                            textColor: "#8ea1ad"
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
