import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import FluentUI
import EduStat.Backend 1.0

// 作业管理 Assignment Management Page
Item {
    required property ApiClient requiredApiClient
    required property string requiredCourseUuid

    property var assignmentsData: ([])
    property var submissionsData: ([])
    property string selectedAssignmentUuid: ""
    property var selectedAssignmentData: ({})
    property string sortOrder: "newest"  // "newest" | "oldest"

    Component.onCompleted: {
        var now = new Date()
        calendarYear = now.getFullYear()
        calendarMonth = now.getMonth() + 1
        if (requiredCourseUuid) requiredApiClient.fetchAssignments(requiredCourseUuid)
    }

    onVisibleChanged: {
        if (visible && requiredCourseUuid) requiredApiClient.fetchAssignments(requiredCourseUuid)
    }

    onRequiredCourseUuidChanged: {
        if (visible && requiredCourseUuid) requiredApiClient.fetchAssignments(requiredCourseUuid)
    }

    Connections {
        target: requiredApiClient

        // --- Assignments ---
        function onAssignmentListReset() { assignmentsData = [] }
        function onAssignmentListed(uuid, title, description, dueDate, totalPoints,
                                     hasAttachment, attachmentName, status,
                                     authorName, submissionCount, createdAt) {
            assignmentsData.push({
                uuid: uuid, title: title, description: description,
                dueDate: dueDate, totalPoints: totalPoints,
                hasAttachment: hasAttachment, attachmentName: attachmentName,
                status: status, authorName: authorName,
                submissionCount: submissionCount, createdAt: createdAt
            })
            assignmentsDataChanged()
        }
        function onAssignmentPublished(uuid, title) {
            requiredApiClient.fetchAssignments(requiredCourseUuid)
        }
        function onAssignmentPublishError(msg) {
            console.log("Publish assignment error:", msg)
        }
        function onAssignmentDeleted(uuid) {
            if (selectedAssignmentUuid === uuid) {
                selectedAssignmentUuid = ""
                selectedAssignmentData = ({})
                submissionsData = []
            }
            requiredApiClient.fetchAssignments(requiredCourseUuid)
        }

        // --- Submissions ---
        function onSubmissionListReset() { submissionsData = [] }
        function onSubmissionListed(uuid, studentUuid, studentName, studentNo,
                                     content, fileName, submittedAt, score,
                                     feedback, status, createdAt) {
            submissionsData.push({
                uuid: uuid, studentUuid: studentUuid, studentName: studentName,
                studentNo: studentNo, content: content, fileName: fileName,
                submittedAt: submittedAt, score: score, feedback: feedback,
                status: status, createdAt: createdAt
            })
            submissionsDataChanged()
        }
        function onSubmissionGraded(uuid) {
            // Refresh submissions
            if (selectedAssignmentUuid) {
                requiredApiClient.fetchSubmissions(requiredCourseUuid, selectedAssignmentUuid)
            }
        }
        function onSubmissionGradeError(msg) {
            console.log("Grade error:", msg)
        }
    }

    // Sort assignments
    // Calendar state
    property string dueDateText: ""
    property int calendarYear: 2026
    property int calendarMonth: 5
    property int calendarDay: 0
    property int selectedHour: 23
    property int selectedMinute: 59

    function daysInMonth(year, month) {
        return new Date(year, month, 0).getDate()
    }
    function firstDayOfWeek(year, month) {
        var d = new Date(year, month - 1, 1)
        var w = d.getDay()
        return w === 0 ? 6 : w - 1  // Monday = 0
    }
    function applyCalendarSelection() {
        if (calendarDay > 0) {
            var m = String(calendarMonth).padStart(2, "0")
            var d = String(calendarDay).padStart(2, "0")
            var h = String(selectedHour).padStart(2, "0")
            var min = String(selectedMinute).padStart(2, "0")
            dueDateText = calendarYear + "-" + m + "-" + d + " " + h + ":" + min
        }
        calendarPopup.close()
    }

    property var displayAssignments: {
        var list = assignmentsData.slice()
        if (sortOrder === "oldest") {
            list.sort(function(a, b) {
                return (a.createdAt || "").localeCompare(b.createdAt || "")
            })
        } else {
            list.sort(function(a, b) {
                return (b.createdAt || "").localeCompare(a.createdAt || "")
            })
        }
        return list
    }

    function getStatusLabel(s) {
        if (s === "submitted") return "已提交"
        if (s === "late") return "迟交"
        if (s === "graded") return "已批改"
        return "草稿"
    }

    function getStatusColor(s) {
        if (s === "submitted") return "#22c55e"
        if (s === "late") return "#f59e0b"
        if (s === "graded") return "#0f766e"
        return "#8ea1ad"
    }

    RowLayout {
        anchors.fill: parent
        spacing: 24

        // Left: Publish form
        FluFrame {
            Layout.preferredWidth: 380
            Layout.fillHeight: true
            radius: 12

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 14

                FluText {
                    text: "布置作业"
                    font.pixelSize: 16
                    font.bold: true
                }

                FluText {
                    text: "针对当前课程布置作业，选课学生可在移动端查看并提交。"
                    font.pixelSize: 11
                    textColor: "#8ea1ad"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                FluDivider { Layout.fillWidth: true }

                FluText {
                    text: "作业标题"
                    font.pixelSize: 12
                    textColor: "#b3c0c8"
                }
                FluTextBox {
                    id: titleInput
                    Layout.fillWidth: true
                    placeholderText: "请输入作业标题"
                }

                FluText {
                    text: "作业内容"
                    font.pixelSize: 12
                    textColor: "#b3c0c8"
                }
                FluMultilineTextBox {
                    id: descriptionInput
                    Layout.fillWidth: true
                    Layout.preferredHeight: 160
                    placeholderText: "请输入作业要求..."
                    wrapMode: Text.WordWrap
                }

                FluText {
                    text: "截止日期（可选）"
                    font.pixelSize: 12
                    textColor: "#b3c0c8"
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    FluFrame {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: 6
                        color: Qt.rgba(255,255,255,0.05)
                        FluText {
                            anchors.centerIn: parent
                            text: dueDateText || "未设置"
                            font.pixelSize: 12
                            textColor: dueDateText ? "#ffffff" : "#53636d"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: calendarPopup.open()
                        }
                    }
                    FluButton {
                        text: dueDateText ? "修改" : "选择日期"
                        font.pixelSize: 11
                        onClicked: {
                            if (dueDateText) {
                                var parts = dueDateText.split(" ")
                                var dateParts = parts[0].split("-")
                                calendarYear = parseInt(dateParts[0])
                                calendarMonth = parseInt(dateParts[1])
                                calendarDay = parseInt(dateParts[2])
                                if (parts.length > 1) {
                                    var timeParts = parts[1].split(":")
                                    selectedHour = parseInt(timeParts[0])
                                    selectedMinute = parseInt(timeParts[1])
                                }
                            } else {
                                var now = new Date()
                                calendarYear = now.getFullYear()
                                calendarMonth = now.getMonth() + 1
                                calendarDay = 0
                                selectedHour = 23
                                selectedMinute = 59
                            }
                            calendarPopup.open()
                        }
                    }
                    FluButton {
                        visible: dueDateText !== ""
                        text: "清除"
                        font.pixelSize: 11
                        onClicked: {
                            dueDateText = ""
                            calendarDay = 0
                        }
                    }
                }

                FluText {
                    text: "满分（可选）"
                    font.pixelSize: 12
                    textColor: "#b3c0c8"
                }
                FluTextBox {
                    id: pointsInput
                    Layout.fillWidth: true
                    text: "100"
                    placeholderText: "如 100"
                }

                Item { Layout.fillHeight: true }

                FluFilledButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    text: "发 布 作 业"
                    font.pixelSize: 14
                    font.bold: true
                    onClicked: {
                        var t = titleInput.text.trim()
                        if (!t) return
                        var pts = parseFloat(pointsInput.text)
                        if (isNaN(pts)) pts = 100
                        requiredApiClient.publishAssignment(
                            requiredCourseUuid, t,
                            descriptionInput.text.trim(),
                            dueDateText, pts)
                        titleInput.text = ""
                        descriptionInput.text = ""
                        dueDateText = ""
                        calendarDay = 0
                        pointsInput.text = "100"
                    }
                }
            }
        }

        // Right: Assignment list + submission detail
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                FluText {
                    text: "已发布作业"
                    font.pixelSize: 18
                    font.bold: true
                }
                Item { Layout.fillWidth: true }
                FluButton {
                    text: sortOrder === "newest" ? "最新优先" : "最早优先"
                    font.pixelSize: 11
                    onClicked: {
                        sortOrder = sortOrder === "newest" ? "oldest" : "newest"
                        displayAssignmentsChanged()
                    }
                }
            }

            ScrollView {
                id: assignmentScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.vertical: FluScrollBar {}

                ColumnLayout {
                    width: assignmentScroll.availableWidth
                    spacing: 8

                    Repeater {
                        model: displayAssignments

                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            height: selectedAssignmentUuid === modelData.uuid ? 52 : 48
                            color: selectedAssignmentUuid === modelData.uuid
                                ? Qt.rgba(15/255, 118/255, 110/255, 0.15)
                                : (index % 2 === 0 ? "transparent" : Qt.rgba(0,0,0,0.04))
                            radius: 6

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (selectedAssignmentUuid === modelData.uuid) {
                                        selectedAssignmentUuid = ""
                                        selectedAssignmentData = ({})
                                        submissionsData = []
                                    } else {
                                        selectedAssignmentUuid = modelData.uuid
                                        selectedAssignmentData = modelData
                                        requiredApiClient.fetchSubmissions(
                                            requiredCourseUuid, modelData.uuid)
                                    }
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 12

                                FluText {
                                    Layout.fillWidth: true
                                    text: modelData.title
                                    font.pixelSize: 13
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                FluFrame {
                                    radius: 4
                                    color: modelData.status === "open"
                                        ? Qt.rgba(34/255, 197/255, 94/255, 0.15)
                                        : Qt.rgba(255,255,255,0.08)
                                    padding: 3
                                    visible: true
                                    FluText {
                                        text: modelData.status === "open" ? "进行中" : "已关闭"
                                        font.pixelSize: 9
                                        textColor: modelData.status === "open" ? "#22c55e" : "#53636d"
                                    }
                                }

                                FluText {
                                    text: modelData.submissionCount + " 份提交"
                                    font.pixelSize: 10
                                    textColor: "#8ea1ad"
                                    Layout.preferredWidth: 70
                                }

                                FluText {
                                    text: modelData.dueDate
                                        ? modelData.dueDate.substring(0, 16)
                                        : "无截止"
                                    font.pixelSize: 10
                                    textColor: "#b3c0c8"
                                    Layout.preferredWidth: 120
                                }

                                FluIconButton {
                                    iconSource: FluentIcons.Delete
                                    width: 28; height: 28
                                    onClicked: {
                                        requiredApiClient.deleteAssignment(
                                            requiredCourseUuid, modelData.uuid)
                                    }
                                }
                            }
                        }
                    }

                    // Submission detail section
                    FluFrame {
                        visible: selectedAssignmentUuid !== ""
                        Layout.fillWidth: true
                        radius: 10
                        padding: 16
                        implicitHeight: submissionContent.implicitHeight + 32

                        ColumnLayout {
                            id: submissionContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            spacing: 12

                            FluText {
                                text: "提交列表 · " + (selectedAssignmentData.title || "")
                                font.pixelSize: 14
                                font.bold: true
                            }

                            FluDivider { Layout.fillWidth: true }

                            Repeater {
                                model: submissionsData

                                delegate: FluFrame {
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    radius: 8
                                    padding: 12
                                    implicitHeight: subCol.implicitHeight + 24

                                    ColumnLayout {
                                        id: subCol
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        spacing: 6

                                        RowLayout {
                                            Layout.fillWidth: true

                                            FluText {
                                                text: modelData.studentName || modelData.studentUuid
                                                font.pixelSize: 12
                                                font.bold: true
                                            }
                                            FluText {
                                                text: modelData.studentNo || ""
                                                font.pixelSize: 10
                                                textColor: "#8ea1ad"
                                            }
                                            Item { Layout.fillWidth: true }
                                            FluFrame {
                                                radius: 4
                                                color: getStatusColor(modelData.status)
                                                    ? Qt.rgba(0,0,0,0.1)
                                                    : Qt.rgba(255,255,255,0.08)
                                                padding: 3
                                                FluText {
                                                    text: getStatusLabel(modelData.status)
                                                    font.pixelSize: 9
                                                    textColor: getStatusColor(modelData.status)
                                                }
                                            }
                                        }

                                        FluText {
                                            visible: modelData.content
                                            Layout.fillWidth: true
                                            text: modelData.content || ""
                                            font.pixelSize: 11
                                            textColor: "#b3c0c8"
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 3
                                        }

                                        FluText {
                                            visible: modelData.fileName
                                            text: "附件: " + (modelData.fileName || "")
                                            font.pixelSize: 10
                                            textColor: "#8ea1ad"
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            visible: modelData.status !== "graded"

                                            FluTextBox {
                                                id: scoreInput
                                                Layout.preferredWidth: 80
                                                font.pixelSize: 11
                                                placeholderText: "分数"
                                            }
                                            FluTextBox {
                                                id: feedbackInput
                                                Layout.fillWidth: true
                                                font.pixelSize: 11
                                                placeholderText: "反馈（可选）"
                                            }
                                            FluFilledButton {
                                                text: "评分"
                                                font.pixelSize: 11
                                                onClicked: {
                                                    var s = parseFloat(scoreInput.text)
                                                    if (isNaN(s)) return
                                                    requiredApiClient.gradeSubmission(
                                                        requiredCourseUuid,
                                                        selectedAssignmentUuid,
                                                        modelData.uuid,
                                                        s,
                                                        feedbackInput.text.trim())
                                                    scoreInput.text = ""
                                                    feedbackInput.text = ""
                                                }
                                            }
                                        }

                                        RowLayout {
                                            visible: modelData.status === "graded"
                                            Layout.fillWidth: true
                                            FluText {
                                                text: "得分: " + (modelData.score != null ? modelData.score.toFixed(1) : "--")
                                                font.pixelSize: 13
                                                font.bold: true
                                                textColor: modelData.score >= 60 ? "#22c55e" : "#ef4444"
                                            }
                                            FluText {
                                                visible: modelData.feedback
                                                text: "反馈: " + (modelData.feedback || "")
                                                font.pixelSize: 11
                                                textColor: "#b3c0c8"
                                                Layout.fillWidth: true
                                                wrapMode: Text.WordWrap
                                            }
                                        }
                                    }
                                }
                            }

                            // No submissions placeholder
                            FluText {
                                visible: submissionsData.length === 0
                                text: "暂无提交"
                                font.pixelSize: 12
                                textColor: "#53636d"
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }

                    // Empty assignments placeholder
                    Label {
                        visible: displayAssignments.length === 0
                        text: "暂无作业"
                        color: "#53636d"
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }

    // Calendar popup
    Popup {
        id: calendarPopup
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 340
        height: 420
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: Qt.rgba(28/255, 31/255, 36/255, 1)
            radius: 12
            border.color: Qt.rgba(255,255,255,0.08)
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            // Month navigation
            RowLayout {
                Layout.fillWidth: true
                FluIconButton {
                    iconSource: FluentIcons.ChevronLeft
                    width: 32; height: 32
                    onClicked: {
                        if (calendarMonth === 1) {
                            calendarMonth = 12
                            calendarYear--
                        } else {
                            calendarMonth--
                        }
                    }
                }
                FluText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: calendarYear + " 年 " + calendarMonth + " 月"
                    font.pixelSize: 14
                    font.bold: true
                }
                FluIconButton {
                    iconSource: FluentIcons.ChevronRight
                    width: 32; height: 32
                    onClicked: {
                        if (calendarMonth === 12) {
                            calendarMonth = 1
                            calendarYear++
                        } else {
                            calendarMonth++
                        }
                    }
                }
            }

            FluDivider { Layout.fillWidth: true }

            // Day headers
            RowLayout {
                id: dayHeaderRow
                Layout.fillWidth: true
                spacing: 0
                property var dayNames: ["一", "二", "三", "四", "五", "六", "日"]
                Repeater {
                    model: 7
                    FluText {
                        Layout.preferredWidth: 44
                        horizontalAlignment: Text.AlignHCenter
                        text: dayHeaderRow.dayNames[index]
                        font.pixelSize: 11
                        textColor: "#8ea1ad"
                    }
                }
            }

            // Day grid
            GridLayout {
                Layout.fillWidth: true
                columns: 7
                rowSpacing: 2
                columnSpacing: 0

                Repeater {
                    model: {
                        var days = []
                        var first = firstDayOfWeek(calendarYear, calendarMonth)
                        var total = daysInMonth(calendarYear, calendarMonth)
                        var prevTotal = daysInMonth(
                            calendarMonth === 1 ? calendarYear - 1 : calendarYear,
                            calendarMonth === 1 ? 12 : calendarMonth - 1)
                        // Prev month trailing days
                        for (var i = first - 1; i >= 0; i--) {
                            days.push({day: prevTotal - i, current: false})
                        }
                        // Current month days
                        for (var j = 1; j <= total; j++) {
                            days.push({day: j, current: true})
                        }
                        // Next month leading days (fill 6 rows)
                        var remaining = 42 - days.length
                        for (var k = 1; k <= remaining; k++) {
                            days.push({day: k, current: false})
                        }
                        return days
                    }

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: 44
                        height: 36
                        radius: 6
                        color: {
                            if (!modelData.current) return "transparent"
                            var selected = modelData.day === calendarDay
                            if (selected) return Qt.rgba(15/255, 118/255, 110/255, 0.6)
                            return Qt.rgba(255,255,255,0.03)
                        }
                        FluText {
                            anchors.centerIn: parent
                            text: modelData.day
                            font.pixelSize: 12
                            textColor: modelData.current
                                ? (modelData.day === calendarDay ? "#ffffff" : "#cccccc")
                                : "#444444"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: modelData.current ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled: modelData.current
                            onClicked: {
                                calendarDay = modelData.day
                            }
                        }
                    }
                }
            }

            FluDivider { Layout.fillWidth: true }

            // Time input
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                FluText {
                    text: "时间"
                    font.pixelSize: 12
                    textColor: "#b3c0c8"
                }
                FluTextBox {
                    id: hourInput
                    Layout.preferredWidth: 60
                    text: String(selectedHour).padStart(2, "0")
                    validator: IntValidator { bottom: 0; top: 23 }
                    onTextChanged: {
                        var v = parseInt(text)
                        if (!isNaN(v)) selectedHour = v
                    }
                }
                FluText { text: ":"; font.pixelSize: 14; font.bold: true }
                FluTextBox {
                    id: minuteInput
                    Layout.preferredWidth: 60
                    text: String(selectedMinute).padStart(2, "0")
                    validator: IntValidator { bottom: 0; top: 59 }
                    onTextChanged: {
                        var v = parseInt(text)
                        if (!isNaN(v)) selectedMinute = v
                    }
                }
                Item { Layout.fillWidth: true }
            }

            Item { Layout.fillHeight: true }

            // Action buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                FluButton {
                    text: "清除"
                    Layout.fillWidth: true
                    onClicked: {
                        dueDateText = ""
                        calendarDay = 0
                        calendarPopup.close()
                    }
                }
                FluFilledButton {
                    text: "确定"
                    Layout.fillWidth: true
                    onClicked: applyCalendarSelection()
                }
            }
        }
    }
}
