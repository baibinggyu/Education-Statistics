import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import FluentUI
import EduStat.Backend 1.0

// 作业管理 Assignment Management Page
Item {
    id: assignmentPage
    required property ApiClient requiredApiClient
    required property string requiredCourseUuid

    property var assignmentsData: ([])
    property var submissionsData: ([])
    property string selectedAssignmentUuid: ""
    property var selectedAssignmentData: ({})
    property string sortOrder: "newest"

    // Calendar state
    property string dueDateText: ""
    property int calendarYear: 2026
    property int calendarMonth: 5
    property int calendarDay: 0
    property int selectedHour: 23
    property int selectedMinute: 59

    // Publish form expand state
    property bool publishFormExpanded: false

    // Submission loading state
    property bool loadingSubmissions: false

    // Course members (for unsubmitted tracking)
    property var courseMembersData: ([])

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

    // -------------------------------------------------------
    // Backend signals
    // -------------------------------------------------------
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
            publishFormExpanded = false
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
        function onSubmissionListReset() { submissionsData = []; loadingSubmissions = true }
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
            if (selectedAssignmentUuid) {
                requiredApiClient.fetchSubmissions(requiredCourseUuid, selectedAssignmentUuid)
            }
        }
        function onSubmissionsListDone() { loadingSubmissions = false }
        function onSubmissionsError(msg) { loadingSubmissions = false; console.log("Submissions error:", msg) }
        function onSubmissionGradeError(msg) {
            console.log("Grade error:", msg)
        }

        // --- Course Members ---
        function onCourseMembersReset() { courseMembersData = [] }
        function onCourseMemberListed(userUuid, username, memberRole, joinedAt, studentNo, realName) {
            courseMembersData.push({
                userUuid: userUuid, username: username, memberRole: memberRole,
                joinedAt: joinedAt, studentNo: studentNo, realName: realName
            })
            courseMembersDataChanged()
        }

        // --- Announcements ---
        function onAnnouncementPublished(uuid, title) {
            console.log("Reminder announcement published:", title)
        }
        function onAnnouncementPublishError(msg) {
            console.log("Reminder announcement error:", msg)
        }
    }

    // -------------------------------------------------------
    // Helpers
    // -------------------------------------------------------
    function daysInMonth(year, month) {
        return new Date(year, month, 0).getDate()
    }
    function firstDayOfWeek(year, month) {
        var d = new Date(year, month - 1, 1)
        var w = d.getDay()
        return w === 0 ? 6 : w - 1
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
            list.sort(function(a, b) { return (a.createdAt || "").localeCompare(b.createdAt || "") })
        } else {
            list.sort(function(a, b) { return (b.createdAt || "").localeCompare(a.createdAt || "") })
        }
        return list
    }

    function getStatusLabel(s) {
        if (s === "submitted") return "已提交"
        if (s === "late") return "迟交"
        if (s === "graded") return "已批改"
        if (s === "unsubmitted") return "未提交"
        return "草稿"
    }
    function getStatusColor(s) {
        if (s === "submitted") return "#22c55e"
        if (s === "late") return "#f59e0b"
        if (s === "graded") return "#0f766e"
        if (s === "unsubmitted") return "#f59e0b"
        return "#8ea1ad"
    }
    function isImageFile(name) {
        if (!name) return false
        var ext = name.split('.').pop().toLowerCase()
        return ext === "jpg" || ext === "jpeg" || ext === "png"
            || ext === "gif" || ext === "webp" || ext === "bmp"
    }
    function isVideoFile(name) {
        if (!name) return false
        var ext = name.split('.').pop().toLowerCase()
        return ext === "mp4" || ext === "mkv" || ext === "webm"
            || ext === "mov" || ext === "avi"
    }
    function fileDownloadUrl(submissionUuid) {
        return requiredApiClient.serverUrl + "/api/courses/" + requiredCourseUuid
            + "/assignments/" + selectedAssignmentUuid + "/submissions/" + submissionUuid
            + "/file?token=" + requiredApiClient.token
    }

    // -------------------------------------------------------
    // StackView
    // -------------------------------------------------------
    StackView {
        id: stackView
        anchors.fill: parent
        initialItem: assignmentListPage
    }

    // ==========================================================
    // MAIN PAGE — Assignment List + Publish Form
    // ==========================================================
    Component {
        id: assignmentListPage

        Item {
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                // ---- Header ----
                RowLayout {
                    Layout.fillWidth: true
                    FluText {
                        text: "作业管理"
                        font.pixelSize: 18
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    FluFilledButton {
                        text: publishFormExpanded ? "收起发布" : "布置作业"
                        font.pixelSize: 12
                        onClicked: publishFormExpanded = !publishFormExpanded
                    }
                }

                // ---- Publish Form (collapsible) ----
                FluFrame {
                    visible: publishFormExpanded
                    Layout.fillWidth: true
                    radius: 12
                    padding: 20
                    implicitHeight: publishFormCol.implicitHeight + 40

                    ColumnLayout {
                        id: publishFormCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        spacing: 12

                        FluText {
                            text: "针对当前课程布置作业，选课学生可在移动端查看并提交。"
                            font.pixelSize: 11
                            textColor: "#8ea1ad"
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        FluDivider { Layout.fillWidth: true }

                        FluText { text: "作业标题"; font.pixelSize: 12; textColor: "#b3c0c8" }
                        FluTextBox {
                            id: titleInput
                            Layout.fillWidth: true
                            placeholderText: "请输入作业标题"
                        }

                        FluText { text: "作业内容"; font.pixelSize: 12; textColor: "#b3c0c8" }
                        FluMultilineTextBox {
                            id: descriptionInput
                            Layout.fillWidth: true
                            Layout.preferredHeight: 140
                            placeholderText: "请输入作业要求..."
                            wrapMode: Text.WordWrap
                        }

                        FluText { text: "截止日期（可选）"; font.pixelSize: 12; textColor: "#b3c0c8" }
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
                                onClicked: { dueDateText = ""; calendarDay = 0 }
                            }
                        }

                        FluText { text: "满分（可选）"; font.pixelSize: 12; textColor: "#b3c0c8" }
                        FluTextBox {
                            id: pointsInput
                            Layout.fillWidth: true
                            text: "100"
                            placeholderText: "如 100"
                        }

                        FluFilledButton {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
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

                // ---- Sort toggle ----
                RowLayout {
                    Layout.fillWidth: true
                    visible: !publishFormExpanded
                    FluText {
                        text: "已发布作业"
                        font.pixelSize: 16
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

                // ---- Assignment List ----
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
                                implicitHeight: 56
                                radius: 8
                                color: index % 2 === 0
                                    ? "transparent"
                                    : Qt.rgba(255,255,255,0.03)
                                border.color: Qt.rgba(255,255,255,0.06)
                                border.width: 1

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        assignmentPage.selectedAssignmentUuid = modelData.uuid
                                        assignmentPage.selectedAssignmentData = modelData
                                        stackView.push(assignmentDetailPage, {
                                            assignmentData: modelData
                                        })
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
                                        padding: 4
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
                                            assignmentPage.requiredApiClient.deleteAssignment(
                                                assignmentPage.requiredCourseUuid,
                                                modelData.uuid)
                                        }
                                    }
                                }
                            }
                        }

                        // Empty placeholder
                        FluText {
                            visible: displayAssignments.length === 0
                            text: "暂无作业，点击「布置作业」开始"
                            font.pixelSize: 12
                            textColor: "#53636d"
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 40
                        }
                    }
                }
            }
        }
    }

    // ==========================================================
    // DETAIL PAGE — Assignment info + Submissions with filter & detail popup
    // ==========================================================
    Component {
        id: assignmentDetailPage

        Item {
            property var assignmentData: ({})
            property string submissionFilter: "all"  // "all" | "ungraded" | "graded" | "unsubmitted"
            property var filteredSubmissions: []

            Component.onCompleted: {
                assignmentPage.requiredApiClient.fetchCourseMembers(
                    assignmentPage.requiredCourseUuid)
                assignmentPage.requiredApiClient.fetchSubmissions(
                    assignmentPage.requiredCourseUuid,
                    assignmentPage.selectedAssignmentUuid)
            }

            // ---------------------------------------------------
            // Filter helpers
            // ---------------------------------------------------
            function refreshFilter() {
                var all = assignmentPage.submissionsData
                var result
                if (submissionFilter === "ungraded") {
                    result = []
                    for (var i = 0; i < all.length; i++) {
                        if (all[i].status !== "graded") result.push(all[i])
                    }
                } else if (submissionFilter === "graded") {
                    result = []
                    for (var i = 0; i < all.length; i++) {
                        if (all[i].status === "graded") result.push(all[i])
                    }
                } else if (submissionFilter === "unsubmitted") {
                    result = []
                    var members = assignmentPage.courseMembersData
                    for (var i = 0; i < members.length; i++) {
                        if (members[i].memberRole !== "student") continue
                        var found = false
                        for (var j = 0; j < all.length; j++) {
                            if (all[j].studentUuid === members[i].userUuid) {
                                found = true; break
                            }
                        }
                        if (!found) {
                            result.push({
                                studentUuid: members[i].userUuid,
                                studentName: members[i].realName || members[i].username,
                                studentNo: members[i].studentNo || "",
                                status: "unsubmitted"
                            })
                        }
                    }
                } else {
                    result = all.slice()  // copy to force change detection
                }
                filteredSubmissions = result
            }
            onSubmissionFilterChanged: refreshFilter()

            Connections {
                target: assignmentPage
                function onSubmissionsDataChanged() { refreshFilter() }
                function onCourseMembersDataChanged() { refreshFilter() }
            }

            // Counts
            property int allCount: assignmentPage.submissionsData.length
            property int ungradedCount: {
                var c = 0
                var d = assignmentPage.submissionsData
                for (var i = 0; i < d.length; i++) {
                    if (d[i].status !== "graded") c++
                }
                return c
            }
            property int gradedCount: allCount - ungradedCount
            property int unsubmittedCount: {
                var c = 0
                var all = assignmentPage.submissionsData
                var members = assignmentPage.courseMembersData
                for (var i = 0; i < members.length; i++) {
                    if (members[i].memberRole !== "student") continue
                    var found = false
                    for (var j = 0; j < all.length; j++) {
                        if (all[j].studentUuid === members[i].userUuid) {
                            found = true; break
                        }
                    }
                    if (!found) c++
                }
                return c
            }

            function formatTime(dateStr) {
                if (!dateStr) return ""
                return dateStr.length >= 16 ? dateStr.substring(0, 16).replace("T", " ") : dateStr
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                // ---- Top bar with back button ----
                RowLayout {
                    Layout.fillWidth: true
                    FluIconButton {
                        iconSource: FluentIcons.ChromeBack
                        width: 36; height: 36
                        onClicked: {
                            assignmentPage.selectedAssignmentUuid = ""
                            assignmentPage.selectedAssignmentData = ({})
                            assignmentPage.submissionsData = []
                            stackView.pop()
                        }
                    }
                    FluText {
                        text: assignmentData.title || "作业详情"
                        font.pixelSize: 18
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    FluFrame {
                        radius: 4
                        color: (assignmentData.status === "open"
                            ? Qt.rgba(34/255, 197/255, 94/255, 0.15)
                            : Qt.rgba(255,255,255,0.08))
                        padding: 6
                        FluText {
                            text: assignmentData.status === "open" ? "进行中" : "已截止"
                            font.pixelSize: 10
                            textColor: assignmentData.status === "open" ? "#22c55e" : "#53636d"
                        }
                    }
                }

                // ---- Assignment info card ----
                FluFrame {
                    Layout.fillWidth: true
                    radius: 10
                    padding: 14
                    implicitHeight: infoCol.implicitHeight + 28

                    ColumnLayout {
                        id: infoCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        spacing: 6

                        FluText {
                            visible: assignmentData.description
                            Layout.fillWidth: true
                            text: assignmentData.description || ""
                            font.pixelSize: 12
                            textColor: "#b3c0c8"
                            wrapMode: Text.WordWrap
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16
                            FluText {
                                text: "截止: " + (assignmentData.dueDate
                                    ? assignmentData.dueDate.substring(0, 16) : "无")
                                font.pixelSize: 11
                                textColor: "#8ea1ad"
                            }
                            FluText {
                                text: "满分: " + (assignmentData.totalPoints != null
                                    ? (typeof assignmentData.totalPoints === "number"
                                        ? assignmentData.totalPoints.toFixed(0)
                                        : assignmentData.totalPoints)
                                    : "100")
                                font.pixelSize: 11
                                textColor: "#8ea1ad"
                            }
                            FluText {
                                text: "已提交: " + (assignmentData.submissionCount || 0) + " 份"
                                font.pixelSize: 11
                                textColor: "#8ea1ad"
                            }
                        }
                    }
                }

                // ---- Filter tabs ----
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Rectangle {
                        implicitWidth: tabAllText.implicitWidth + 28
                        implicitHeight: 32
                        radius: 6
                        color: submissionFilter === "all"
                            ? Qt.rgba(15/255, 118/255, 110/255, 0.2)
                            : "transparent"
                        FluText {
                            id: tabAllText
                            anchors.centerIn: parent
                            text: "全部 " + allCount
                            font.pixelSize: 11
                            textColor: submissionFilter === "all" ? "#0f766e" : "#8ea1ad"
                            font.bold: submissionFilter === "all"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: submissionFilter = "all"
                        }
                    }
                    Rectangle {
                        implicitWidth: tabUngradedText.implicitWidth + 28
                        implicitHeight: 32
                        radius: 6
                        color: submissionFilter === "ungraded"
                            ? Qt.rgba(239/255, 68/255, 68/255, 0.15)
                            : "transparent"
                        FluText {
                            id: tabUngradedText
                            anchors.centerIn: parent
                            text: "待批改 " + ungradedCount
                            font.pixelSize: 11
                            textColor: submissionFilter === "ungraded" ? "#ef4444" : "#8ea1ad"
                            font.bold: submissionFilter === "ungraded"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: submissionFilter = "ungraded"
                        }
                    }
                    Rectangle {
                        implicitWidth: tabGradedText.implicitWidth + 28
                        implicitHeight: 32
                        radius: 6
                        color: submissionFilter === "graded"
                            ? Qt.rgba(34/255, 197/255, 94/255, 0.15)
                            : "transparent"
                        FluText {
                            id: tabGradedText
                            anchors.centerIn: parent
                            text: "已批改 " + gradedCount
                            font.pixelSize: 11
                            textColor: submissionFilter === "graded" ? "#22c55e" : "#8ea1ad"
                            font.bold: submissionFilter === "graded"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: submissionFilter = "graded"
                        }
                    }
                    Rectangle {
                        implicitWidth: tabUnsubText.implicitWidth + 28
                        implicitHeight: 32
                        radius: 6
                        color: submissionFilter === "unsubmitted"
                            ? Qt.rgba(255/255, 165/255, 0, 0.15)
                            : "transparent"
                        FluText {
                            id: tabUnsubText
                            anchors.centerIn: parent
                            text: "未提交 " + unsubmittedCount
                            font.pixelSize: 11
                            textColor: submissionFilter === "unsubmitted" ? "#f59e0b" : "#8ea1ad"
                            font.bold: submissionFilter === "unsubmitted"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: submissionFilter = "unsubmitted"
                        }
                    }
                    Item { Layout.fillWidth: true }
                    FluFilledButton {
                        visible: unsubmittedCount > 0
                        text: "一键提醒交作业"
                        font.pixelSize: 11
                        onClicked: {
                            assignmentPage.requiredApiClient.publishAnnouncement(
                                assignmentPage.requiredCourseUuid,
                                "交作业提醒",
                                "请尽快提交作业「" + (assignmentData.title || "") + "」" +
                                (assignmentData.dueDate
                                    ? "，截止时间: " + assignmentData.dueDate.substring(0, 16) : "") +
                                "。目前已有 " + allCount + " 人提交，还有 " + unsubmittedCount + " 人未提交。",
                                "作业提醒", false, true)
                        }
                    }
                }

                FluDivider { Layout.fillWidth: true }

                // ---- Submissions list ----
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // Loading spinner
                    Rectangle {
                        visible: assignmentPage.loadingSubmissions
                        anchors.centerIn: parent
                        width: 80; height: 80
                        radius: 10
                        color: Qt.rgba(255,255,255,0.03)
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 8
                            FluText {
                                text: "\u23F3"
                                font.pixelSize: 28
                                Layout.alignment: Qt.AlignHCenter
                            }
                            FluText {
                                text: "加载中..."
                                font.pixelSize: 11
                                textColor: "#8ea1ad"
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }

                    ScrollView {
                        id: submissionsScroll
                        visible: !assignmentPage.loadingSubmissions
                        anchors.fill: parent
                        clip: true
                        ScrollBar.vertical: FluScrollBar {}

                        ColumnLayout {
                            width: submissionsScroll.availableWidth
                            spacing: 8

                        Repeater {
                            model: filteredSubmissions

                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                implicitHeight: 52
                                radius: 8
                                color: index % 2 === 0
                                    ? "transparent"
                                    : Qt.rgba(255,255,255,0.03)

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: modelData.status !== "unsubmitted"
                                        ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        if (modelData.status === "unsubmitted") return
                                        submissionDetailPopup.currentSubmission = modelData
                                        submissionDetailPopup.open()
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    // Avatar circle
                                    Rectangle {
                                        width: 32; height: 32
                                        radius: 16
                                        color: Qt.rgba(15/255, 118/255, 110/255, 0.25)
                                        FluText {
                                            anchors.centerIn: parent
                                            text: (modelData.studentName || "?")[0]
                                            font.pixelSize: 13
                                            font.bold: true
                                            textColor: "#0f766e"
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        FluText {
                                            Layout.fillWidth: true
                                            text: modelData.studentName || modelData.studentUuid
                                            font.pixelSize: 12
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }
                                        RowLayout {
                                            spacing: 8
                                            FluText {
                                                visible: modelData.studentNo ? true : false
                                                text: modelData.studentNo || ""
                                                font.pixelSize: 10
                                                textColor: "#8ea1ad"
                                            }
                                            FluText {
                                                visible: modelData.fileName ? true : false
                                                text: (assignmentPage.isImageFile(modelData.fileName)
                                                    ? "\uD83D\uDDBC " : "\uD83D\uDCCE ")
                                                    + (modelData.fileName || "")
                                                font.pixelSize: 10
                                                textColor: "#0f766e"
                                                elide: Text.ElideRight
                                                Layout.preferredWidth: 200
                                            }
                                        }
                                    }

                                    // Score badge (if graded)
                                    FluFrame {
                                        visible: modelData.status === "graded"
                                        radius: 4
                                        color: modelData.score >= 60
                                            ? Qt.rgba(34/255, 197/255, 94/255, 0.15)
                                            : Qt.rgba(239/255, 68/255, 68/255, 0.15)
                                        padding: 5
                                        FluText {
                                            text: (modelData.score != null
                                                ? modelData.score.toFixed(1) : "--") + "分"
                                            font.pixelSize: 11
                                            font.bold: true
                                            textColor: modelData.score >= 60 ? "#22c55e" : "#ef4444"
                                        }
                                    }

                                    // Status badge
                                    FluFrame {
                                        visible: modelData.status !== "graded"
                                        radius: 4
                                        color: Qt.rgba(0,0,0,0.1)
                                        padding: 5
                                        FluText {
                                            text: assignmentPage.getStatusLabel(modelData.status)
                                            font.pixelSize: 10
                                            textColor: assignmentPage.getStatusColor(modelData.status)
                                        }
                                    }
                                }
                            }
                        }

                        // Empty state
                        FluText {
                            visible: filteredSubmissions.length === 0
                                && assignmentPage.submissionsData.length === 0
                            text: "暂无提交"
                            font.pixelSize: 12
                            textColor: "#53636d"
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 30
                        }
                        FluText {
                            visible: filteredSubmissions.length === 0
                                && assignmentPage.submissionsData.length > 0
                            text: submissionFilter === "ungraded" ? "所有提交均已批改"
                                : submissionFilter === "graded" ? "暂无已批改的提交"
                                : submissionFilter === "unsubmitted" ? "所有学生均已提交"
                                : ""
                            font.pixelSize: 12
                            textColor: "#53636d"
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 30
                        }
                    }
                }
                }  // close Item wrapper
            }

            // ======================================================
            // Submission Detail Popup — enlarged full view
            // ======================================================
            Popup {
                id: submissionDetailPopup
                parent: Overlay.overlay
                anchors.centerIn: parent
                width: Math.min(680, parent.width - 40)
                height: Math.min(620, parent.height - 40)
                modal: true
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                property var currentSubmission: ({})

                background: Rectangle {
                    color: Qt.rgba(28/255, 31/255, 36/255, 1)
                    radius: 12
                    border.color: Qt.rgba(255,255,255,0.08)
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 10

                    // ---- Header ----
                    RowLayout {
                        Layout.fillWidth: true
                        Rectangle {
                            width: 40; height: 40; radius: 20
                            color: Qt.rgba(15/255, 118/255, 110/255, 0.25)
                            FluText {
                                anchors.centerIn: parent
                                text: (submissionDetailPopup.currentSubmission.studentName
                                    || "?")[0]
                                font.pixelSize: 16
                                font.bold: true
                                textColor: "#0f766e"
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            FluText {
                                text: submissionDetailPopup.currentSubmission.studentName
                                    || submissionDetailPopup.currentSubmission.studentUuid || ""
                                font.pixelSize: 14
                                font.bold: true
                            }
                            FluText {
                                visible: submissionDetailPopup.currentSubmission.studentNo ? true : false
                                text: "学号: " + (submissionDetailPopup.currentSubmission.studentNo || "")
                                font.pixelSize: 11
                                textColor: "#8ea1ad"
                            }
                        }
                        FluFrame {
                            radius: 4
                            color: Qt.rgba(0,0,0,0.1)
                            padding: 5
                            FluText {
                                text: assignmentPage.getStatusLabel(
                                    submissionDetailPopup.currentSubmission.status || "")
                                font.pixelSize: 10
                                textColor: assignmentPage.getStatusColor(
                                    submissionDetailPopup.currentSubmission.status || "")
                            }
                        }
                        FluFrame {
                            visible: submissionDetailPopup.currentSubmission.submittedAt ? true : false
                            radius: 4
                            color: Qt.rgba(255,255,255,0.05)
                            padding: 5
                            FluText {
                                text: formatTime(submissionDetailPopup.currentSubmission.submittedAt || "")
                                font.pixelSize: 10
                                textColor: "#8ea1ad"
                            }
                        }
                        FluIconButton {
                            iconSource: FluentIcons.ChromeClose
                            width: 32; height: 32
                            onClicked: submissionDetailPopup.close()
                        }
                    }

                    FluDivider { Layout.fillWidth: true }

                    // ---- Content area (fills remaining space) ----
                    ScrollView {
                        id: popupScrollView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        ScrollBar.vertical: FluScrollBar {}

                        ColumnLayout {
                            width: popupScrollView.availableWidth
                            spacing: 14

                            // Text content
                            FluText {
                                visible: submissionDetailPopup.currentSubmission.content ? true : false
                                Layout.fillWidth: true
                                text: submissionDetailPopup.currentSubmission.content || ""
                                font.pixelSize: 12
                                textColor: "#c0c8d0"
                                wrapMode: Text.WordWrap
                            }

                            // Full-size image
                            Rectangle {
                                visible: assignmentPage.isImageFile(
                                    submissionDetailPopup.currentSubmission.fileName)
                                Layout.fillWidth: true
                                implicitHeight: 360
                                radius: 10
                                color: Qt.rgba(0,0,0,0.25)
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    source: assignmentPage.fileDownloadUrl(
                                        submissionDetailPopup.currentSubmission.uuid || "")
                                    fillMode: Image.PreserveAspectFit
                                    cache: false
                                    smooth: true
                                }

                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 8
                                    width: 36; height: 36; radius: 18
                                    color: Qt.rgba(0,0,0,0.6)
                                    FluText {
                                        anchors.centerIn: parent
                                        text: "\u26F6"
                                        font.pixelSize: 16
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Qt.openUrlExternally(assignmentPage.fileDownloadUrl(
                                                submissionDetailPopup.currentSubmission.uuid || ""))
                                        }
                                    }
                                }
                            }

                            // Video area
                            Rectangle {
                                visible: assignmentPage.isVideoFile(
                                    submissionDetailPopup.currentSubmission.fileName)
                                Layout.fillWidth: true
                                implicitHeight: 200
                                radius: 10
                                color: Qt.rgba(0,0,0,0.3)
                                border.color: Qt.rgba(255,255,255,0.06)

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 12
                                    Rectangle {
                                        width: 56; height: 56; radius: 28
                                        color: Qt.rgba(15/255, 118/255, 110/255, 0.3)
                                        Layout.alignment: Qt.AlignHCenter
                                        FluText {
                                            anchors.centerIn: parent
                                            text: "\u25B6"
                                            font.pixelSize: 24
                                            textColor: "#0f766e"
                                        }
                                    }
                                    FluText {
                                        text: submissionDetailPopup.currentSubmission.fileName || "视频文件"
                                        font.pixelSize: 12
                                        textColor: "#b3c0c8"
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    FluFilledButton {
                                        text: "在播放器中打开"
                                        font.pixelSize: 12
                                        Layout.alignment: Qt.AlignHCenter
                                        onClicked: {
                                            Qt.openUrlExternally(assignmentPage.fileDownloadUrl(
                                                submissionDetailPopup.currentSubmission.uuid || ""))
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Qt.openUrlExternally(assignmentPage.fileDownloadUrl(
                                            submissionDetailPopup.currentSubmission.uuid || ""))
                                    }
                                }
                            }

                            // Other file
                            RowLayout {
                                visible: (submissionDetailPopup.currentSubmission.fileName ? true : false)
                                    && !assignmentPage.isImageFile(
                                        submissionDetailPopup.currentSubmission.fileName || "")
                                    && !assignmentPage.isVideoFile(
                                        submissionDetailPopup.currentSubmission.fileName || "")
                                Layout.fillWidth: true
                                spacing: 10

                                FluFrame {
                                    radius: 8
                                    color: Qt.rgba(15/255, 118/255, 110/255, 0.12)
                                    padding: 12
                                    Layout.fillWidth: true
                                    RowLayout {
                                        anchors.fill: parent
                                        spacing: 8
                                        FluText {
                                            text: "\uD83D\uDCC4"
                                            font.pixelSize: 20
                                        }
                                        FluText {
                                            text: submissionDetailPopup.currentSubmission.fileName || "附件"
                                            font.pixelSize: 12
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }
                                        FluTextButton {
                                            text: "下载"
                                            font.pixelSize: 11
                                            onClicked: {
                                                Qt.openUrlExternally(assignmentPage.fileDownloadUrl(
                                                    submissionDetailPopup.currentSubmission.uuid || ""))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ---- Grading section (fixed at bottom) ----
                    FluDivider {
                        Layout.fillWidth: true
                        visible: submissionDetailPopup.currentSubmission.uuid ? true : false
                    }

                    // Grade result (if graded)
                    FluFrame {
                        visible: submissionDetailPopup.currentSubmission.status === "graded"
                        Layout.fillWidth: true
                        radius: 8
                        color: submissionDetailPopup.currentSubmission.score >= 60
                            ? Qt.rgba(34/255, 197/255, 94/255, 0.08)
                            : Qt.rgba(239/255, 68/255, 68/255, 0.08)
                        padding: 12

                        RowLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter

                            FluText {
                                text: "批改结果"
                                font.pixelSize: 13
                                font.bold: true
                            }
                            Item { Layout.fillWidth: true }
                            FluText {
                                visible: submissionDetailPopup.currentSubmission.feedback ? true : false
                                text: (submissionDetailPopup.currentSubmission.feedback || "")
                                font.pixelSize: 11
                                textColor: "#b3c0c8"
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            FluText {
                                text: (submissionDetailPopup.currentSubmission.score != null
                                    ? submissionDetailPopup.currentSubmission.score.toFixed(1)
                                    : "--") + " 分"
                                font.pixelSize: 18
                                font.bold: true
                                textColor: submissionDetailPopup.currentSubmission.score >= 60
                                    ? "#22c55e" : "#ef4444"
                            }
                        }
                    }

                    // Quick grading (if not graded)
                    RowLayout {
                        visible: (submissionDetailPopup.currentSubmission.uuid ? true : false)
                            && submissionDetailPopup.currentSubmission.status !== "graded"
                        Layout.fillWidth: true
                        spacing: 8

                        FluText { text: "评分"; font.pixelSize: 12; textColor: "#b3c0c8" }
                        FluTextBox {
                            id: popupScoreInput
                            Layout.preferredWidth: 80
                            font.pixelSize: 12
                            placeholderText: "分数"
                        }
                        FluTextBox {
                            id: popupFeedbackInput
                            Layout.fillWidth: true
                            font.pixelSize: 12
                            placeholderText: "反馈（可选）"
                        }
                        FluFilledButton {
                            text: "确认评分"
                            font.pixelSize: 12
                            onClicked: {
                                var s = parseFloat(popupScoreInput.text)
                                if (isNaN(s)) return
                                assignmentPage.requiredApiClient.gradeSubmission(
                                    assignmentPage.requiredCourseUuid,
                                    assignmentPage.selectedAssignmentUuid,
                                    submissionDetailPopup.currentSubmission.uuid, s,
                                    popupFeedbackInput.text.trim())
                                popupScoreInput.text = ""
                                popupFeedbackInput.text = ""
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- Calendar popup (shared) ----
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
                        if (calendarMonth === 1) { calendarMonth = 12; calendarYear-- }
                        else { calendarMonth-- }
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
                        if (calendarMonth === 12) { calendarMonth = 1; calendarYear++ }
                        else { calendarMonth++ }
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
                        var first = assignmentPage.firstDayOfWeek(calendarYear, calendarMonth)
                        var total = assignmentPage.daysInMonth(calendarYear, calendarMonth)
                        var prevTotal = assignmentPage.daysInMonth(
                            calendarMonth === 1 ? calendarYear - 1 : calendarYear,
                            calendarMonth === 1 ? 12 : calendarMonth - 1)
                        for (var i = first - 1; i >= 0; i--)
                            days.push({day: prevTotal - i, current: false})
                        for (var j = 1; j <= total; j++)
                            days.push({day: j, current: true})
                        var remaining = 42 - days.length
                        for (var k = 1; k <= remaining; k++)
                            days.push({day: k, current: false})
                        return days
                    }

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: 44; height: 36
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
                            onClicked: { calendarDay = modelData.day }
                        }
                    }
                }
            }

            FluDivider { Layout.fillWidth: true }

            // Time input
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                FluText { text: "时间"; font.pixelSize: 12; textColor: "#b3c0c8" }
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
                    onClicked: { dueDateText = ""; calendarDay = 0; calendarPopup.close() }
                }
                FluFilledButton {
                    text: "确定"
                    Layout.fillWidth: true
                    onClicked: assignmentPage.applyCalendarSelection()
                }
            }
        }
    }
}
