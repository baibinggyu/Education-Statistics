import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import FluentUI
import EduStat.Backend 1.0

// 组队 Team Up Page
Item {
    required property ApiClient requiredApiClient
    required property string requiredCourseUuid

    property var membersRaw: ([])
    property var scoresMap: ({})
    property bool membersLoaded: false
    property bool scoresLoaded: false
    property var teams: ([])
    property var historyList: ([])
    property int groupSize: 3
    property int groupMode: 0  // 0=随机, 1=强配弱平衡
    property bool useScores: true

    // 持久化历史记录到磁盘
    Settings {
        id: teamSettings
        category: "TeamUp"
        property string savedHistory: ""
    }

    Component.onCompleted: {
        // 加载之前保存的组队历史
        try {
            var saved = JSON.parse(teamSettings.savedHistory || "[]")
            if (Array.isArray(saved)) historyList = saved
        } catch (e) {
            historyList = []
        }
        if (requiredCourseUuid) refreshStudents()
    }

    function refreshStudents() {
        membersLoaded = false
        scoresLoaded = false
        membersRaw = []
        scoresMap = ({})
        teams = []
        requiredApiClient.fetchCourseMembers(requiredCourseUuid)
        requiredApiClient.fetchScoreSummary(requiredCourseUuid)
    }

    Connections {
        target: requiredApiClient

        function onCourseMembersReset() { membersRaw = [] }
        function onCourseMemberListed(userUuid, username, memberRole, joinedAt, studentNo, realName) {
            if (memberRole === "student") {
                membersRaw.push({
                    user_uuid: userUuid,
                    username: username,
                    student_no: studentNo || "",
                    real_name: realName || ""
                })
            }
        }
        function onCourseMembersListDone() {
            membersLoaded = true
            membersRawChanged()
        }

        function onScoreSummaryFetched(summary) {
            var map = ({})
            var students = summary.students || []
            for (var i = 0; i < students.length; i++) {
                var s = students[i]
                map[s.student_uuid] = {
                    student_no: s.student_no || "",
                    real_name: s.real_name || "",
                    weighted_total: s.weighted_total,
                    rank: s.rank
                }
            }
            scoresMap = map
            scoresLoaded = true
        }
        function onScoreSummaryError(msg) {
            scoresLoaded = true
        }
    }

    // Merge members with scores
    property var allStudents: {
        var result = []
        for (var i = 0; i < membersRaw.length; i++) {
            var m = membersRaw[i]
            var se = scoresMap[m.user_uuid]
            result.push({
                user_uuid: m.user_uuid,
                username: m.username,
                student_no: m.student_no,
                real_name: m.real_name || m.username,
                weighted_total: (se && se.weighted_total != null) ? se.weighted_total : 0,
                rank: (se && se.rank != null) ? se.rank : 999
            })
        }
        return result
    }

    property int totalStudents: allStudents.length

    function shuffle(arr) {
        var a = arr.slice()
        for (var i = a.length - 1; i > 0; i--) {
            var j = Math.floor(Math.random() * (i + 1))
            var tmp = a[i]; a[i] = a[j]; a[j] = tmp
        }
        return a
    }

    function generateTeams() {
        var pool = allStudents
        if (pool.length === 0) return

        var students = []
        if (groupMode === 0) {
            students = shuffle(pool)
        } else {
            students = pool.slice().sort(function(a, b) {
                return b.weighted_total - a.weighted_total
            })
        }

        var n = students.length
        var size = groupSize
        if (size < 2) size = 2
        var numTeams = Math.ceil(n / size)

        var newTeams = []
        for (var t = 0; t < numTeams; t++) {
            newTeams.push({ name: "第" + (t + 1) + "组", members: [] })
        }

        if (groupMode === 0) {
            for (var i = 0; i < n; i++) {
                newTeams[i % numTeams].members.push(students[i])
            }
        } else {
            for (var i2 = 0; i2 < n; i2++) {
                var round = Math.floor(i2 / numTeams)
                var pos = i2 % numTeams
                var teamIdx = (round % 2 === 0) ? pos : (numTeams - 1 - pos)
                newTeams[teamIdx].members.push(students[i2])
            }
        }

        // Mark first member as leader
        for (var t2 = 0; t2 < newTeams.length; t2++) {
            if (newTeams[t2].members.length > 0) {
                newTeams[t2].members[0].isLeader = true
            }
        }

        // Deep copy via JSON to avoid reference sharing with history
        teams = JSON.parse(JSON.stringify(newTeams))
    }

    function saveToHistory() {
        if (teams.length === 0) return
        var modeLabel = groupMode === 0 ? "随机" : "平衡"
        // Deep copy teams so history entry is independent
        var entry = {
            label: "分组" + (historyList.length + 1) + " - " + numGroups + "组/" + totalStudents + "人 - " + modeLabel,
            date: new Date().toLocaleString(Qt.locale(), "yyyy-MM-dd hh:mm"),
            teams: JSON.parse(JSON.stringify(teams)),
            groupSize: groupSize,
            groupMode: groupMode,
            totalStudents: totalStudents,
            numGroups: numGroups
        }
        var h = historyList.slice()
        h.unshift(entry)
        if (h.length > 20) h = h.slice(0, 20)
        historyList = h
        // 持久化到磁盘
        teamSettings.savedHistory = JSON.stringify(h)
    }

    property int numGroups: teams.length

    RowLayout {
        anchors.fill: parent
        spacing: 24

        // Left: Control panel
        FluFrame {
            Layout.preferredWidth: 280
            Layout.minimumWidth: 240
            Layout.fillHeight: true
            radius: 12

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                FluText {
                    text: "随机组队"
                    font.pixelSize: 16
                    font.bold: true
                }

                FluText {
                    text: {
                        var base = "共 " + totalStudents + " 名学生"
                        if (teams.length > 0) base += "，分为 " + numGroups + " 组"
                        if (!membersLoaded || !scoresLoaded) base += " · 加载中..."
                        return base
                    }
                    font.pixelSize: 11
                    textColor: "#8ea1ad"
                }

                FluDivider { Layout.fillWidth: true }

                FluText {
                    text: "组队规则"
                    font.pixelSize: 12
                    font.bold: true
                    textColor: "#b3c0c8"
                }

                RowLayout {
                    FluText {
                        text: "每组人数"
                        font.pixelSize: 11
                        Layout.preferredWidth: 70
                    }
                    FluSpinBox {
                        id: groupSizeBox
                        Layout.fillWidth: true
                        from: 2
                        to: 8
                        value: 3
                        onValueChanged: groupSize = value
                    }
                }

                RowLayout {
                    FluText {
                        text: "分组模式"
                        font.pixelSize: 11
                        Layout.preferredWidth: 70
                    }
                    FluComboBox {
                        id: modeBox
                        Layout.fillWidth: true
                        model: ["随机分组", "强配弱平衡"]
                        onCurrentIndexChanged: groupMode = currentIndex
                    }
                }

                RowLayout {
                    FluToggleSwitch { id: scoreRefSwitch; checked: true; onCheckedChanged: useScores = checked }
                    FluText {
                        text: "参考当前成绩进行分组"
                        font.pixelSize: 11
                    }
                }

                FluText {
                    text: "强配弱平衡：按加权总分排序后蛇形分配，确保每组整体水平均衡。随机分组：完全随机打乱后平均分配。"
                    font.pixelSize: 10
                    textColor: "#6a7882"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                RowLayout {
                    spacing: 10
                    FluFilledButton {
                        text: "生成组队"
                        Layout.fillWidth: true
                        font.pixelSize: 12
                        onClicked: generateTeams()
                    }
                    FluButton {
                        text: "保存到历史"
                        Layout.fillWidth: true
                        font.pixelSize: 12
                        onClicked: saveToHistory()
                    }
                }

                FluDivider { Layout.fillWidth: true }

                FluText {
                    text: "历史组队"
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
                        spacing: 6
                        model: historyList
                        clip: true

                        delegate: FluFrame {
                            required property var modelData
                            required property int index
                            width: historyView.width - 2
                            height: histContent.implicitHeight + 20
                            radius: 6
                            color: hoverArea2.containsMouse ? Qt.rgba(15/255, 118/255, 110/255, 0.15) : "transparent"

                            MouseArea {
                                id: hoverArea2
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    teams = JSON.parse(JSON.stringify(modelData.teams))
                                    groupSize = modelData.groupSize
                                    groupMode = modelData.groupMode
                                    groupSizeBox.value = modelData.groupSize
                                    modeBox.currentIndex = modelData.groupMode
                                }
                            }

                            ColumnLayout {
                                id: histContent
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 10
                                spacing: 4

                                FluText {
                                    Layout.fillWidth: true
                                    text: modelData.label
                                    font.pixelSize: 11
                                    font.bold: true
                                    wrapMode: Text.WordWrap
                                }
                                FluText {
                                    text: modelData.date
                                    font.pixelSize: 9
                                    textColor: "#6a7882"
                                }
                            }
                        }
                    }

                    FluText {
                        visible: historyList.length === 0
                        anchors.centerIn: parent
                        text: "暂无历史记录"
                        font.pixelSize: 11
                        textColor: "#53636d"
                    }
                }
            }
        }

        // Right: Team cards area
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            FluText {
                text: teams.length > 0 ? "当前队组（" + numGroups + " 组 / " + totalStudents + " 人）" : "当前队组"
                font.pixelSize: 18
                font.bold: true
            }

            FluText {
                visible: teams.length === 0
                text: "请在左侧设置规则后点击「生成组队」"
                font.pixelSize: 12
                textColor: "#53636d"
            }

            ScrollView {
                id: teamScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.vertical: FluScrollBar {}

                Flow {
                    width: teamScroll.availableWidth
                    spacing: 14

                    Repeater {
                        model: teams

                        delegate: FluFrame {
                            required property var modelData
                            required property int index
                            width: 280
                            radius: 16
                            implicitHeight: teamContent.implicitHeight + 32

                            ColumnLayout {
                                id: teamContent
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 16
                                spacing: 10

                                RowLayout {
                                    FluText {
                                        text: modelData.name
                                        font.pixelSize: 14
                                        font.bold: true
                                    }
                                    Item { Layout.fillWidth: true }
                                    FluFrame {
                                        radius: 8
                                        color: "#0f766e"
                                        padding: 6
                                        FluText {
                                            text: modelData.members.length + "人"
                                            font.pixelSize: 10
                                            textColor: "#ffffff"
                                        }
                                    }
                                }

                                FluText {
                                    text: {
                                        var sum = 0, cnt = 0
                                        for (var i = 0; i < modelData.members.length; i++) {
                                            sum += modelData.members[i].weighted_total
                                            cnt++
                                        }
                                        var avg = cnt > 0 ? (sum / cnt).toFixed(1) : "--"
                                        return "共 " + modelData.members.length + " 人 · 均分 " + avg
                                    }
                                    font.pixelSize: 10
                                    textColor: "#8fa1ab"
                                }

                                // Member list
                                FluFrame {
                                    Layout.fillWidth: true
                                    implicitHeight: memberList.implicitHeight + 16
                                    radius: 10
                                    color: Qt.rgba(21/255, 25/255, 31/255, 1)
                                    padding: 0

                                    ColumnLayout {
                                        id: memberList
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 8
                                        spacing: 4

                                        Repeater {
                                            model: modelData.members
                                            delegate: RowLayout {
                                                required property var modelData
                                                width: memberList.width
                                                spacing: 8

                                                Rectangle {
                                                    width: 28; height: 28
                                                    radius: 14
                                                    color: modelData.isLeader ? "#f59e0b" : "#0f766e"
                                                    FluText {
                                                        anchors.centerIn: parent
                                                        text: (modelData.real_name || modelData.username).charAt(0)
                                                        font.pixelSize: 12
                                                        textColor: "#ffffff"
                                                    }
                                                }

                                                ColumnLayout {
                                                    spacing: 0
                                                    FluText {
                                                        text: modelData.real_name || modelData.username
                                                        font.pixelSize: 11
                                                    }
                                                    FluText {
                                                        text: modelData.student_no || ""
                                                        font.pixelSize: 9
                                                        textColor: "#6a7882"
                                                        visible: modelData.student_no !== ""
                                                    }
                                                }

                                                Item { Layout.fillWidth: true }

                                                FluText {
                                                    text: modelData.weighted_total != null ? modelData.weighted_total.toFixed(1) : "--"
                                                    font.pixelSize: 10
                                                    textColor: "#6a7882"
                                                }

                                                FluText {
                                                    visible: modelData.isLeader === true
                                                    text: "组长"
                                                    font.pixelSize: 9
                                                    textColor: "#f59e0b"
                                                    font.bold: true
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
    }
}
