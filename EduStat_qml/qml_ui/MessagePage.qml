import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import FluentUI
import EduStat.Backend 1.0

// QQ 风格消息页面 — 左侧联系人，右侧聊天气泡
Item {
    required property ApiClient requiredApiClient
    required property string requiredCourseUuid

    // ---- persistent contact list (course members) ----
    property var memberList: []

    // ---- current conversation ----
    property string chatWithUuid: ""
    property string chatWithName: ""
    property var conversationList: []

    // ---- helper: format time from ISO string ----
    function fmtTime(isoStr) {
        if (!isoStr) return ""
        var s = isoStr.toString()
        var idx = s.indexOf("T")
        if (idx < 0) return s.substring(0, 10)
        return s.substring(idx + 1, idx + 6)
    }

    // ---- Component lifecycle ----
    Component.onCompleted: {
        if (requiredCourseUuid) {
            requiredApiClient.fetchCourseMembers(requiredCourseUuid)
        }
    }

    onVisibleChanged: {
        if (visible && requiredCourseUuid) {
            requiredApiClient.fetchCourseMembers(requiredCourseUuid)
        }
    }

    onRequiredCourseUuidChanged: {
        conversationList = []
        chatWithUuid = ""
        chatWithName = ""
        if (requiredCourseUuid) {
            requiredApiClient.fetchCourseMembers(requiredCourseUuid)
        }
    }

    // ---- Server Connections ----
    Connections {
        target: requiredApiClient
        function onCourseMembersReset() { memberList = [] }
        function onCourseMemberListed(userUuid, username, memberRole, joinedAt, studentNo, realName) {
            memberList.push({
                userUuid: userUuid, username: username, memberRole: memberRole,
                studentNo: studentNo, realName: realName
            })
            memberListChanged()
        }

        function onMessageSent(uuid) {
            if (chatWithUuid) {
                requiredApiClient.fetchConversation(requiredCourseUuid, chatWithUuid)
            }
        }
        function onMessageSendError(msg) {
            console.log("Send error:", msg)
        }

        function onConversationReset() { conversationList = [] }
        function onConversationListed(uuid, senderUuid, senderName, content, msgType, isRead, subject, createdAt) {
            conversationList.push({
                uuid: uuid, senderUuid: senderUuid, senderName: senderName,
                content: content, msgType: msgType, isRead: isRead,
                subject: subject, createdAt: createdAt
            })
            conversationListChanged()
        }
        function onConversationListDone() {
            chatScrollTimer.start()
        }
        function onConversationError(msg) {
            console.log("Conversation error:", msg)
        }
    }

    // Auto-scroll to bottom after conversation loaded
    Timer {
        id: chatScrollTimer
        interval: 50
        onTriggered: {
            if (chatView.contentHeight > chatView.height)
                chatView.positionViewAtEnd()
        }
    }

    // ---- Open chat with a user ----
    function openChat(userUuid, userName) {
        chatWithUuid = userUuid
        chatWithName = userName
        conversationList = []
        if (requiredCourseUuid && userUuid) {
            requiredApiClient.fetchConversation(requiredCourseUuid, userUuid)
        }
    }

    // ---- Send message in current chat ----
    function sendChatMessage() {
        var content = chatInput.text.trim()
        if (!content || !chatWithUuid) return

        // Determine message type from combo
        var mtype = chatTypeCombo.model[chatTypeCombo.currentIndex]

        requiredApiClient.sendMessage(
            requiredCourseUuid, content, mtype, "", chatWithName)
        chatInput.text = ""
    }

    // ---- Who's the teacher? (properties so bindings track memberList) ----
    readonly property string teacherUuid: {
        for (var i = 0; i < memberList.length; i++) {
            if (memberList[i].memberRole === "teacher")
                return memberList[i].userUuid
        }
        return ""
    }

    readonly property string teacherName: {
        for (var i = 0; i < memberList.length; i++) {
            if (memberList[i].memberRole === "teacher")
                return memberList[i].realName || memberList[i].username
        }
        return "教师"
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ============================================================
        // Left: Contact list
        // ============================================================
        Rectangle {
            Layout.preferredWidth: 260
            Layout.fillHeight: true
            color: FluTheme.dark ? Qt.rgba(22/255, 25/255, 30/255, 1) : "#f5f5f5"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                // Search bar
                FluTextBox {
                    Layout.fillWidth: true
                    placeholderText: "搜索联系人..."
                }

                // Contact list
                ScrollView {
                    id: contactScroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    ScrollBar.vertical: FluScrollBar {}

                    ColumnLayout {
                        width: contactScroll.availableWidth
                        spacing: 2

                        // Teacher always first
                        Rectangle {
                            Layout.fillWidth: true
                            height: 56
                            radius: 8
                            color: chatWithUuid === teacherUuid
                                ? Qt.rgba(15/255, 118/255, 110/255, 0.15)
                                : (contactMouse.containsMouse ? Qt.rgba(255,255,255,0.05) : "transparent")

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                Rectangle {
                                    width: 40; height: 40; radius: 20
                                    color: "#0f766e"
                                    FluText {
                                        anchors.centerIn: parent
                                        text: "T"
                                        font.pixelSize: 16
                                        font.bold: true
                                        textColor: "#ffffff"
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    FluText {
                                        text: "教师（" + teacherName + "）"
                                        font.pixelSize: 12
                                        font.bold: true
                                    }
                                    FluText {
                                        text: "点击与教师对话"
                                        font.pixelSize: 10
                                        textColor: "#8ea1ad"
                                    }
                                }
                            }

                            MouseArea {
                                id: contactMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (teacherUuid) openChat(teacherUuid, teacherName)
                                }
                            }
                        }

                        // Students list
                        Repeater {
                            model: memberList

                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                visible: modelData.memberRole === "student"
                                Layout.fillWidth: true
                                height: 52
                                radius: 8
                                color: chatWithUuid === modelData.userUuid
                                    ? Qt.rgba(15/255, 118/255, 110/255, 0.15)
                                    : (stuMouse.containsMouse ? Qt.rgba(255,255,255,0.05) : "transparent")

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 10

                                    Rectangle {
                                        width: 38; height: 38; radius: 19
                                        color: "#555555"
                                        FluText {
                                            anchors.centerIn: parent
                                            text: (modelData.realName || modelData.username).charAt(0)
                                            font.pixelSize: 14
                                            font.bold: true
                                            textColor: "#ffffff"
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        FluText {
                                            text: modelData.realName || modelData.username
                                            font.pixelSize: 12
                                        }
                                        FluText {
                                            text: "学号: " + (modelData.studentNo || "未绑定")
                                            font.pixelSize: 9
                                            textColor: "#8ea1ad"
                                        }
                                    }
                                }

                                MouseArea {
                                    id: stuMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var name = modelData.realName || modelData.username
                                        openChat(modelData.userUuid, modelData.username)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Vertical divider
        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            color: FluTheme.dark ? Qt.rgba(255,255,255,0.08) : Qt.rgba(0,0,0,0.08)
        }

        // ============================================================
        // Right: Chat area
        // ============================================================
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Chat header
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                color: FluTheme.dark ? Qt.rgba(25/255, 29/255, 35/255, 1) : "#fafafa"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 10

                    FluText {
                        text: chatWithName || "选择联系人开始对话"
                        font.pixelSize: 14
                        font.bold: true
                    }

                    FluComboBox {
                        id: chatTypeCombo
                        visible: chatWithUuid !== ""
                        Layout.preferredWidth: 120
                        model: ["学习提醒", "作业通知", "考试安排", "课堂反馈", "其他"]
                        currentIndex: 0
                    }

                    Item { Layout.fillWidth: true }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: FluTheme.dark ? Qt.rgba(255,255,255,0.06) : Qt.rgba(0,0,0,0.06)
            }

            // Chat messages
            ScrollView {
                id: chatScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.vertical: FluScrollBar {}

                ColumnLayout {
                    id: chatView
                    width: chatScroll.availableWidth
                    spacing: 6

                    FluText {
                        Layout.alignment: Qt.AlignHCenter
                        visible: chatWithUuid === ""
                        text: "点击左侧联系人开始对话"
                        font.pixelSize: 13
                        textColor: "#53636d"
                        Layout.topMargin: 100
                    }

                    // Message bubbles
                    Repeater {
                        model: conversationList

                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.leftMargin: modelData.senderUuid === requiredApiClient.userUuid ? 60 : 8
                            Layout.rightMargin: modelData.senderUuid === requiredApiClient.userUuid ? 8 : 60

                            // layoutDirection trick to align bubbles left/right
                            layoutDirection: modelData.senderUuid === requiredApiClient.userUuid
                                ? Qt.RightToLeft : Qt.LeftToRight

                            FluFrame {
                                Layout.preferredWidth: Math.min(
                                    implicitWidth + 24, chatView.width * 0.7)
                                radius: 12
                                color: modelData.senderUuid === requiredApiClient.userUuid
                                    ? "#0f766e"
                                    : (FluTheme.dark ? Qt.rgba(40/255, 44/255, 50/255, 1)
                                                     : "#e8e8e8")
                                padding: 10

                                ColumnLayout {
                                    spacing: 4
                                    FluText {
                                        text: modelData.content
                                        font.pixelSize: 12
                                        textColor: modelData.senderUuid === requiredApiClient.userUuid
                                            ? "#ffffff" : "#edf6f4"
                                        wrapMode: Text.WordWrap
                                        Layout.maximumWidth: chatView.width * 0.7 - 48
                                    }
                                    RowLayout {
                                        spacing: 6
                                        FluText {
                                            text: modelData.senderName
                                            font.pixelSize: 9
                                            textColor: modelData.senderUuid === requiredApiClient.userUuid
                                                ? Qt.rgba(255,255,255,0.5) : "#8ea1ad"
                                        }
                                        FluText {
                                            text: fmtTime(modelData.createdAt)
                                            font.pixelSize: 9
                                            textColor: modelData.senderUuid === requiredApiClient.userUuid
                                                ? Qt.rgba(255,255,255,0.4) : "#53636d"
                                        }
                                    }
                                    FluFrame {
                                        visible: modelData.msgType !== ""
                                        radius: 3
                                        color: modelData.senderUuid === requiredApiClient.userUuid
                                            ? Qt.rgba(255,255,255,0.15)
                                            : Qt.rgba(15/255, 118/255, 110/255, 0.12)
                                        padding: 2
                                        FluText {
                                            text: modelData.msgType
                                            font.pixelSize: 8
                                            textColor: modelData.senderUuid === requiredApiClient.userUuid
                                                ? Qt.rgba(255,255,255,0.7) : "#0f766e"
                                        }
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }
                        }
                    }
                }
            }

            // Input bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                color: FluTheme.dark ? Qt.rgba(25/255, 29/255, 35/255, 1) : "#fafafa"

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: FluTheme.dark ? Qt.rgba(255,255,255,0.06) : Qt.rgba(0,0,0,0.06)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    FluTextBox {
                        id: chatInput
                        Layout.fillWidth: true
                        placeholderText: chatWithUuid
                            ? "输入消息..."
                            : "请先选择联系人"
                        enabled: chatWithUuid !== ""
                        onAccepted: sendChatMessage()
                    }

                    FluFilledButton {
                        Layout.preferredHeight: 36
                        Layout.preferredWidth: 80
                        text: "发送"
                        font.pixelSize: 12
                        font.bold: true
                        enabled: chatWithUuid !== "" && chatInput.text.trim() !== ""
                        onClicked: sendChatMessage()
                    }
                }
            }
        }
    }
}
