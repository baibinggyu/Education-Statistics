import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import FluentUI
import EduStat.Backend 1.0

// 点名 / 考勤签到 Roll Call & Attendance Page
Item {
    required property ApiClient requiredApiClient
    required property string requiredCourseUuid

    // ---- Random picker state ----
    property var allStudents: ([])
    property var roundHistory: ([])
    property var currentDrawResults: ([])
    property bool membersLoaded: false

    // ---- Attendance state ----
    property var attendancesData: ([])
    property var attendanceDetailData: (null)
    property var attendanceDetailRecords: ([])
    property string selectedAttendanceUuid: ""
    property bool attendanceLoading: false
    property bool detailLoading: false
    property bool showPhotoDialog: false
    property string photoUrl: ""
    property string photoTitle: ""

    // ---- UI state ----
    property int viewMode: 0  // 0 = random picker, 1 = attendance

    // ---- data loading ----
    Component.onCompleted: {
        if (requiredCourseUuid) {
            requiredApiClient.fetchCourseMembers(requiredCourseUuid)
            requiredApiClient.fetchAttendances(requiredCourseUuid)
        }
    }

    onRequiredCourseUuidChanged: {
        if (visible && requiredCourseUuid) {
            requiredApiClient.fetchCourseMembers(requiredCourseUuid)
            requiredApiClient.fetchAttendances(requiredCourseUuid)
        }
    }

    onVisibleChanged: {
        if (visible && requiredCourseUuid) {
            requiredApiClient.fetchCourseMembers(requiredCourseUuid)
            requiredApiClient.fetchAttendances(requiredCourseUuid)
        }
    }

    // ---- Connections ----
    Connections {
        target: requiredApiClient

        // Course members
        function onCourseMembersReset() { allStudents = [] }
        function onCourseMemberListed(userUuid, username, memberRole, joinedAt, studentNo, realName) {
            allStudents.push({
                user_uuid: userUuid,
                username: username,
                member_role: memberRole,
                student_no: studentNo || "",
                real_name: realName || ""
            })
            allStudentsChanged()
        }
        function onCourseMembersListDone() {
            membersLoaded = true
        }

        // Attendance list
        function onAttendanceListReset() { attendancesData = [] }
        function onAttendanceListed(uuid, title, status, total, presentCount, absentCount, lateCount, leaveCount, createdAt) {
            attendancesData.push({
                uuid: uuid,
                title: title,
                status: status,
                total: total,
                present_count: presentCount,
                absent_count: absentCount,
                late_count: lateCount,
                leave_count: leaveCount,
                created_at: createdAt
            })
            attendancesDataChanged()
        }
        function onAttendancesListDone() { attendanceLoading = false }

        // Attendance created
        function onAttendanceStarted(detail) {
            attendancesData.unshift({
                uuid: detail.uuid,
                title: detail.title,
                mode: detail.mode || "simple",
                status: detail.status,
                total: detail.total,
                present_count: detail.present_count,
                absent_count: detail.absent_count,
                late_count: detail.late_count,
                leave_count: detail.leave_count,
                created_at: detail.created_at
            })
            attendancesDataChanged()
            // Select the newly created session
            selectedAttendanceUuid = detail.uuid
            attendanceDetailData = detail
            attendanceDetailRecords = detail.records || []
            selectedAttendanceUuidChanged()
        }

        // Attendance detail
        function onAttendanceDetailFetched(detail) {
            attendanceDetailData = detail
            attendanceDetailRecords = detail.records || []
            detailLoading = false
        }
        function onAttendanceDetailError(msg) { detailLoading = false }

        // Attendance marked
        function onAttendanceMarked(record) {
            // Refresh detail
            if (selectedAttendanceUuid) {
                requiredApiClient.fetchAttendanceDetail(requiredCourseUuid, selectedAttendanceUuid)
            }
        }

        // Attendance closed
        function onAttendanceClosed(uuid) {
            // Update list
            for (var i = 0; i < attendancesData.length; i++) {
                if (attendancesData[i].uuid === uuid) {
                    attendancesData[i].status = "closed"
                    attendancesDataChanged()
                    break
                }
            }
            if (attendanceDetailData && attendanceDetailData.uuid === uuid) {
                attendanceDetailData.status = "closed"
                attendanceDetailDataChanged()
            }
        }
    }

    // ---- Student pool ----
    property var studentPool: {
        var arr = []
        for (var i = 0; i < allStudents.length; i++) {
            if (allStudents[i].member_role === "student") arr.push(allStudents[i])
        }
        return arr
    }

    // ---- Random picker functions ----
    function shuffleInPlace(arr) {
        for (var i = arr.length - 1; i > 0; i--) {
            var j = Math.floor(Math.random() * (i + 1))
            var tmp = arr[i]; arr[i] = arr[j]; arr[j] = tmp
        }
    }

    function pickRandom(pool, count, excludeList) {
        var available = []
        for (var i = 0; i < pool.length; i++) {
            var excluded = false
            for (var j = 0; j < excludeList.length; j++) {
                if (pool[i].user_uuid === excludeList[j].user_uuid) { excluded = true; break }
            }
            if (!excluded) available.push(pool[i])
        }
        if (available.length === 0) return []
        shuffleInPlace(available)
        return available.slice(0, Math.min(count, available.length))
    }

    function pickWeighted(pool, count, excludeList) {
        var fresh = []
        var used = []
        for (var i = 0; i < pool.length; i++) {
            var excluded = false
            for (var j = 0; j < excludeList.length; j++) {
                if (pool[i].user_uuid === excludeList[j].user_uuid) { excluded = true; break }
            }
            if (excluded) used.push(pool[i])
            else fresh.push(pool[i])
        }
        shuffleInPlace(fresh)
        shuffleInPlace(used)
        var result = fresh.slice(0, Math.min(count, fresh.length))
        if (result.length < count) {
            result = result.concat(used.slice(0, count - result.length))
        }
        return result
    }

    function doDraw() {
        var mode = drawMode.currentIndex
        var count = drawCountBox.value
        var pool = studentPool
        if (pool.length === 0) return

        var exclude = (mode === 2) ? roundHistory : []
        var picked
        if (mode === 0) {
            picked = pickRandom(pool, count, [])
        } else if (mode === 1) {
            picked = pickWeighted(pool, count, roundHistory)
        } else {
            picked = pickRandom(pool, count, roundHistory)
            if (picked.length < count) {
                var remaining = pickRandom(pool, count - picked.length, [])
                for (var r = 0; r < remaining.length; r++) picked.push(remaining[r])
            }
        }

        currentDrawResults = picked

        var newHistory = roundHistory.slice()
        for (var p = 0; p < picked.length; p++) {
            var dup = false
            for (var h = 0; h < newHistory.length; h++) {
                if (newHistory[h].user_uuid === picked[p].user_uuid) { dup = true; break }
            }
            if (!dup) newHistory.push(picked[p])
        }
        roundHistory = newHistory
    }

    function resetRound() {
        roundHistory = []
        currentDrawResults = []
    }

    // ---- Attendance helpers ----
    function getStatusLabel(s) {
        if (s === "present") return "已到"
        if (s === "absent") return "缺席"
        if (s === "late") return "迟到"
        if (s === "leave") return "请假"
        return s
    }

    function getStatusColor(s) {
        if (s === "present") return "#22c55e"
        if (s === "absent") return "#ef4444"
        if (s === "late") return "#f59e0b"
        if (s === "leave") return "#3b82f6"
        return "#8ea1ad"
    }

    function formatTime(dt) {
        if (!dt) return ""
        try {
            var d = new Date(dt)
            return d.getFullYear() + "-" + String(d.getMonth()+1).padStart(2,'0') + "-"
                + String(d.getDate()).padStart(2,'0') + " "
                + String(d.getHours()).padStart(2,'0') + ":" + String(d.getMinutes()).padStart(2,'0')
        } catch(e) { return dt }
    }

    function selectAttendance(uuid) {
        selectedAttendanceUuid = uuid
        detailLoading = true
        requiredApiClient.fetchAttendanceDetail(requiredCourseUuid, uuid)
    }

    function backToList() {
        selectedAttendanceUuid = ""
        attendanceDetailData = null
        attendanceDetailRecords = []
    }

    function viewPhoto(url, title) {
        photoUrl = url
        photoTitle = title
        showPhotoDialog = true
    }

    // ---- Layout ----
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ---- Mode toggle tabs ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Rectangle {
                Layout.preferredWidth: 140
                Layout.preferredHeight: 36
                radius: 6
                color: viewMode === 0 ? Qt.rgba(15/255, 118/255, 110/255, 0.2) : "transparent"
                FluText {
                    anchors.centerIn: parent
                    text: "随机点名"
                    font.pixelSize: 13
                    font.bold: viewMode === 0
                    textColor: viewMode === 0 ? "#0f766e" : "#8ea1ad"
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        viewMode = 0
                        backToList()
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 140
                Layout.preferredHeight: 36
                radius: 6
                color: viewMode === 1 ? Qt.rgba(15/255, 118/255, 110/255, 0.2) : "transparent"
                FluText {
                    anchors.centerIn: parent
                    text: "考勤签到"
                    font.pixelSize: 13
                    font.bold: viewMode === 1
                    textColor: viewMode === 1 ? "#0f766e" : "#8ea1ad"
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        viewMode = 1
                        backToList()
                        requiredApiClient.fetchAttendances(requiredCourseUuid)
                    }
                }
            }

            Item { Layout.fillWidth: true }
        }

        FluDivider { Layout.fillWidth: true; Layout.topMargin: 6; Layout.bottomMargin: 6 }

        // ---- Random Picker Panel ----
        RowLayout {
            visible: viewMode === 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 24

            // Left: Control panel
            FluFrame {
                Layout.preferredWidth: 300
                Layout.minimumWidth: 250
                Layout.fillHeight: true
                radius: 12

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 14

                    FluText {
                        text: "点名控制台"
                        font.pixelSize: 16
                        font.bold: true
                    }

                    FluText {
                        text: "随机抽取学生回答问题或进行课堂互动"
                        font.pixelSize: 11
                        textColor: "#8ea1ad"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    FluDivider { Layout.fillWidth: true }

                    FluText {
                        text: "抽取设置"
                        font.pixelSize: 12
                        font.bold: true
                        textColor: "#b3c0c8"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        FluText {
                            text: "抽取人数"
                            font.pixelSize: 11
                            Layout.preferredWidth: 70
                        }
                        FluSpinBox {
                            id: drawCountBox
                            Layout.fillWidth: true
                            from: 1
                            to: 15
                            value: 1
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        FluText {
                            text: "抽取模式"
                            font.pixelSize: 11
                            Layout.preferredWidth: 70
                        }
                        FluComboBox {
                            id: drawMode
                            Layout.fillWidth: true
                            model: ["随机抽取", "尽量不重复", "只抽未点到"]
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        FluToggleSwitch { id: showClass; checked: true }
                        FluText { text: "结果里显示班级"; font.pixelSize: 11 }
                    }

                    FluText {
                        text: "随机抽取：完全随机；尽量不重复：降低近期被点过的概率；只抽未点到：本轮未点名过的学生"
                        font.pixelSize: 10
                        textColor: "#6a7882"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        FluFilledButton {
                            text: "开始点名"
                            Layout.fillWidth: true
                            font.pixelSize: 12
                            onClicked: doDraw()
                        }
                        FluButton {
                            text: "重置记录"
                            Layout.fillWidth: true
                            font.pixelSize: 12
                            onClicked: resetRound()
                        }
                    }

                    FluDivider { Layout.fillWidth: true }

                    FluText {
                        text: "本轮历史"
                        font.pixelSize: 12
                        font.bold: true
                        textColor: "#b3c0c8"
                    }

                    FluFrame {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 8
                        color: Qt.rgba(21/255, 24/255, 29/255, 1)

                        ListView {
                            id: historyView
                            anchors.fill: parent
                            anchors.margins: 8
                            clip: true
                            model: roundHistory
                            delegate: RowLayout {
                                required property var modelData
                                required property int index
                                width: historyView.width - 4
                                spacing: 6
                                FluText {
                                    text: (index + 1) + "."
                                    font.pixelSize: 11
                                    textColor: "#6a7882"
                                    Layout.preferredWidth: 20
                                }
                                FluText {
                                    text: modelData.real_name || modelData.username
                                    font.pixelSize: 11
                                    textColor: "#b3c0c8"
                                    Layout.preferredWidth: 80
                                }
                                FluText {
                                    text: modelData.student_no || ""
                                    font.pixelSize: 10
                                    textColor: "#6a7882"
                                }
                            }
                        }

                        FluText {
                            visible: roundHistory.length === 0
                            anchors.centerIn: parent
                            text: "暂无记录"
                            font.pixelSize: 11
                            textColor: "#53636d"
                        }
                    }
                }
            }

            // Right: Result area
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 16

                FluText {
                    text: "点名结果"
                    font.pixelSize: 18
                    font.bold: true
                }

                FluText {
                    text: {
                        var total = studentPool.length
                        var drawn = roundHistory.length
                        var base = "课堂共 " + total + " 人"
                        if (drawn > 0) base += " | 已点名 " + drawn + " 人"
                        base += " | 模式：" + drawMode.currentText
                        if (!membersLoaded) base += " | 加载中..."
                        return base
                    }
                    font.pixelSize: 12
                    textColor: "#8ea1ad"
                }

                FluFrame {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 160
                    radius: 16
                    color: currentDrawResults.length > 0 ? "#0f766e" : Qt.rgba(15/255, 118/255, 110/255, 0.3)

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        FluText {
                            text: currentDrawResults.length > 0 ? "本轮结果" : "点击「开始点名」抽取"
                            font.pixelSize: 12
                            textColor: Qt.rgba(1,1,1,0.7)
                            Layout.alignment: Qt.AlignHCenter
                        }
                        FluText {
                            visible: currentDrawResults.length === 1
                            text: currentDrawResults.length === 1 ? (currentDrawResults[0].real_name || currentDrawResults[0].username) : ""
                            font.pixelSize: 32
                            font.bold: true
                            textColor: "#ffffff"
                            Layout.alignment: Qt.AlignHCenter
                        }
                        FluText {
                            visible: currentDrawResults.length === 1
                            text: currentDrawResults.length === 1 ? ((currentDrawResults[0].student_no || "") + (showClass.checked ? "" : "")) : ""
                            font.pixelSize: 13
                            textColor: Qt.rgba(1,1,1,0.7)
                            Layout.alignment: Qt.AlignHCenter
                        }
                        FluText {
                            visible: currentDrawResults.length > 1
                            text: "共抽取 " + currentDrawResults.length + " 人"
                            font.pixelSize: 22
                            font.bold: true
                            textColor: "#ffffff"
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }

                // Detail list
                FluFrame {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 42
                            color: "transparent"

                            FluText {
                                anchors {
                                    left: parent.left
                                    leftMargin: 16
                                    verticalCenter: parent.verticalCenter
                                }
                                text: "本次抽取详情"
                                font.pixelSize: 14
                                font.bold: true
                                visible: currentDrawResults.length > 0
                            }
                            FluText {
                                anchors.centerIn: parent
                                text: "暂无抽取结果"
                                font.pixelSize: 12
                                textColor: "#53636d"
                                visible: currentDrawResults.length === 0
                            }
                        }

                        FluDivider { Layout.fillWidth: true }

                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            model: currentDrawResults
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                width: ListView.view.width
                                height: 48
                                color: index % 2 === 0 ? Qt.rgba(255,255,255,0.04) : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 16
                                    spacing: 12

                                    Rectangle {
                                        width: 32; height: 32; radius: 16
                                        color: "#0f766e"
                                        FluText {
                                            anchors.centerIn: parent
                                            text: (modelData.real_name || modelData.username).charAt(0).toUpperCase()
                                            font.pixelSize: 14
                                            font.bold: true
                                            textColor: "#ffffff"
                                        }
                                    }

                                    FluText {
                                        text: modelData.real_name || modelData.username
                                        font.pixelSize: 14
                                        font.bold: true
                                        Layout.preferredWidth: 120
                                        elide: Text.ElideRight
                                    }

                                    FluText {
                                        text: modelData.student_no || ""
                                        font.pixelSize: 11
                                        textColor: "#8ea1ad"
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 28
                                        Layout.preferredHeight: 22
                                        radius: 11
                                        color: Qt.rgba(15/255, 118/255, 110/255, 0.2)
                                        FluText {
                                            anchors.centerIn: parent
                                            text: "#" + (index + 1)
                                            font.pixelSize: 10
                                            textColor: "#0f766e"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---- Attendance Panel ----
        ColumnLayout {
            visible: viewMode === 1
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Session detail view (when selectedAttendanceUuid is set)
            // Session list / create form (when no session selected)
            ScrollView {
                id: attScrollView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.vertical: FluScrollBar {}

                ColumnLayout {
                    width: attScrollView.availableWidth
                    spacing: 16

                    // ---- Create Attendance Card ----
                    FluFrame {
                        Layout.fillWidth: true
                        radius: 10
                        padding: 16
                        implicitHeight: createCol.implicitHeight + 32

                        ColumnLayout {
                            id: createCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            spacing: 10

                            FluText {
                                text: "发起签到"
                                font.pixelSize: 16
                                font.bold: true
                            }
                            FluText {
                                text: "创建一次新的考勤签到会话，学生可在移动端完成签到"
                                font.pixelSize: 11
                                textColor: "#8ea1ad"
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            FluDivider { Layout.fillWidth: true }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                FluText {
                                    text: "签到标题"
                                    font.pixelSize: 11
                                    Layout.preferredWidth: 70
                                }
                                FluTextBox {
                                    id: attendanceTitleInput
                                    Layout.fillWidth: true
                                    font.pixelSize: 12
                                    placeholderText: "例如：第3周周一签到"
                                    text: ""
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                FluText {
                                    text: "签到模式"
                                    font.pixelSize: 11
                                    Layout.preferredWidth: 70
                                }
                                FluComboBox {
                                    id: attendanceModeCombo
                                    Layout.preferredWidth: 200
                                    model: ["简单签到 (一键签到)", "拍照签到 (上传照片)"]
                                    currentIndex: 0
                                }
                            }

                            FluFilledButton {
                                text: "发起签到"
                                font.pixelSize: 12
                                onClicked: {
                                    var title = attendanceTitleInput.text.trim()
                                    if (!title) title = "第" + (attendancesData.length + 1) + "次签到"
                                    var mode = attendanceModeCombo.currentIndex === 0 ? "simple" : "photo"
                                    requiredApiClient.startAttendance(requiredCourseUuid, title, mode)
                                }
                            }
                        }
                    }

                    // ---- Detail Back Button (when viewing detail) ----
                    RowLayout {
                        visible: selectedAttendanceUuid ? true : false
                        Layout.fillWidth: true
                        spacing: 8

                        FluIconButton {
                            iconSource: FluentIcons.ChromeBack
                            width: 28; height: 28
                            onClicked: backToList()
                        }
                        FluText {
                            text: attendanceDetailData ? (attendanceDetailData.title || "") : ""
                            font.pixelSize: 16
                            font.bold: true
                        }
                        Item { Layout.fillWidth: true }
                    }

                    // ---- Attendance Detail Card (when viewing detail) ----
                    FluFrame {
                        visible: selectedAttendanceUuid ? true : false
                        Layout.fillWidth: true
                        radius: 10
                        padding: 16
                        implicitHeight: detailInfoCol.implicitHeight + 32

                        ColumnLayout {
                            id: detailInfoCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                FluText {
                                    text: "模式: " + (attendanceDetailData && attendanceDetailData.mode === "photo" ? "拍照签到" : "简单签到")
                                    font.pixelSize: 12
                                }

                                Rectangle {
                                    radius: 4
                                    color: attendanceDetailData && attendanceDetailData.status === "closed"
                                        ? Qt.rgba(239/255, 68/255, 68/255, 0.15)
                                        : Qt.rgba(34/255, 197/255, 94/255, 0.15)
                                    Layout.preferredWidth: 52
                                    Layout.preferredHeight: 22
                                    FluText {
                                        anchors.centerIn: parent
                                        text: attendanceDetailData && attendanceDetailData.status === "closed" ? "已结束" : "进行中"
                                        font.pixelSize: 10
                                        font.bold: true
                                        textColor: attendanceDetailData && attendanceDetailData.status === "closed" ? "#ef4444" : "#22c55e"
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                FluText {
                                    text: attendanceDetailData ? formatTime(attendanceDetailData.created_at) : ""
                                    font.pixelSize: 10
                                    textColor: "#6a7882"
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 20
                                FluText { text: "总人数: " + (attendanceDetailData ? attendanceDetailData.total : 0); font.pixelSize: 12 }
                                FluText { text: "已到: " + (attendanceDetailData ? attendanceDetailData.present_count : 0); font.pixelSize: 12; textColor: "#22c55e" }
                                FluText { text: "缺席: " + (attendanceDetailData ? attendanceDetailData.absent_count : 0); font.pixelSize: 12; textColor: "#ef4444" }
                                FluText { text: "迟到: " + (attendanceDetailData ? attendanceDetailData.late_count : 0); font.pixelSize: 12; textColor: "#f59e0b" }
                                FluText { text: "请假: " + (attendanceDetailData ? attendanceDetailData.leave_count : 0); font.pixelSize: 12; textColor: "#3b82f6" }
                            }

                            FluButton {
                                visible: attendanceDetailData && attendanceDetailData.status !== "closed"
                                text: "关闭签到"
                                font.pixelSize: 11
                                onClicked: {
                                    requiredApiClient.closeAttendance(requiredCourseUuid, selectedAttendanceUuid)
                                }
                            }
                        }
                    }

                    // ---- Student Records (detail view) ----
                    FluText {
                        visible: selectedAttendanceUuid ? true : false
                        text: "学生签到记录"
                        font.pixelSize: 14
                        font.bold: true
                    }

                    ColumnLayout {
                        visible: selectedAttendanceUuid ? true : false
                        Layout.fillWidth: true
                        spacing: 2

                        Repeater {
                            model: attendanceDetailRecords
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                implicitHeight: 52
                                radius: 6
                                color: index % 2 === 0 ? Qt.rgba(255,255,255,0.03) : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 10

                                    Rectangle {
                                        width: 28; height: 28; radius: 14
                                        color: getStatusColor(modelData.status || "absent")
                                        FluText {
                                            anchors.centerIn: parent
                                            text: (modelData.real_name || modelData.student_name || "?").charAt(0).toUpperCase()
                                            font.pixelSize: 12
                                            font.bold: true
                                            textColor: "#ffffff"
                                        }
                                    }

                                    FluText {
                                        text: modelData.real_name || modelData.student_name || ""
                                        font.pixelSize: 13
                                        font.bold: true
                                        Layout.preferredWidth: 100
                                        elide: Text.ElideRight
                                    }

                                    FluText {
                                        text: modelData.student_no || ""
                                        font.pixelSize: 10
                                        textColor: "#8ea1ad"
                                        Layout.preferredWidth: 80
                                    }

                                    Rectangle {
                                        radius: 4
                                        color: Qt.rgba(0,0,0,0.1)
                                        Layout.preferredWidth: 48
                                        Layout.preferredHeight: 22
                                        FluText {
                                            anchors.centerIn: parent
                                            text: getStatusLabel(modelData.status || "absent")
                                            font.pixelSize: 10
                                            font.bold: true
                                            textColor: getStatusColor(modelData.status || "absent")
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    // Photo button for photo mode
                                    FluTextButton {
                                        visible: modelData.has_photo ? true : false
                                        text: "查看照片"
                                        font.pixelSize: 11
                                        onClicked: {
                                            viewPhoto(
                                                modelData.photo_url || "",
                                                (modelData.real_name || modelData.student_name || "")
                                            )
                                        }
                                    }

                                    // Speed grade buttons
                                    Rectangle {
                                        visible: attendanceDetailData && attendanceDetailData.status !== "closed"
                                        radius: 4
                                        color: Qt.rgba(34/255, 197/255, 94/255, 0.1)
                                        Layout.preferredWidth: 36
                                        Layout.preferredHeight: 24
                                        FluText {
                                            anchors.centerIn: parent
                                            text: "到"
                                            font.pixelSize: 10
                                            textColor: "#22c55e"
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: requiredApiClient.markAttendance(
                                                requiredCourseUuid, selectedAttendanceUuid,
                                                modelData.student_uuid, "present", "")
                                        }
                                    }

                                    Rectangle {
                                        visible: attendanceDetailData && attendanceDetailData.status !== "closed"
                                        radius: 4
                                        color: Qt.rgba(239/255, 68/255, 68/255, 0.1)
                                        Layout.preferredWidth: 36
                                        Layout.preferredHeight: 24
                                        FluText {
                                            anchors.centerIn: parent
                                            text: "缺"
                                            font.pixelSize: 10
                                            textColor: "#ef4444"
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: requiredApiClient.markAttendance(
                                                requiredCourseUuid, selectedAttendanceUuid,
                                                modelData.student_uuid, "absent", "")
                                        }
                                    }
                                }
                            }
                        }

                        // Loading indicator
                        FluText {
                            visible: detailLoading && attendanceDetailRecords.length === 0
                            text: "加载中..."
                            font.pixelSize: 11
                            textColor: "#53636d"
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    // ---- Sessions List (no selection) ----
                    FluText {
                        visible: !selectedAttendanceUuid
                        text: "签到记录"
                        font.pixelSize: 14
                        font.bold: true
                    }

                    ColumnLayout {
                        visible: !selectedAttendanceUuid
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: attendancesData
                            delegate: FluFrame {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                radius: 10
                                padding: 14
                                implicitHeight: attCardContent.implicitHeight + 28

                                RowLayout {
                                    id: attCardContent
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    spacing: 12

                                    // Mode icon
                                    Rectangle {
                                        width: 40; height: 40; radius: 20
                                        color: modelData.mode === "photo"
                                            ? Qt.rgba(59/255, 130/255, 246/255, 0.15)
                                            : Qt.rgba(15/255, 118/255, 110/255, 0.15)
                                        FluText {
                                            anchors.centerIn: parent
                                            text: modelData.mode === "photo" ? "\uD83D\uDCF7" : "\u2714"
                                            font.pixelSize: 18
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        FluText {
                                            text: modelData.title || ""
                                            font.pixelSize: 13
                                            font.bold: true
                                            Layout.fillWidth: true
                                        }
                                        FluText {
                                            text: (modelData.mode === "photo" ? "拍照签到" : "简单签到")
                                                + " | 已到 " + (modelData.present_count || 0)
                                                + "/" + (modelData.total || 0)
                                                + " | " + formatTime(modelData.created_at)
                                            font.pixelSize: 10
                                            textColor: "#8ea1ad"
                                            Layout.fillWidth: true
                                        }
                                    }

                                    Rectangle {
                                        radius: 4
                                        color: modelData.status === "closed"
                                            ? Qt.rgba(239/255, 68/255, 68/255, 0.12)
                                            : Qt.rgba(34/255, 197/255, 94/255, 0.12)
                                        Layout.preferredWidth: 52
                                        Layout.preferredHeight: 22
                                        FluText {
                                            anchors.centerIn: parent
                                            text: modelData.status === "closed" ? "已结束" : "进行中"
                                            font.pixelSize: 10
                                            font.bold: true
                                            textColor: modelData.status === "closed" ? "#ef4444" : "#22c55e"
                                        }
                                    }

                                    FluButton {
                                        text: "查看"
                                        font.pixelSize: 11
                                        onClicked: selectAttendance(modelData.uuid)
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: selectAttendance(modelData.uuid)
                                }
                            }
                        }

                        FluText {
                            visible: attendancesData.length === 0
                            text: "暂无签到记录，请发起新的签到"
                            font.pixelSize: 11
                            textColor: "#53636d"
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 20
                        }
                    }
                }
            }
        }
    }

    // ---- Photo Viewer Popup ----
    Popup {
        id: photoPopup
        visible: showPhotoDialog
        modal: true
        dim: true
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.8, 640)
        height: Math.min(parent.height * 0.8, 520)
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onClosed: showPhotoDialog = false

        background: FluFrame {
            radius: 12
            padding: 0
            color: Qt.rgba(30/255, 34/255, 40/255, 1)
        }

        contentItem: ColumnLayout {
            spacing: 0

            // Header
            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 12
                spacing: 8

                FluText {
                    text: photoTitle || "签到照片"
                    font.pixelSize: 14
                    font.bold: true
                    Layout.fillWidth: true
                }
                FluIconButton {
                    iconSource: FluentIcons.ChromeClose
                    width: 28; height: 28
                    onClicked: { showPhotoDialog = false; photoPopup.close() }
                }
            }

            FluDivider { Layout.fillWidth: true }

            // Image
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 12
                radius: 8
                color: Qt.rgba(0,0,0,0.3)
                clip: true

                Image {
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectFit
                    source: photoUrl ? (requiredApiClient.serverUrl() + photoUrl + "?token=" + requiredApiClient.token()) : ""
                    cache: false
                    smooth: true
                }
            }
        }
    }
}
