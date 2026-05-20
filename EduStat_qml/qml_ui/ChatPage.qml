import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import FluentUI
import EduStat.Backend 1.0

Item {
    id: root
    property string activeSessionId: ""

    // ---- ChatBackend (from C++) ----
    ChatBackend {
        id: chat
        onMessageReceived: function(role, content) {
            msgModel.append({role: role, content: content})
            scrollToBottom()
        }
        onErrorOccurred: function(msg) {
            msgModel.append({role: "system", content: "[错误] " + msg})
            scrollToBottom()
        }
        onCompressed: function(summary) {
            msgModel.append({role: "system", content: summary})
            scrollToBottom()
        }
        onConversationReset: {
            msgModel.clear()
        }
        onSessionListReset: {
            sessionModel.clear()
        }
        onSessionListed: function(id, title, preview, updatedAt, active) {
            sessionModel.append({
                sessionId: id,
                title: title,
                preview: preview,
                updatedAt: updatedAt,
                active: active
            })
        }
        onSessionSelected: function(id) {
            root.activeSessionId = id
        }
        onHistoryLoaded: function(role, content) {
            msgModel.append({role: role, content: content})
        }
    }

    // ---- 消息数据模型 ----
    ListModel {
        id: msgModel
    }

    ListModel {
        id: sessionModel
    }

    Component.onCompleted: chat.newConversation()

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.preferredWidth: 250
            Layout.fillHeight: true
            color: Qt.rgba(25/255, 28/255, 33/255, 1)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                FluFilledButton {
                    Layout.fillWidth: true
                    text: "新对话"
                    enabled: !chat.loading
                    onClicked: chat.newConversation()
                }

                FluText {
                    text: "历史对话"
                    font.pixelSize: 12
                    font.bold: true
                    textColor: "#d7e1e8"
                    Layout.topMargin: 4
                }

                ListView {
                    id: sessionList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 6
                    model: sessionModel

                    delegate: Rectangle {
                        required property string sessionId
                        required property string title
                        required property string preview
                        required property bool active

                        width: sessionList.width
                        height: 68
                        radius: 8
                        color: active ? "#0f766e" :
                               sessionMouse.containsMouse ? Qt.rgba(43/255, 50/255, 56/255, 1) :
                               "transparent"

                        MouseArea {
                            id: sessionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: chat.loadConversation(sessionId)
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.right: deleteBtn.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 10
                            anchors.rightMargin: 6
                            spacing: 4

                            FluText {
                                width: parent.width
                                text: title
                                font.pixelSize: 12
                                font.bold: active
                                textColor: active ? "#ffffff" : "#dbe6ed"
                                elide: Text.ElideRight
                            }

                            FluText {
                                width: parent.width
                                text: preview.length > 0 ? preview : "暂无回复"
                                font.pixelSize: 10
                                textColor: active ? "#d4f5ee" : "#84939f"
                                elide: Text.ElideRight
                            }
                        }

                        FluButton {
                            id: deleteBtn
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            width: 30
                            height: 30
                            text: "×"
                            visible: sessionMouse.containsMouse || active
                            onClicked: chat.deleteConversation(sessionId)
                        }
                    }
                }
            }
        }

        Rectangle {
            width: 1
            Layout.fillHeight: true
            color: Qt.rgba(49/255, 56/255, 64/255, 1)
        }

        ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 0

        // ---- 顶栏 ----
        FluFrame {
            Layout.fillWidth: true
            radius: 0
            padding: 16

            RowLayout {
                anchors.fill: parent
                FluText {
                    text: "AI 助手"
                    font.pixelSize: 18
                    font.bold: true
                }
                Item { Layout.fillWidth: true }

                FluText {
                    text: "保留轮数:"
                    font.pixelSize: 11
                    textColor: "#8ea1ad"
                }
                FluComboBox {
                    id: compressTurnsBox
                    Layout.preferredWidth: 70
                    model: ["5", "10", "15", "20"]
                    currentIndex: 1
                    onCurrentTextChanged: chat.setCompressTurns(parseInt(currentText))
                }
                FluButton {
                    text: "压缩"
                    onClicked: chat.compressHistory()
                }
                FluButton {
                    text: "清空"
                    enabled: activeSessionId.length > 0 && !chat.loading
                    onClicked: {
                        chat.clearHistory()
                    }
                }
            }
        }

        FluDivider {}

        // ---- 消息列表 ----
        ScrollView {
            id: scrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.vertical: FluScrollBar { id: vbar }

            ColumnLayout {
                id: msgColumn
                width: scrollView.availableWidth
                spacing: 12

                // 欢迎语
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: msgModel.count === 0 && !chat.loading
                    spacing: 10

                    Item { Layout.fillWidth: true; implicitHeight: 80 }

                    FluText {
                        Layout.fillWidth: true
                        text: "开始新对话"
                        font.pixelSize: 30
                        font.bold: true
                        textColor: "#edf6f4"
                        horizontalAlignment: Text.AlignHCenter
                    }

                    FluText {
                        Layout.fillWidth: true
                        text: "我是 " + chat.modelName + "，输入问题后会自动保存到左侧历史。"
                        font.pixelSize: 13
                        textColor: "#8ea1ad"
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                Repeater {
                    model: msgModel

                    delegate: Item {
                        id: delegateItem
                        Layout.fillWidth: true
                        implicitHeight: bubbleFrame.implicitHeight + 8

                        FluFrame {
                            id: bubbleFrame
                            anchors.right: role === "user" ? parent.right : undefined
                            anchors.left: role !== "user" ? parent.left : undefined
                            anchors.margins: 16
                            width: Math.min(msgColumn.width * 0.78,
                                            msgColumn.width - 32)
                            radius: 12
                            padding: 12
                            color: role === "user" ? "#0f766e" :
                                   role === "system" ? Qt.rgba(40/255, 25/255, 25/255, 1) :
                                   Qt.rgba(30/255, 34/255, 40/255, 1)

                            TextEdit {
                                id: textContent
                                width: parent.width - 24
                                text: content
                                textFormat: role === "assistant"
                                            ? TextEdit.MarkdownText
                                            : TextEdit.PlainText
                                font.pixelSize: 12
                                color: role === "user" ? "#ffffff" :
                                       role === "system" ? "#ef4444" : "#e0e0e0"
                                wrapMode: TextEdit.WordWrap
                                readOnly: true
                                selectByMouse: true
                                padding: 0
                            }
                        }
                    }
                }

                // 加载指示器
                FluText {
                    Layout.leftMargin: 16
                    text: "思考中..."
                    font.pixelSize: 12
                    textColor: "#8ea1ad"
                    visible: chat.loading
                }

                Item { Layout.fillWidth: true; implicitHeight: 8; visible: msgModel.count > 0 }
            }
        }

        // ---- 输入区 ----
        FluFrame {
            Layout.fillWidth: true
            radius: 0
            padding: 12

            RowLayout {
                anchors.fill: parent
                spacing: 12

                // Enter 发送 / Shift+Enter 换行
                // Qt 6 中 Keys.onReturnPressed 在 FluMultilineTextBox 之前触发
                FluMultilineTextBox {
                    id: inputBox
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    placeholderText: "输入消息... (Enter 发送, Shift+Enter 换行)"
                    enabled: !chat.loading

                    Keys.onReturnPressed: function(event) {
                        if (!(event.modifiers & Qt.ShiftModifier)) {
                            event.accepted = true
                            sendBtn.clicked()
                        }
                    }
                }

                FluFilledButton {
                    id: sendBtn
                    text: "发送"
                    Layout.preferredHeight: 60
                    enabled: inputBox.text.trim().length > 0 && !chat.loading
                    onClicked: {
                        var txt = inputBox.text.trim()
                        if (txt.length === 0) return
                        msgModel.append({role: "user", content: txt})
                        chat.sendMessage(txt)
                        inputBox.text = ""
                        scrollToBottom()
                    }
                }
            }
        }
    }
    }

    // ---- 辅助: 滚动到底部 ----
    Timer {
        id: scrollTimer
        interval: 30
        repeat: false
        onTriggered: {
            if (vbar.size < 1.0)
                vbar.position = 1.0 - vbar.size
        }
    }

    function scrollToBottom() {
        scrollTimer.start()
    }
}
