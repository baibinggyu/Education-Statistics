import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import FluentUI
import EduStat.Backend 1.0

Item {
    id: root
    property string activeSessionId: ""
    property string streamingMsgId: ""

    // ---- AgentBackend (from C++) ----
    AgentBackend {
        id: chat
        onMessageReceived: function(role, content) {
            // If we had a streaming in-progress message, remove it first
            if (streamingMsgId !== "") {
                for (var i = msgModel.count - 1; i >= 0; i--) {
                    if (msgModel.get(i).msgId === streamingMsgId) {
                        msgModel.remove(i)
                        break
                    }
                }
                streamingMsgId = ""
            }
            msgModel.append({msgId: genId(), role: role, content: content, isStep: false, stepStatus: "", stepSuccess: false, stepResult: "", collapsed: false})
            scrollToBottom()
        }
        onStreamChunk: function(chunk) {
            if (streamingMsgId === "") {
                streamingMsgId = genId()
                msgModel.append({msgId: streamingMsgId, role: "assistant", content: chunk, isStep: false, stepStatus: "", stepSuccess: false, stepResult: "", collapsed: false})
            } else {
                for (var i = msgModel.count - 1; i >= 0; i--) {
                    if (msgModel.get(i).msgId === streamingMsgId) {
                        var entry = msgModel.get(i)
                        msgModel.setProperty(i, "content", entry.content + chunk)
                        break
                    }
                }
            }
            scrollToBottom()
        }
        onStreamFinished: {
            streamingMsgId = ""
        }
        onErrorOccurred: function(msg) {
            msgModel.append({msgId: genId(), role: "system", content: "[错误] " + msg, isStep: false, stepStatus: "", stepSuccess: false, stepResult: "", collapsed: false})
            scrollToBottom()
        }
        onStepUpdated: function(description, status, success, resultJson) {
            msgModel.append({
                msgId: genId(),
                role: "step",
                content: description + "\n状态: " + status + (resultJson ? "\n" + resultJson : ""),
                isStep: true,
                stepStatus: status,
                stepSuccess: success,
                stepResult: resultJson || "",
                collapsed: true
            })
            scrollToBottom()
        }
        onConversationReset: {
            msgModel.clear()
            streamingMsgId = ""
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
            msgModel.append({msgId: genId(), role: role, content: content, isStep: false, stepStatus: "", stepSuccess: false, stepResult: "", collapsed: false})
        }
    }

    // ---- Message models ----
    ListModel { id: msgModel }
    ListModel { id: sessionModel }

    // Unique message ID generator
    property int msgIdCounter: 0
    function genId() {
        msgIdCounter++
        return "msg_" + msgIdCounter
    }

    Component.onCompleted: chat.newConversation()

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ---- Session sidebar ----
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

        // ---- Main chat area ----
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // ---- Top bar ----
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

                    // Agent mode toggle
                    FluText {
                        text: "Agent"
                        font.pixelSize: 11
                        textColor: "#d7e1e8"
                    }
                    FluToggleSwitch {
                        id: agentToggle
                        checked: chat.agentMode
                        enabled: !chat.loading
                        onClicked: chat.setAgentMode(checked)
                    }

                    // Stop button
                    FluButton {
                        text: "停止"
                        visible: chat.loading
                        onClicked: chat.stopGeneration()
                    }

                    // Clear button
                    FluButton {
                        text: "清空"
                        enabled: !chat.loading
                        onClicked: chat.clearHistory()
                    }
                }
            }

            FluDivider {}

            // ---- Message list ----
            ScrollView {
                id: scrollView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.vertical: FluScrollBar { id: vbar }

                ColumnLayout {
                    id: msgColumn
                    width: scrollView.availableWidth
                    spacing: 10

                    // Welcome
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: msgModel.count === 0 && !chat.loading
                        spacing: 10

                        Item { Layout.fillWidth: true; implicitHeight: 80 }

                        FluText {
                            Layout.fillWidth: true
                            text: agentToggle.checked ? "Agent 模式" : "开始新对话"
                            font.pixelSize: 30
                            font.bold: true
                            textColor: "#edf6f4"
                            horizontalAlignment: Text.AlignHCenter
                        }

                        FluText {
                            Layout.fillWidth: true
                            text: agentToggle.checked
                                ? "我是 " + chat.modelName + " Agent，可以使用工具完成复杂任务。"
                                : "我是 " + chat.modelName + "，输入问题后会自动保存到左侧历史。"
                            font.pixelSize: 13
                            textColor: "#8ea1ad"
                            horizontalAlignment: Text.AlignHCenter
                        }

                    }

                    Repeater {
                        model: msgModel

                        delegate: Item {
                            id: delegateItem
                            required property string msgId
                            required property string role
                            required property string content
                            required property bool isStep
                            required property string stepStatus
                            required property bool stepSuccess
                            required property string stepResult
                            required property bool collapsed
                            Layout.fillWidth: true
                            implicitHeight: (isStep || role === "step") ? stepCard.implicitHeight + 8
                                                                      : bubbleFrame.implicitHeight + 8

                            // ---- Step card (agent progress, collapsible) ----
                            FluFrame {
                                id: stepCard
                                visible: isStep === true || role === "step"
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: Math.min(msgColumn.width * 0.85, msgColumn.width - 32)
                                radius: 10
                                padding: 12
                                color: stepSuccess ? Qt.rgba(15/255, 118/255, 110/255, 0.25) :
                                        stepStatus === "Failed" ? Qt.rgba(239/255, 68/255, 68/255, 0.2) :
                                        Qt.rgba(40/255, 45/255, 52/255, 1)

                                ColumnLayout {
                                    id: stepCardContent
                                    anchors.fill: parent
                                    spacing: 4

                                    // Header row (always visible, clickable to toggle)
                                    MouseArea {
                                        id: stepHeaderArea
                                        Layout.fillWidth: true
                                        implicitHeight: stepHeaderRow.implicitHeight
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onClicked: {
                                            var idx = -1
                                            for (var i = 0; i < msgModel.count; i++) {
                                                if (msgModel.get(i).msgId === msgId) { idx = i; break }
                                            }
                                            if (idx >= 0) {
                                                var c = msgModel.get(idx).collapsed
                                                msgModel.setProperty(idx, "collapsed", !c)
                                            }
                                        }

                                        RowLayout {
                                            id: stepHeaderRow
                                            width: parent.width
                                            FluText {
                                                id: stepTitle
                                                text: stepStatus !== "" ? "◉ " + stepStatus : "◉ Step"
                                                font.pixelSize: 12
                                                font.bold: true
                                                textColor: stepSuccess ? "#22c55e" :
                                                            stepStatus === "Failed" ? "#ef4444" : "#8ea1ad"
                                            }
                                            Item { Layout.fillWidth: true }
                                            FluText {
                                                text: stepSuccess ? "✓" :
                                                      stepStatus === "Failed" ? "✗" : "..."
                                                font.pixelSize: 14
                                                textColor: stepSuccess ? "#22c55e" :
                                                            stepStatus === "Failed" ? "#ef4444" : "#8ea1ad"
                                            }
                                            FluText {
                                                text: collapsed ? "▶" : "▼"
                                                font.pixelSize: 10
                                                textColor: "#53636d"
                                            }
                                        }
                                    }

                                    // Content area (hidden when collapsed)
                                    Item {
                                        visible: !collapsed
                                        Layout.fillWidth: true
                                        implicitHeight: stepDetailText.implicitHeight

                                        TextEdit {
                                            id: stepDetailText
                                            width: parent.width
                                            text: content
                                            textFormat: TextEdit.PlainText
                                            font { pixelSize: 11; family: "Source Han Sans CN, Noto Sans CJK TC, sans-serif" }
                                            color: "#b3c0c8"
                                            wrapMode: TextEdit.WordWrap
                                            readOnly: true
                                            selectByMouse: true
                                            padding: 0
                                        }
                                    }
                                }
                            }

                            // ---- Regular message bubble ----
                            FluFrame {
                                id: bubbleFrame
                                visible: !(isStep === true || role === "step")
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

                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: 4

                                    TextEdit {
                                        id: bubbleText
                                        Layout.fillWidth: true
                                        text: {
                                            if (role === "user" || role === "system") return content
                                            if (content.length <= 500) return content
                                            if (collapsed) return content.substring(0, 500) + "..."
                                            return content
                                        }
                                        textFormat: role === "assistant" || role === "tool"
                                                    ? TextEdit.MarkdownText
                                                    : TextEdit.PlainText
                                        font { pixelSize: 12; family: "Source Han Sans CN, Noto Sans CJK TC, sans-serif" }
                                        color: role === "user" ? "#ffffff" :
                                               role === "system" ? "#ef4444" : "#e0e0e0"
                                        wrapMode: TextEdit.WordWrap
                                        readOnly: true
                                        selectByMouse: true
                                        padding: 0
                                    }

                                    // Expand/collapse toggle for long messages
                                    FluTextButton {
                                        id: expandBtn
                                        Layout.fillWidth: true
                                        visible: (role === "assistant" || role === "tool") && content.length > 500
                                        text: collapsed ? "展开全部" : "收起"
                                        onClicked: {
                                            var idx = -1
                                            for (var i = 0; i < msgModel.count; i++) {
                                                if (msgModel.get(i).msgId === msgId) { idx = i; break }
                                            }
                                            if (idx >= 0) {
                                                var c = msgModel.get(idx).collapsed
                                                msgModel.setProperty(idx, "collapsed", !c)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Loading / streaming indicator
                    RowLayout {
                        Layout.leftMargin: 16
                        spacing: 8
                        visible: chat.loading || chat.streaming

                        FluText {
                            text: chat.streaming ? "接收中..." : chat.agentMode ? "Agent 思考中..." : "思考中..."
                            font.pixelSize: 12
                            textColor: "#8ea1ad"
                        }

                        FluButton {
                            text: "停止"
                            visible: chat.loading
                            font.pixelSize: 11
                            onClicked: chat.stopGeneration()
                        }
                    }

                    Item { Layout.fillWidth: true; implicitHeight: 8; visible: msgModel.count > 0 }
                }
            }

            // ---- Input area ----
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
                        placeholderText: chat.agentMode
                            ? "输入任务... (Enter 发送, Shift+Enter 换行)"
                            : "输入消息... (Enter 发送, Shift+Enter 换行)"
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
                            msgModel.append({msgId: genId(), role: "user", content: txt, isStep: false, stepStatus: "", stepSuccess: false, stepResult: "", collapsed: false})
                            chat.sendMessage(txt)
                            inputBox.text = ""
                            scrollToBottom()
                        }
                    }
                }
            }
        }
    }

    // ---- Scroll helper ----
    Timer {
        id: scrollTimer
        interval: 80
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
