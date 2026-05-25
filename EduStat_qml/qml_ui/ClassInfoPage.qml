import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import FluentUI
import EduStat.Backend 1.0

// 班级信息 Class Info Dashboard
Item {
    required property ApiClient requiredApiClient
    required property string requiredCourseUuid

    property var distData: ({})
    property var unitsData: ([])
    property var summaryData: ({})
    property var studentsData: ([])
    property string aiAnalysis: ""
    property bool loading: false
    property bool dataReady: false
    property bool summaryReady: false
    property bool pendingAiAnalysis: false

    // Use AgentBackend (beast library) for AI analysis — same approach as ChatPage
    AgentBackend {
        id: analysisAgent
        onOneShotChatFinished: function(content) { aiAnalysis = content }
        onOneShotChatError: function(msg) { aiAnalysis = "AI 分析失败: " + msg }
    }

    Component.onCompleted: {
        analysisAgent.setApiClient(requiredApiClient)
        if (requiredCourseUuid) {
            refreshData()
            pendingAiAnalysis = true
        }
    }

    onRequiredCourseUuidChanged: {
        if (visible && requiredCourseUuid) {
            refreshData()
            pendingAiAnalysis = true
        }
    }

    onVisibleChanged: {
        if (visible && requiredCourseUuid) refreshData()
    }

    function refreshData() {
        if (!requiredCourseUuid) return
        loading = true
        dataReady = false
        summaryReady = false
        studentsData = []
        requiredApiClient.fetchScoreDistribution(requiredCourseUuid)
        requiredApiClient.fetchUnits(requiredCourseUuid)
        requiredApiClient.fetchCourseDetail(requiredCourseUuid)
        requiredApiClient.fetchScoreSummary(requiredCourseUuid)
    }

    function tryAutoAnalysis() {
        if (pendingAiAnalysis && dataReady && summaryReady && distData && distData.total) {
            pendingAiAnalysis = false
            runQuickAnalysis()
        }
    }

    // Simple / quick analysis — auto-runs on page load, concise but informative
    function runQuickAnalysis() {
        if (!requiredCourseUuid || !distData || !distData.total) return
        var total = distData.total || 0
        var passRate = total > 0 ? Math.round((distData.passed || 0) / total * 100) : 0
        var avg = distData.average || 0
        var med = distData.median || 0
        var passed = distData.passed || 0
        var failed = distData.failed || 0

        // Calculate grade tiers
        var excellent = 0, good = 0, fair = 0, poor = 0
        for (var i = 0; i < studentsData.length; i++) {
            var s = studentsData[i].weighted_total
            if (s == null) continue
            if (s >= 90) excellent++
            else if (s >= 75) good++
            else if (s >= 60) fair++
            else poor++
        }

        var prompt =
            "你是一位教学分析师。请根据以下课程数据做简要但全面的评估，使用 Markdown 排版。\n\n" +
            "## 课程数据\n" +
            "- 课程：" + (currentCourseName || "未知") + "\n" +
            "- 学生总数：" + total + "\n" +
            "- 平均分：" + avg + " | 中位数：" + med + "\n" +
            "- 及格率：" + passRate + "%（" + passed + " 人及格，" + failed + " 人不及格）\n" +
            "- 优秀(>=90)：" + excellent + " 人 | 良好(>=75)：" + good + " 人 | 中等(>=60)：" + fair + " 人 | 不及格(<60)：" + poor + " 人\n\n" +
            "请按以下结构输出，每部分 3-5 句，要具体不要空泛：\n\n" +
            "### 整体评估\n" +
            "综合平均分、中位数、及格率，评定课程学业水平等级（优秀/良好/中等/薄弱），说明理由。\n\n" +
            "### 成绩分布特征\n" +
            "分析优秀-良好-中等-不及格四个层级的占比和分布形态，判断是否存在两极分化或趋中现象，指出最需关注的群体。\n\n" +
            "### 关键问题诊断\n" +
            "基于数据诊断 2-3 个具体的教学问题（如：缺乏拔尖生、中段学生占比过大、存在不及格风险等），每个问题说明判断依据。\n\n" +
            "### 教学改进建议\n" +
            "针对诊断出的问题，给出 3-4 条可操作的建议，每条 1-2 句话说明理由和预期效果。\n\n" +
            "注意：整体控制在 500-800 字，精炼有料，不要重复数据。"
        aiAnalysis = "正在生成简要分析..."
        analysisAgent.oneShotChat(prompt)
    }

    // Detailed analysis — manual trigger, per-student report quality
    function runDetailedAnalysis() {
        if (!requiredCourseUuid || !distData || !distData.total) return
        var total = distData.total || 0
        var passRate = total > 0 ? Math.round((distData.passed || 0) / total * 100) : 0
        var failRate = total > 0 ? Math.round((distData.failed || 0) / total * 100) : 0

        // Build per-student score table
        var studentTable = ""
        for (var i = 0; i < studentsData.length; i++) {
            var s = studentsData[i]
            var name = s.real_name || s.username || "?"
            var sNo = s.student_no || "-"
            var wt = s.weighted_total
            var totalScore = (wt != null) ? Number(wt).toFixed(1) : "N/A"
            var rank = s.rank || "-"
            var unitDetails = ""
            var scores = s.scores || []
            for (var j = 0; j < scores.length; j++) {
                var sc = scores[j]
                if (!sc) continue
                var uname = sc.unit_name
                if (!uname && sc.unit_id != null) uname = "单元" + sc.unit_id
                if (!uname) continue
                var sval = (sc.score != null) ? sc.score : "N/A"
                if (unitDetails) unitDetails += "、"
                unitDetails += uname + ":" + sval
            }
            studentTable += (i + 1) + ". " + name + " | 学号:" + sNo + " | 总分:" + totalScore + " | 排名:" + rank
            if (unitDetails) studentTable += " | " + unitDetails
            else studentTable += " | 无单元成绩"
            studentTable += "\n"
        }

        var prompt =
            "你是一位资深教学分析师，需要撰写一份可用于期末教学报告的详细分析。请根据以下数据，使用 Markdown 排版输出。\n\n" +
            "## 课程数据\n" +
            "- 课程名称：" + (currentCourseName || "未知") + "\n" +
            "- 学生总数：" + total + "\n" +
            "- 平均分：" + (distData.average || "N/A") + "\n" +
            "- 中位数：" + (distData.median || "N/A") + "\n" +
            "- 及格人数：" + (distData.passed || 0) + "（" + passRate + "%）\n" +
            "- 不及格人数：" + (distData.failed || 0) + "（" + failRate + "%）\n\n" +
            "## 学生个人成绩明细\n" +
            "```\n" + studentTable + "```\n\n" +
            "## 数据说明\n" +
            "- 总分显示 N/A 表示该生暂无加权总分，可能未录入足够单元成绩。\n" +
            "- 单元成绩显示 N/A 表示该单元尚未录入分数，分析时应标注为「待录入」。\n" +
            "- 无单元成绩的学生，请基于总分判断其层级，并在分析中注明数据不完整。\n" +
            "- 排名显示 - 表示尚未计算排名。\n\n" +
            "## 分析要求\n" +
            "请按以下结构输出一份严肃、专业、可直接放入期末教学报告的完整分析。每部分需足够详细，拒绝泛泛而谈。\n\n" +
            "### 一、整体成绩概况\n" +
            "用平均分、中位数、及格率综合评定课程整体学业水平，说明数据反映的教学成效。\n\n" +
            "### 二、学生分层与分布特征\n" +
            "按成绩将学生分为 3-4 个层级（如优秀/良好/及格/不及格），分析各层占比和特征，指出需重点关注的群体。\n\n" +
            "### 三、个别学生精准分析\n" +
            "逐一点评每位学生的学业表现：\n" +
            "- 总成绩所处位置（排名/层级）\n" +
            "- 各单元的强项与薄弱环节\n" +
            "- 与班级均分的差距\n" +
            "- 1-2 句针对性提升建议\n" +
            "要求覆盖每一位学生，不可遗漏。\n\n" +
            "### 四、教学问题诊断\n" +
            "从学生成绩数据中归纳出共性问题，结合教学单元内容，诊断 3-5 条教学中可能存在的薄弱环节。\n\n" +
            "### 五、改进措施与建议\n" +
            "针对诊断出的问题，给出 5-8 条具体、可操作的教学改进措施，每条说明针对什么问题和预期效果。\n\n" +
            "### 六、下学期重点关注\n" +
            "列出下学期应重点关注的指标、学生群体和教学策略。"
        aiAnalysis = "正在生成详细分析报告..."
        analysisAgent.oneShotChat(prompt)
    }

    property string currentCourseName: ""

    Connections {
        target: requiredApiClient

        function onScoreDistributionFetched(dist) {
            distData = dist
            loading = false
            dataReady = true
            tryAutoAnalysis()
        }
        function onScoreDistributionError(msg) {
            console.log("Distribution error:", msg)
            loading = false
            dataReady = true
        }
        function onScoreSummaryFetched(summary) {
            summaryData = summary
            var list = []
            var students = summary.students || []
            for (var i = 0; i < students.length; i++) {
                list.push(students[i])
            }
            studentsData = list
            summaryReady = true
            tryAutoAnalysis()
        }
        function onScoreSummaryError(msg) {
            console.log("Score summary error:", msg)
            summaryReady = true
        }
        function onUnitListReset() { unitsData = [] }
        function onUnitListed(id, name, weight, fullScore, order) {
            unitsData.push({id: id, name: name, weight: weight, fullScore: fullScore, order: order})
            unitsDataChanged()
        }
        function onCourseDetailFetched(detail) {
            currentCourseName = detail.name || ""
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 24

        // Left: main content area
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            // Header
            RowLayout {
                FluText {
                    text: currentCourseName ? currentCourseName + " \u00B7 班级信息总览" : "班级信息总览"
                    font.pixelSize: 18
                    font.bold: true
                }
                Item { Layout.fillWidth: true }
                FluFilledButton {
                    text: "刷新分析"
                    font.pixelSize: 12
                    onClicked: {
                        refreshData()
                        // AI analysis will be triggered after data arrives
                    }
                }
            }

            // Info hint
            FluFrame {
                Layout.fillWidth: true
                radius: 8
                padding: 12
                FluText {
                    anchors.fill: parent
                    text: "进入页面自动生成简要 AI 分析；点击「详细分析」可生成完整期末报告级教学分析。"
                    font.pixelSize: 11
                    textColor: "#8ea1ad"
                    wrapMode: Text.WordWrap
                }
            }

            // 4 Stat cards
            RowLayout {
                Layout.fillWidth: true
                spacing: 14
                StatCard { title: "学生总数"; value: distData.total ? distData.total.toString() : "--" }
                StatCard { title: "整体均分"; value: distData.average ? distData.average.toString() : "--" }
                StatCard { title: "中位数"; value: distData.median ? distData.median.toString() : "--" }
                StatCard {
                    title: "及格率"
                    value: distData.total > 0
                        ? Math.round(distData.passed / distData.total * 100) + "%"
                        : "--"
                }
            }

            // Charts section
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 14

                // Left: distribution bar chart + unit info
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 14

                    // Score distribution
                    FluFrame {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredHeight: 220
                        radius: 12
                        padding: 16

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 10
                            FluText {
                                text: "成绩段分布"
                                font.pixelSize: 13
                                font.bold: true
                            }
                            FluText {
                                text: "各分数段人数统计"
                                font.pixelSize: 10
                                textColor: "#53636d"
                            }

                            ColumnLayout {
                                id: barChart
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 4

                                Repeater {
                                    model: distData.bands ? distData.bands : []
                                    delegate: RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        FluText {
                                            Layout.preferredWidth: 50
                                            text: modelData.range
                                            font.pixelSize: 11
                                            textColor: "#b3c0c8"
                                        }

                                        // Progress bar with clipping container
                                        Item {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 22

                                            Rectangle {
                                                anchors {
                                                    left: parent.left
                                                    top: parent.top
                                                    bottom: parent.bottom
                                                }
                                                radius: 4
                                                color: "#0f766e"
                                                width: {
                                                    var maxCount = 0
                                                    var bands = distData.bands || []
                                                    for (var i = 0; i < bands.length; i++)
                                                        maxCount = Math.max(maxCount, bands[i].count)
                                                    var avail = parent.width
                                                    var ratio = maxCount > 0 ? modelData.count / maxCount : 0
                                                    return Math.min(ratio * avail * 0.9, avail)
                                                }
                                            }
                                        }

                                        FluText {
                                            text: modelData.count
                                            font.pixelSize: 11
                                            font.bold: true
                                            Layout.preferredWidth: 30
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Unit list
                    FluFrame {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredHeight: 200
                        radius: 12
                        padding: 16

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 10
                            FluText {
                                text: "教学单元"
                                font.pixelSize: 13
                                font.bold: true
                            }
                            FluText {
                                text: "当前课程单元及权重"
                                font.pixelSize: 10
                                textColor: "#53636d"
                            }

                            ListView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                spacing: 4
                                model: unitsData

                                delegate: RowLayout {
                                    width: ListView.view.width
                                    height: 30
                                    spacing: 10

                                    FluText {
                                        text: modelData.order + ". " + modelData.name
                                        font.pixelSize: 11
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }
                                    FluText {
                                        text: "满分 " + modelData.fullScore
                                        font.pixelSize: 10
                                        textColor: "#8ea1ad"
                                        Layout.preferredWidth: 60
                                        horizontalAlignment: Text.AlignRight
                                    }
                                    FluText {
                                        text: "权重 " + (modelData.weight * 100).toFixed(0) + "%"
                                        font.pixelSize: 10
                                        textColor: "#0f766e"
                                        Layout.preferredWidth: 60
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }
                            }
                        }
                    }
                }

                // Right: data overview
                FluFrame {
                    Layout.preferredWidth: 300
                    Layout.fillHeight: true
                    radius: 12
                    padding: 20

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 14

                        FluText {
                            text: "数据总览"
                            font.pixelSize: 14
                            font.bold: true
                        }
                        FluText {
                            text: "成绩分布统计"
                            font.pixelSize: 10
                            textColor: "#53636d"
                        }

                        Item { Layout.preferredHeight: 10 }

                        StatsBlock {
                            label: "总人数"
                            value: distData.total ? distData.total.toString() : "--"
                            iconText: "\uD83D\uDC65"
                        }
                        StatsBlock {
                            label: "平均分"
                            value: distData.average ? distData.average.toString() : "--"
                            iconText: "\uD83D\uDCCA"
                        }
                        StatsBlock {
                            label: "中位数"
                            value: distData.median ? distData.median.toString() : "--"
                            iconText: "\u2195"
                        }
                        StatsBlock {
                            label: "及格人数"
                            value: distData.passed ? distData.passed.toString() : "--"
                            iconText: "\u2714"
                        }
                        StatsBlock {
                            label: "不及格人数"
                            value: distData.failed ? distData.failed.toString() : "--"
                            valueColor: distData.failed > 0 ? "#ef4444" : "#22c55e"
                            iconText: "\u2718"
                        }
                        StatsBlock {
                            label: "教学单元"
                            value: unitsData.length.toString()
                            iconText: "\uD83D\uDCDA"
                        }

                        FluDivider { Layout.fillWidth: true }

                        // Auto-computed grade tiers from summary data
                        FluText {
                            text: "成绩分层"
                            font.pixelSize: 12
                            font.bold: true
                            Layout.topMargin: 4
                        }

                        StatsBlock {
                            label: "优秀 (≥90)"
                            value: {
                                var cnt = 0
                                for (var i = 0; i < studentsData.length; i++)
                                    if (studentsData[i].weighted_total >= 90) cnt++
                                return cnt.toString()
                            }
                            iconText: "\u2B50"
                            valueColor: "#f59e0b"
                        }
                        StatsBlock {
                            label: "良好 (≥75)"
                            value: {
                                var cnt = 0
                                for (var i = 0; i < studentsData.length; i++) {
                                    var s = studentsData[i].weighted_total
                                    if (s >= 75 && s < 90) cnt++
                                }
                                return cnt.toString()
                            }
                            iconText: "\uD83D\uDC4D"
                            valueColor: "#22c55e"
                        }
                        StatsBlock {
                            label: "待提升 (<60)"
                            value: {
                                var cnt = 0
                                for (var i = 0; i < studentsData.length; i++)
                                    if (studentsData[i].weighted_total < 60) cnt++
                                return cnt.toString()
                            }
                            iconText: "\u26A0"
                            valueColor: "#ef4444"
                        }

                        Item { Layout.fillHeight: true }
                    }
                }
            }
        }

        // Right: AI Analysis panel
        FluFrame {
            Layout.preferredWidth: 360
            Layout.minimumWidth: 300
            Layout.fillHeight: true
            radius: 12

            // Export dialog
            FileDialog {
                id: exportAnalysisDialog
                title: "导出教学分析"
                nameFilters: ["Markdown (*.md)", "文本文件 (*.txt)"]
                fileMode: FileDialog.SaveFile
                defaultSuffix: "md"
                selectedFile: {
                    var ts = new Date().toISOString().replace(/[:.]/g, "-").substring(0, 19)
                    return requiredApiClient.homeDir() + "/" +
                        (currentCourseName || "analysis") + "_分析_" + ts + ".md"
                }
                onAccepted: {
                    var path = exportAnalysisDialog.selectedFile.toString()
                    if (path.startsWith("file://")) path = path.substring(7)
                    requiredApiClient.saveTextFile(path, aiAnalysis)
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                RowLayout {
                    FluText {
                        text: "教学分析建议"
                        font.pixelSize: 15
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    FluButton {
                        text: "简要分析"
                        font.pixelSize: 10
                        enabled: dataReady && distData && distData.total
                        onClicked: runQuickAnalysis()
                    }
                    FluButton {
                        text: "详细分析"
                        font.pixelSize: 10
                        enabled: dataReady && distData && distData.total
                        onClicked: runDetailedAnalysis()
                    }
                    FluButton {
                        text: "导出分析"
                        font.pixelSize: 10
                        enabled: aiAnalysis && aiAnalysis !== "正在分析..." &&
                                 !aiAnalysis.startsWith("AI 分析失败")
                        onClicked: exportAnalysisDialog.open()
                    }
                }

                FluFrame {
                    Layout.fillWidth: true
                    radius: 6
                    color: Qt.rgba(20/255, 23/255, 28/255, 1)
                    padding: 10
                    RowLayout {
                        anchors.fill: parent
                        spacing: 10
                        FluText {
                            text: "分析来源：AI 助手"
                            font.pixelSize: 11
                            textColor: "#8ea1ad"
                            Layout.fillWidth: true
                        }
                        FluText {
                            text: currentCourseName || "等待加载..."
                            font.pixelSize: 10
                            textColor: "#0f766e"
                        }
                    }
                }

                ScrollView {
                    id: analysisScroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    TextEdit {
                        id: analysisTextEdit
                        width: analysisScroll.availableWidth
                        text: aiAnalysis || "进入页面自动生成简要分析。点击「详细分析」按钮可生成完整的期末报告级教学分析。"
                        textFormat: aiAnalysis && aiAnalysis !== "正在分析..." &&
                                    !aiAnalysis.startsWith("AI 分析失败")
                                    ? TextEdit.MarkdownText : TextEdit.PlainText
                        font { pixelSize: 12; family: "Source Han Sans CN, Noto Sans CJK TC, sans-serif" }
                        color: aiAnalysis ? "#d7e1e8" : "#7f8c96"
                        wrapMode: TextEdit.WordWrap
                        readOnly: true
                        selectByMouse: true
                        padding: 0
                    }
                }
            }
        }
    }

    // ========= COMPONENTS ==========

    component StatCard: FluFrame {
        required property string title
        required property string value

        Layout.fillWidth: true
        Layout.preferredHeight: 90
        radius: 14
        padding: 0

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 6
            FluText {
                text: title
                font.pixelSize: 11
                textColor: "#8ea1ad"
            }
            FluText {
                text: value
                font.pixelSize: 22
                font.bold: true
                textColor: "#f8fbfc"
            }
        }
    }

    component StatsBlock: RowLayout {
        required property string label
        required property string value
        required property string iconText
        property string valueColor: "#e0e6ea"

        spacing: 12
        Layout.fillWidth: true

        FluText {
            text: iconText
            font.pixelSize: 14
            Layout.preferredWidth: 22
        }
        FluText {
            text: label
            font.pixelSize: 11
            textColor: "#8ea1ad"
            Layout.fillWidth: true
        }
        FluText {
            text: value
            font.pixelSize: 14
            font.bold: true
            textColor: valueColor
        }
    }
}
