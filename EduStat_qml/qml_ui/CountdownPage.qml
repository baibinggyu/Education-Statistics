import QtQuick
import QtQuick.Layouts
import FluentUI

// 课堂倒计时 Classroom Countdown Timer
Item {
    property int totalSeconds: 300
    property int remainingSeconds: 300
    property bool running: false
    property int presetIndex: 2

    onRemainingSecondsChanged: progressCanvas.requestPaint()
    onRunningChanged: progressCanvas.requestPaint()
    onTotalSecondsChanged: progressCanvas.requestPaint()

    ListModel {
        id: presetModel
        ListElement { label: "1 分钟"; seconds: 60 }
        ListElement { label: "3 分钟"; seconds: 180 }
        ListElement { label: "5 分钟"; seconds: 300 }
        ListElement { label: "10 分钟"; seconds: 600 }
        ListElement { label: "15 分钟"; seconds: 900 }
        ListElement { label: "30 分钟"; seconds: 1800 }
        ListElement { label: "自定义"; seconds: 0 }
    }

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        running: running && remainingSeconds > 0
        onTriggered: {
            remainingSeconds--
            if (remainingSeconds <= 0) {
                running = false
            }
        }
    }

    function formatTime(s) {
        var m = Math.floor(s / 60)
        var sec = s % 60
        return (m < 10 ? "0" + m : m) + ":" + (sec < 10 ? "0" + sec : sec)
    }

    function progressRatio() {
        if (totalSeconds <= 0) return 0
        return remainingSeconds / totalSeconds
    }

    function selectPreset(idx) {
        presetIndex = idx
        running = false
        var item = presetModel.get(idx)
        if (item.seconds > 0) {
            totalSeconds = item.seconds
            remainingSeconds = item.seconds
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 24

        // Left: Timer display + presets
        FluFrame {
            Layout.preferredWidth: 480
            Layout.fillHeight: true
            radius: 12

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 20

                FluText {
                    text: "课堂倒计时"
                    font.pixelSize: 18
                    font.bold: true
                }

                FluText {
                    text: "辅助课堂练习、阅读、讨论等环节的时间管理"
                    font.pixelSize: 11
                    textColor: "#8ea1ad"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                FluDivider { Layout.fillWidth: true }

                // Circular timer
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 260
                    Layout.preferredHeight: 260

                    // Background ring
                    Rectangle {
                        anchors.centerIn: parent
                        width: 240; height: 240
                        radius: 120
                        color: "transparent"
                        border.width: 12
                        border.color: Qt.rgba(15/255, 118/255, 110/255, 0.15)
                    }

                    // Progress ring using Canvas
                    Canvas {
                        id: progressCanvas
                        anchors.centerIn: parent
                        width: 240; height: 240
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var cx = width / 2, cy = height / 2, r = 114
                            var angle = -Math.PI / 2
                            var ratio = totalSeconds > 0 ? remainingSeconds / totalSeconds : 0
                            var sweep = ratio * 2 * Math.PI

                            ctx.beginPath()
                            ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                            ctx.strokeStyle = FluTheme.dark ? "rgba(15,118,110,0.15)" : "rgba(0,0,0,0.06)"
                            ctx.lineWidth = 12
                            ctx.stroke()

                            ctx.beginPath()
                            ctx.arc(cx, cy, r, angle, angle + sweep)
                            ctx.strokeStyle = running ? "#0f766e" : (remainingSeconds <= 30 ? "#ef4444" : "#0f766e")
                            ctx.lineWidth = 12
                            ctx.lineCap = "round"
                            ctx.stroke()
                        }
                    }

                    // Time text
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 2

                        FluText {
                            text: formatTime(remainingSeconds)
                            font.pixelSize: 52
                            font.bold: true
                            textColor: remainingSeconds <= 30 && running ? "#ef4444" : "#ffffff"
                            Layout.alignment: Qt.AlignHCenter
                        }

                        FluText {
                            text: running ? (remainingSeconds <= 30 ? "⏰ 即将结束" : "倒计时中...") : (remainingSeconds < totalSeconds ? "已暂停" : "准备开始")
                            font.pixelSize: 11
                            textColor: remainingSeconds <= 30 && running ? "#ef4444" : "#8ea1ad"
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }

                // Preset buttons
                FluText {
                    text: "快捷时长"
                    font.pixelSize: 12
                    font.bold: true
                    textColor: "#b3c0c8"
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 4
                    rowSpacing: 8
                    columnSpacing: 8

                    Repeater {
                        model: presetModel
                        delegate: Rectangle {
                            required property int index
                            required property string label
                            Layout.fillWidth: true
                            height: 32
                            radius: 6
                            color: presetIndex === index ? "#0f766e" : (hoverArea.containsMouse ? Qt.rgba(43/255, 50/255, 56/255, 1) : Qt.rgba(255,255,255,0.06))

                            FluText {
                                anchors.centerIn: parent
                                text: label
                                font.pixelSize: 10
                                textColor: presetIndex === index ? "#ffffff" : "#b3c0c8"
                            }

                            MouseArea {
                                id: hoverArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (index === presetModel.count - 1) {
                                        // Custom — toggle a simple input approach
                                        return
                                    }
                                    selectPreset(index)
                                }
                            }
                        }
                    }
                }

                // Custom time input
                RowLayout {
                    visible: presetIndex === presetModel.count - 1
                    FluTextBox {
                        Layout.preferredWidth: 100
                        placeholderText: "分钟数"
                    }
                    FluText {
                        text: "分钟"
                        font.pixelSize: 11
                        textColor: "#8ea1ad"
                    }
                    FluFilledButton {
                        text: "设定"
                        font.pixelSize: 11
                        Layout.preferredHeight: 32
                    }
                }

                Item { Layout.fillHeight: true }

                // Control buttons
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    FluFilledButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        text: running ? "暂 停" : (remainingSeconds < totalSeconds ? "继 续" : "开 始")
                        font.pixelSize: 14
                        font.bold: true
                        onClicked: {
                            if (remainingSeconds <= 0) {
                                remainingSeconds = totalSeconds
                            }
                            running = !running
                        }
                    }

                    FluButton {
                        Layout.preferredHeight: 46
                        text: "重 置"
                        font.pixelSize: 13
                        onClicked: {
                            running = false
                            remainingSeconds = totalSeconds
                        }
                    }
                }
            }
        }

        // Right: Info / usage panel
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            FluText {
                text: "使用场景"
                font.pixelSize: 18
                font.bold: true
            }

            FluFrame {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 10

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 14

                    Repeater {
                        model: [
                            { icon: "📖", title: "课堂阅读", desc: "设定阅读时间，让学生在规定时间内完成材料阅读" },
                            { icon: "✏️", title: "随堂练习", desc: "限时完成课堂习题，培养学生时间管理能力" },
                            { icon: "💬", title: "小组讨论", desc: "控制讨论时长，确保课堂节奏紧凑有序" },
                            { icon: "🧪", title: "实验操作", desc: "倒计时提醒学生实验剩余时间，提高效率" },
                            { icon: "📝", title: "随堂测验", desc: "严格限时测验，模拟考试环境" },
                            { icon: "🎯", title: "课间休息", desc: "设定休息时长，准时恢复上课" }
                        ]

                        delegate: FluFrame {
                            required property var modelData
                            Layout.fillWidth: true
                            radius: 8
                            color: FluTheme.dark ? Qt.rgba(25/255, 29/255, 35/255, 1) : "#fafafa"
                            padding: 14

                            RowLayout {
                                anchors.fill: parent
                                spacing: 12

                                FluText {
                                    text: modelData.icon
                                    font.pixelSize: 24
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    FluText {
                                        text: modelData.title
                                        font.pixelSize: 13
                                        font.bold: true
                                    }
                                    FluText {
                                        text: modelData.desc
                                        font.pixelSize: 10
                                        textColor: "#8ea1ad"
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
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
