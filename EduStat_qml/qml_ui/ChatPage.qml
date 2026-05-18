import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import FluentUI

Item {
    id: root

    // ---- ChatBackend (from C++) ----
    ChatBackend {
        id: chat
        onMessageReceived: function(role, content) {
            msgModel.append({role: role, content: content})
            msgList.positionViewAtEnd()
        }
        onErrorOccurred: function(msg) {
            msgModel.append({role: "system", content: "[错误] " + msg})
        }
        onCompressed: {
            // 重建消息列表以匹配压缩后的 history
            msgModel.clear()
            // 压缩后 ChatBackend 内部 history 已更新，但 QML 侧不知道具体内容
            // 简单处理：加一条提示消息
            msgModel.append({role: "system", content: "[对话已压缩，早期内容已总结]"})
        }
    }

    // ---- 消息数据模型 ----
    ListModel {
        id: msgModel
    }

    ColumnLayout {
        anchors.fill: parent
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
                    onClicked: {
                        chat.clearHistory()
                        msgModel.clear()
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
            ScrollBar.vertical: FluScrollBar {}

            ColumnLayout {
                id: msgColumn
                width: scrollView.availableWidth
                spacing: 12
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 16

                // 欢迎语
                FluText {
                    Layout.fillWidth: true
                    text: "你好！我是 " + chat.modelName + "，有什么可以帮你的？"
                    font.pixelSize: 12
                    textColor: "#53636d"
                    horizontalAlignment: Text.AlignHCenter
                    visible: msgModel.count === 0
                }

                Repeater {
                    model: msgModel
                    delegate: Item {
                        Layout.fillWidth: true
                        implicitHeight: bubbleCol.implicitHeight + 4

                        ColumnLayout {
                            id: bubbleCol
                            width: parent.width
                            spacing: 4

                            // 角色标签
                            FluText {
                                text: role === "user" ? "你" :
                                      role === "assistant" ? "AI" : "系统"
                                font.pixelSize: 10
                                textColor: role === "user" ? "#0f766e" :
                                            role === "system" ? "#ef4444" : "#8ea1ad"
                                Layout.leftMargin: role === "user" ? 0 : 16
                                Layout.alignment: role === "user" ?
                                    Qt.AlignRight : Qt.AlignLeft
                            }

                            // 消息气泡
                            FluFrame {
                                Layout.preferredWidth: Math.min(
                                    implicitWidth, msgColumn.width * 0.78)
                                Layout.maximumWidth: msgColumn.width - 32
                                Layout.alignment: role === "user" ?
                                    Qt.AlignRight : Qt.AlignLeft
                                radius: 12
                                padding: 12
                                color: role === "user" ? "#0f766e" :
                                       role === "system" ? Qt.rgba(40/255, 25/255, 25/255, 1) :
                                       Qt.rgba(30/255, 34/255, 40/255, 1)

                                FluText {
                                    anchors.fill: parent
                                    text: content
                                    font.pixelSize: 12
                                    textColor: role === "user" ? "#ffffff" :
                                               role === "system" ? "#ef4444" : "#e0e0e0"
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }

                // 加载动画
                Item {
                    Layout.fillWidth: true
                    implicitHeight: loadingRow.visible ? 24 : 0
                    RowLayout {
                        id: loadingRow
                        visible: chat.loading
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        spacing: 8
                        FluText {
                            text: "思考中..."
                            font.pixelSize: 12
                            textColor: "#8ea1ad"
                        }
                    }
                }
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

                FluMultilineTextBox {
                    id: inputBox
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    placeholderText: "输入消息... (Enter 发送, Shift+Enter 换行)"
                    enabled: !chat.loading

                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Return &&
                            !(event.modifiers & Qt.ShiftModifier)) {
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
                        msgList.positionViewAtEnd()
                    }
                }
            }
        }
    }

    // 辅助：滚动到底部
    function msgList_scroll() {
        msgList.positionViewAtEnd()
    }
}
