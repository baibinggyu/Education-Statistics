import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import FluentUI
import EduStat.Backend 1.0

// 学生信息 Student Info Page
Item {
    required property ApiClient requiredApiClient
    required property string requiredCourseUuid
    required property string requiredCourseName

    property var summaryData: ({})
    property var unitsData: ([])
    property var membersRaw: ([])
    property var scoresMap: ({})
    property var unitNames: []
    property var unitIds: []
    property string searchTerm: ""
    property bool membersLoaded: false
    property bool scoresLoaded: false
    property var editingCell: null // {rowIndex, unitId}
    property string sortMode: "student_no"  // "student_no" | "rank"

    Component.onCompleted: {
        if (requiredCourseUuid) refreshData()
    }

    onRequiredCourseUuidChanged: {
        if (visible && requiredCourseUuid) refreshData()
    }

    onVisibleChanged: {
        if (visible && requiredCourseUuid) refreshData()
    }

    function refreshData() {
        if (!requiredCourseUuid) return
        membersLoaded = false
        scoresLoaded = false
        membersRaw = []
        scoresMap = ({})
        unitsData = []
        unitNames = []
        unitIds = []
        editingCell = null
        requiredApiClient.fetchCourseMembers(requiredCourseUuid)
        requiredApiClient.fetchScoreSummary(requiredCourseUuid)
        requiredApiClient.fetchUnits(requiredCourseUuid)
    }

    // Recompute unitIds when unitsData changes
    onUnitsDataChanged: {
        var ids = []
        for (var i = 0; i < unitsData.length; i++) {
            ids.push(unitsData[i].id)
        }
        unitIds = ids
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
            summaryData = summary
            var map = ({})
            var students = summary.students || []
            for (var i = 0; i < students.length; i++) {
                var s = students[i]
                map[s.student_uuid] = {
                    student_no: s.student_no || "",
                    real_name: s.real_name || "",
                    scores: s.scores || [],
                    weighted_total: s.weighted_total,
                    rank: s.rank
                }
            }
            scoresMap = map
            scoresLoaded = true
            if (unitNames.length === 0 && summary.unit_names) {
                unitNames = summary.unit_names
            }
        }
        function onScoreSummaryError(msg) {
            scoresLoaded = true
            console.log("Score summary error:", msg)
        }

        function onScoreUpserted(result) {
            editingCell = null
            refreshData()
        }
        function onScoreUpsertError(msg) {
            console.log("Score upsert error:", msg)
            editingCell = null
        }

        function onUnitListReset() { unitsData = []; unitNames = []; unitIds = [] }
        function onUnitListed(id, name, weight, fullScore, order) {
            unitsData.push({id: id, name: name, weight: weight, fullScore: fullScore, order: order})
            unitNames.push(name)
            unitIds.push(id)
            unitNamesChanged()
            unitIdsChanged()
        }
    }

    // Merge members with scores + embed student_uuid into score entries for editing
    property var studentsData: {
        var result = []
        for (var i = 0; i < membersRaw.length; i++) {
            var m = membersRaw[i]
            var scoreEntry = scoresMap[m.user_uuid] || null
            var rawScores = scoreEntry ? scoreEntry.scores : []
            var scoreEntries = []
            for (var j = 0; j < unitIds.length; j++) {
                var us = unitsData[j]
                scoreEntries.push({
                    unit_id: unitIds[j],
                    value: (j < rawScores.length && rawScores[j] !== null) ? rawScores[j] : null,
                    student_uuid: m.user_uuid,
                    row_index: i,
                    full_score: (us && us.fullScore) ? us.fullScore : 100
                })
            }
            result.push({
                user_uuid: m.user_uuid,
                username: m.username,
                student_no: (scoreEntry && scoreEntry.student_no) ? scoreEntry.student_no : m.student_no,
                real_name: (scoreEntry && scoreEntry.real_name) ? scoreEntry.real_name : (m.real_name || m.username),
                scoreEntries: scoreEntries,
                weighted_total: scoreEntry ? scoreEntry.weighted_total : null,
                rank: scoreEntry ? scoreEntry.rank : null
            })
        }
        return result
    }

    // Sorted and filtered
    property var displayStudents: {
        var list = studentsData.slice()
        if (sortMode === "rank") {
            list.sort(function(a, b) {
                var ra = a.rank != null ? a.rank : 9999
                var rb = b.rank != null ? b.rank : 9999
                return ra - rb
            })
        } else {
            list.sort(function(a, b) {
                var sa = a.student_no || ""
                var sb = b.student_no || ""
                return sa.localeCompare(sb)
            })
        }
        if (!searchTerm) return list
        var term = searchTerm.toLowerCase()
        return list.filter(function(s) {
            return (s.student_no || "").toLowerCase().includes(term) ||
                   (s.real_name || "").toLowerCase().includes(term) ||
                   (s.username || "").toLowerCase().includes(term)
        })
    }

    // ---- Column widths (shared by header and data rows) ----
    property real colStudentNo: 110
    property real colName: 72
    property real colUsername: 110
    property real colWeightedTotal: 70
    property real colRank: 44
    property real colUnitMin: 60  // minimum unit column width

    function calcUnitColWidth() {
        var fixedW = colStudentNo + colName + colUsername + colWeightedTotal + colRank
        var avail = headerRow.width - fixedW - 28  // 28 = leftMargin + rightMargin
        if (unitIds.length <= 0) return colUnitMin
        return Math.max(colUnitMin, Math.floor(avail / unitIds.length))
    }

    // ---- Export helpers ----
    function generateExportContent(format) {
        var list = displayStudents
        if (format === "csv") {
            var header = ["学号","姓名","用户名"].concat(unitNames).concat(["加权总分","排名"])
            var lines = [header.join(",")]
            for (var i = 0; i < list.length; i++) {
                var s = list[i]
                var row = [
                    s.student_no || "",
                    s.real_name || "",
                    s.username || ""
                ]
                var entries = s.scoreEntries || []
                for (var j = 0; j < entries.length; j++) {
                    row.push(entries[j].value != null ? entries[j].value.toFixed(1) : "")
                }
                row.push(s.weighted_total != null ? s.weighted_total.toFixed(1) : "")
                row.push(s.rank != null ? s.rank : "")
                lines.push(row.join(","))
            }
            return lines.join("\n")
        }
        // Markdown (default)
        var headerCells = ["#","学号","姓名","用户名"].concat(unitNames).concat(["加权总分","排名"])
        var md = "| " + headerCells.join(" | ") + " |\n"
        md += "|" + headerCells.map(function(){return "---"}).join("|") + "|\n"
        for (var i = 0; i < list.length; i++) {
            var s = list[i]
            var cells = [
                String(i + 1),
                s.student_no || "",
                s.real_name || "",
                s.username || ""
            ]
            var entries = s.scoreEntries || []
            for (var j = 0; j < entries.length; j++) {
                cells.push(entries[j].value != null ? entries[j].value.toFixed(1) : "--")
            }
            cells.push(s.weighted_total != null ? s.weighted_total.toFixed(1) : "--")
            cells.push(s.rank != null ? "#" + s.rank : "--")
            md += "| " + cells.join(" | ") + " |\n"
        }
        return md
    }

    function detectFormat(path) {
        var p = path.toLowerCase()
        if (p.endsWith(".csv")) return "csv"
        if (p.endsWith(".xlsx")) return "xlsx"
        return "markdown"  // .md or anything else
    }

    FileDialog {
        id: exportFileDialog
        title: "导出成绩"
        nameFilters: [
            "Excel (*.xlsx)",
            "CSV (*.csv)",
            "Markdown (*.md)"
        ]
        fileMode: FileDialog.SaveFile
        onAccepted: {
            var path = exportFileDialog.selectedFile.toString()
            if (path.startsWith("file://")) path = path.substring(7)
            var fmt = detectFormat(path)

            if (fmt === "xlsx") {
                var ok = requiredApiClient.exportScoresToExcel(path, unitNames, displayStudents)
                if (!ok) console.log("Excel export failed:", path)
            } else {
                var content = generateExportContent(fmt)
                var ok = requiredApiClient.saveTextFile(path, content)
                if (!ok) console.log("Export failed:", path)
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        FluText {
            text: "学生信息"
            font.pixelSize: 18
            font.bold: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            FluFilledButton {
                text: "刷新"
                font.pixelSize: 12
                onClicked: refreshData()
            }

            FluText { text: "排序"; font.pixelSize: 11; textColor: "#b3c0c8" }
            FluComboBox {
                id: sortSelector
                Layout.preferredWidth: 120
                model: ["按学号", "按成绩排名"]
                currentIndex: sortMode === "rank" ? 1 : 0
                onActivated: {
                    sortMode = currentIndex === 1 ? "rank" : "student_no"
                    displayStudentsChanged()
                }
            }

            Item { Layout.fillWidth: true }

            FluTextBox {
                id: searchBox
                Layout.preferredWidth: 200
                placeholderText: "搜索..."
                onTextChanged: searchTerm = text
            }

            FluFilledButton {
                text: "导出"
                font.pixelSize: 12
                onClicked: {
                    var name = (requiredCourseName || "成绩表").replace(/[\\/:*?"<>|]/g, '_')
                    // Default to .xlsx (richest format); user can pick .csv or .md in dialog
                    exportFileDialog.selectedFile = requiredApiClient.homeDir() + "/" + name + ".xlsx"
                    exportFileDialog.open()
                }
            }
        }

        FluText {
            text: {
                var total = studentsData.length
                var shown = displayStudents.length
                var modeLabel = sortMode === "rank" ? "按成绩排名" : "按学号"
                var base = "共 " + total + " 名学生 · " + modeLabel
                if (shown !== total) base += " · 筛选 " + shown + " 人"
                base += " · " + (unitNames.length || 0) + " 个单元"
                if (!membersLoaded || !scoresLoaded) base += " · 加载中..."
                return base
            }
            font.pixelSize: 11
            textColor: "#8ea1ad"
        }

        FluFrame {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 10

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 2
                spacing: 0

                // Table header
                Rectangle {
                    id: headerRow
                    Layout.fillWidth: true
                    height: 42
                    color: Qt.rgba(0,0,0,0.08)
                    radius: 8

                    RowLayout {
                        id: headerRowLayout
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 0

                        FluText { Layout.preferredWidth: 110; text: "学号"; font.pixelSize: 11; font.bold: true }
                        FluText { Layout.preferredWidth: 72; text: "姓名"; font.pixelSize: 11; font.bold: true }
                        FluText { Layout.preferredWidth: 110; text: "用户名"; font.pixelSize: 11; font.bold: true }
                        Repeater {
                            model: unitNames
                            delegate: FluText {
                                Layout.preferredWidth: calcUnitColWidth()
                                text: modelData
                                font.pixelSize: 11
                                font.bold: true
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                        FluText { Layout.preferredWidth: 70; text: "加权总分"; font.pixelSize: 11; font.bold: true; horizontalAlignment: Text.AlignRight }
                        FluText { Layout.preferredWidth: 44; text: "排名"; font.pixelSize: 11; font.bold: true; horizontalAlignment: Text.AlignRight }
                    }
                }

                // Table rows
                ListView {
                    id: studentList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: displayStudents

                    delegate: Rectangle {
                        id: rowDelegate
                        required property var modelData
                        required property int index
                        width: headerRow.width
                        height: 40
                        color: index % 2 === 0 ? "transparent" : Qt.rgba(0,0,0,0.04)
                        radius: 4

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 0

                            // Copyable: 学号
                            TextEdit {
                                Layout.preferredWidth: 110
                                text: modelData.student_no || "--"
                                font { pixelSize: 11; family: "Source Han Sans CN, Noto Sans CJK TC, sans-serif" }
                                color: "#e0e0e0"
                                readOnly: true
                                selectByMouse: true
                                verticalAlignment: Text.AlignVCenter
                                padding: 0
                            }
                            // Copyable: 姓名
                            TextEdit {
                                Layout.preferredWidth: 72
                                text: modelData.real_name || "--"
                                font { pixelSize: 11; family: "Source Han Sans CN, Noto Sans CJK TC, sans-serif" }
                                color: "#e0e0e0"
                                readOnly: true
                                selectByMouse: true
                                verticalAlignment: Text.AlignVCenter
                                padding: 0
                            }
                            // Copyable: 用户名
                            TextEdit {
                                Layout.preferredWidth: 110
                                text: modelData.username || "--"
                                font { pixelSize: 11; family: "Source Han Sans CN, Noto Sans CJK TC, sans-serif" }
                                color: "#8ea1ad"
                                readOnly: true
                                selectByMouse: true
                                verticalAlignment: Text.AlignVCenter
                                padding: 0
                            }

                            // Score cells (editable inline)
                            Repeater {
                                model: modelData.scoreEntries || []
                                delegate: Rectangle {
                                    required property var modelData  // {unit_id, value, student_uuid, row_index}
                                    property bool isEditing: {
                                        var ec = editingCell
                                        return ec !== null && ec.rowIndex === modelData.row_index && ec.unitId === modelData.unit_id
                                    }
                                    property real cellScore: modelData.value !== null ? modelData.value : NaN

                                    Layout.preferredWidth: calcUnitColWidth()
                                    Layout.preferredHeight: 40
                                    color: isEditing ? Qt.rgba(15/255, 118/255, 110/255, 0.2) : "transparent"
                                    radius: 3

                                    FluText {
                                        id: scoreDisplay
                                        visible: !parent.isEditing
                                        anchors.right: parent.right
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: isNaN(parent.cellScore) ? "--" : parent.cellScore.toFixed(1)
                                        font.pixelSize: 11
                                        horizontalAlignment: Text.AlignRight
                                    }

                                    FluTextBox {
                                        id: scoreEdit
                                        visible: parent.isEditing
                                        anchors.fill: parent
                                        anchors.margins: 1
                                        font.pixelSize: 11
                                        text: isNaN(parent.cellScore) ? "" : parent.cellScore.toString()
                                        verticalAlignment: Text.AlignVCenter

                                        property real fullScore: modelData.full_score !== undefined ? modelData.full_score : 100
                                        property bool scoreValid: {
                                            var v = parseFloat(text)
                                            if (isNaN(v)) return text === ""
                                            return v >= 0 && v <= fullScore
                                        }
                                        property bool scoreDirty: text !== "" && text !== (isNaN(parent.cellScore) ? "" : parent.cellScore.toString())

                                        // Invalid indicator via border
                                        Rectangle {
                                            anchors.fill: parent
                                            color: "transparent"
                                            border.width: parent.scoreDirty && !parent.scoreValid ? 2 : 0
                                            border.color: "#ef4444"
                                            radius: 4
                                        }

                                        Keys.onReturnPressed: {
                                            if (!scoreValid) return
                                            var v = parseFloat(text)
                                            if (!isNaN(v) && text !== "") {
                                                requiredApiClient.upsertScore(
                                                    requiredCourseUuid,
                                                    modelData.student_uuid,
                                                    modelData.unit_id,
                                                    v
                                                )
                                            } else {
                                                editingCell = null
                                            }
                                        }
                                        Keys.onEscapePressed: {
                                            editingCell = null
                                        }
                                        onActiveFocusChanged: {
                                            if (!activeFocus && parent.isEditing) {
                                                editingCell = null
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onClicked: {
                                            if (!isEditing) {
                                                editingCell = {rowIndex: modelData.row_index, unitId: modelData.unit_id}
                                                scoreEdit.forceActiveFocus()
                                                scoreEdit.selectAll()
                                            }
                                        }
                                    }
                                }
                            }

                            FluText {
                                Layout.preferredWidth: 70
                                text: modelData.weighted_total != null ? modelData.weighted_total.toFixed(1) : "--"
                                font.pixelSize: 11
                                font.bold: true
                                horizontalAlignment: Text.AlignRight
                            }
                            FluText {
                                Layout.preferredWidth: 44
                                text: modelData.rank != null ? modelData.rank.toString() : "--"
                                font.pixelSize: 11
                                textColor: modelData.rank <= 3 ? "#0f766e" : "#b3c0c8"
                                font.bold: modelData.rank <= 3
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }

                FluText {
                    visible: displayStudents.length === 0 && membersLoaded && scoresLoaded
                    Layout.alignment: Qt.AlignCenter
                    text: studentsData.length === 0 ? "该课程暂无学生" : "无匹配结果"
                    font.pixelSize: 13
                    textColor: "#53636d"
                }

                FluText {
                    visible: !membersLoaded || !scoresLoaded
                    Layout.alignment: Qt.AlignCenter
                    text: "加载中..."
                    font.pixelSize: 13
                    textColor: "#8ea1ad"
                }
            }
        }
    }
}
