import QtQuick
import QtQuick.Layouts
import FluentUI
import EduStat.Backend 1.0

// 点名 Roll Call Page
Item {
    required property ApiClient requiredApiClient
    required property string requiredCourseUuid

    property var allStudents: ([])
    property var roundHistory: ([])      // 本轮已抽取
    property var currentDrawResults: ([])  // 本次抽取结果
    property bool membersLoaded: false

    Component.onCompleted: {
        if (requiredCourseUuid) requiredApiClient.fetchCourseMembers(requiredCourseUuid)
    }

    Connections {
        target: requiredApiClient
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
    }

    // 只保留学生
    property var studentPool: {
        var arr = []
        for (var i = 0; i < allStudents.length; i++) {
            if (allStudents[i].member_role === "student") arr.push(allStudents[i])
        }
        return arr
    }

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
        // 尽量不重复: 优先选还没被点过的，不够了再从已点的随机
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

        var exclude = (mode === 2) ? roundHistory : []  // 只抽未点到: exclude all history
        var picked
        if (mode === 0) {
            picked = pickRandom(pool, count, [])
        } else if (mode === 1) {
            picked = pickWeighted(pool, count, roundHistory)
        } else {
            picked = pickRandom(pool, count, roundHistory)
            // If not enough fresh students, pick from remaining
            if (picked.length < count) {
                var remaining = pickRandom(pool, count - picked.length, [])
                for (var r = 0; r < remaining.length; r++) picked.push(remaining[r])
            }
        }

        currentDrawResults = picked

        // Add to round history (avoid duplicates)
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

    RowLayout {
        anchors.fill: parent
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

                // Number of students
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

                // Draw mode
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

                // Show class info
                RowLayout {
                    Layout.fillWidth: true
                    FluToggleSwitch {
                        id: showClass
                        checked: true
                    }
                    FluText {
                        text: "结果里显示班级"
                        font.pixelSize: 11
                    }
                }

                FluText {
                    text: "随机抽取：完全随机；尽量不重复：降低近期被点过的概率；只抽未点到：本轮未点名过的学生"
                    font.pixelSize: 10
                    textColor: "#6a7882"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                // Action buttons
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

                // History
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

            // Summary
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

            // Highlight result
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
                    anchors.margins: 16
                    spacing: 6

                    FluText {
                        text: "本次抽取详情"
                        font.pixelSize: 13
                        font.bold: true
                        visible: currentDrawResults.length > 0
                    }

                    FluText {
                        visible: currentDrawResults.length === 0
                        Layout.alignment: Qt.AlignCenter
                        text: "暂无抽取结果"
                        font.pixelSize: 12
                        textColor: "#53636d"
                    }

                    Repeater {
                        model: currentDrawResults
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            height: 44
                            radius: 8
                            color: index % 2 === 0 ? Qt.rgba(255,255,255,0.04) : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10

                                Rectangle {
                                    width: 30; height: 30; radius: 15
                                    color: "#0f766e"
                                    FluText {
                                        anchors.centerIn: parent
                                        text: (modelData.real_name || modelData.username).charAt(0)
                                        font.pixelSize: 13
                                        textColor: "#ffffff"
                                    }
                                }
                                FluText {
                                    text: (index + 1) + "."
                                    font.pixelSize: 11
                                    textColor: "#6a7882"
                                    Layout.preferredWidth: 24
                                }
                                FluText {
                                    text: modelData.real_name || modelData.username
                                    font.pixelSize: 13
                                    font.bold: true
                                    Layout.preferredWidth: 100
                                }
                                FluText {
                                    text: modelData.student_no || "--"
                                    font.pixelSize: 11
                                    textColor: "#8ea1ad"
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
