import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import FluentUI
import EduStat.Backend 1.0

// 开课申请 Course Application Page
Item {
    required property ApiClient requiredApiClient
    required property string requiredCourseUuid



    property var unitRows: [
        { order: 1, name: "绪论与基础知识", weight: "0.15", score: "100", hours: "6" },
        { order: 2, name: "半导体器件", weight: "0.20", score: "100", hours: "10" },
        { order: 3, name: "放大电路基础", weight: "0.25", score: "100", hours: "12" },
        { order: 4, name: "集成运算放大器", weight: "0.25", score: "100", hours: "10" },
        { order: 5, name: "直流电源", weight: "0.15", score: "100", hours: "10" }
    ]
    property string courseName: ""
    property string statusMessage: ""
    property bool submitting: false
    property string teacherName: "加载中..."

    Component.onCompleted: { requiredApiClient.fetchCurrentUser() }

    Connections {
        target: requiredApiClient
        function onUserFetched(uuid, username, role) {
            teacherName = username + " (" + role + ")"
        }
        function onCourseCreated(uuid, name) {
            for (var i = 0; i < unitRows.length; i++) {
                var u = unitRows[i]
                requiredApiClient.createUnit(uuid, u.name, parseFloat(u.weight) || 0,
                                     parseFloat(u.score) || 100, u.order)
            }
            statusMessage = "课程「" + name + "」申请提交成功"
            submitting = false
            // Refresh course list in sidebar and other pages
            requiredApiClient.listCourses()
        }
        function onCourseCreateError(msg) {
            statusMessage = "提交失败: " + msg
            submitting = false
        }
    }

    function totalWeight() {
        var sum = 0
        for (var i = 0; i < unitRows.length; i++) {
            sum += parseFloat(unitRows[i].weight) || 0
        }
        return sum.toFixed(2)
    }

    function submitApplication() {
        if (!courseName) {
            statusMessage = "请填写课程名称"
            return
        }
        submitting = true
        statusMessage = "正在提交..."
        // Encode extra metadata in description as JSON
        var extra = {
            semester: courseSemester.currentText || "",
            credits: creditsField.text || "",
            hours: hoursField.text || "",
            maxStudents: maxField.text || "",
            location: locationField.text || ""
        }
        var desc = courseDescField.text || ""
        if (desc) desc += "\n---\n"
        desc += JSON.stringify(extra)
        requiredApiClient.createCourse(courseName, desc)
    }

    ScrollView {
        anchors.fill: parent
        clip: true
        ScrollBar.vertical: FluScrollBar {}

        ColumnLayout {
            width: parent.width
            spacing: 20

            // Page header
            RowLayout {
                Layout.fillWidth: true
                FluText {
                    text: "开课申请"
                    font.pixelSize: 20
                    font.bold: true
                }
                Item { Layout.fillWidth: true }
                FluText {
                    text: "教师: " + teacherName
                    font.pixelSize: 11
                    textColor: "#8ea1ad"
                }
                FluText {
                    visible: statusMessage !== ""
                    text: statusMessage
                    font.pixelSize: 11
                    textColor: statusMessage.includes("成功") ? "#22c55e" : "#ef4444"
                    Layout.leftMargin: 16
                }
            }

            FluText {
                text: "填写课程信息并提交申请，审核通过后即可开始教学。"
                font.pixelSize: 11
                textColor: "#8ea1ad"
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            // ===== SECTION 1: Basic course info =====
            FluFrame {
                Layout.fillWidth: true
                radius: 10
                padding: 20

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 14

                    FluText {
                        text: "基本信息"
                        font.pixelSize: 14
                        font.bold: true
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: 12
                        columnSpacing: 16

                        FluText {
                            text: "课程名称 *"
                            font.pixelSize: 11
                            textColor: "#b3c0c8"
                            Layout.alignment: Qt.AlignVCenter
                        }
                        FluTextBox {
                            Layout.fillWidth: true
                            placeholderText: "如：电子技术基础"
                            onTextChanged: courseName = text
                        }

                        FluText {
                            text: "课程类别"
                            font.pixelSize: 11
                            textColor: "#b3c0c8"
                            Layout.alignment: Qt.AlignVCenter
                        }
                        FluComboBox {
                            Layout.fillWidth: true
                            model: ["必修课", "选修课", "通识课", "实验课", "实训课"]
                            currentIndex: 0
                        }

                        FluText {
                            text: "开课学期"
                            font.pixelSize: 11
                            textColor: "#b3c0c8"
                            Layout.alignment: Qt.AlignVCenter
                        }
                        FluComboBox {
                            id: courseSemester
                            Layout.fillWidth: true
                            model: ["2025-2026学年第一学期", "2025-2026学年第二学期"]
                            currentIndex: 0
                        }

                        FluText {
                            text: "学分"
                            font.pixelSize: 11
                            textColor: "#b3c0c8"
                            Layout.alignment: Qt.AlignVCenter
                        }
                        FluTextBox {
                            id: creditsField
                            Layout.fillWidth: true
                            placeholderText: "如：3.0"
                            text: "3.0"
                        }

                        FluText {
                            text: "总学时"
                            font.pixelSize: 11
                            textColor: "#b3c0c8"
                            Layout.alignment: Qt.AlignVCenter
                        }
                        FluTextBox {
                            id: hoursField
                            Layout.fillWidth: true
                            placeholderText: "如：48"
                            text: "48"
                        }

                        FluText {
                            text: "限选人数"
                            font.pixelSize: 11
                            textColor: "#b3c0c8"
                            Layout.alignment: Qt.AlignVCenter
                        }
                        FluTextBox {
                            id: maxField
                            Layout.fillWidth: true
                            placeholderText: "如：60"
                            text: "60"
                        }

                        FluText {
                            text: "上课地点"
                            font.pixelSize: 11
                            textColor: "#b3c0c8"
                            Layout.alignment: Qt.AlignVCenter
                        }
                        FluTextBox {
                            id: locationField
                            Layout.fillWidth: true
                            placeholderText: "如：教学楼A301"
                        }

                        FluText {
                            text: "上课时间"
                            font.pixelSize: 11
                            textColor: "#b3c0c8"
                            Layout.alignment: Qt.AlignVCenter
                        }
                        RowLayout {
                            FluComboBox {
                                Layout.preferredWidth: 90
                                model: ["周一", "周二", "周三", "周四", "周五"]
                                currentIndex: 0
                            }
                            FluComboBox {
                                Layout.preferredWidth: 80
                                model: ["第1-2节", "第3-4节", "第5-6节", "第7-8节"]
                                currentIndex: 0
                            }
                        }
                    }

                    FluDivider { Layout.fillWidth: true }

                    FluText {
                        text: "课程描述"
                        font.pixelSize: 11
                        textColor: "#b3c0c8"
                    }
                    FluMultilineTextBox {
                        id: courseDescField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 100
                        placeholderText: "请输入课程简介、教学目标、主要内容等..."
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // ===== SECTION 2: Teaching units =====
            FluFrame {
                Layout.fillWidth: true
                radius: 10
                padding: 20

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        FluText {
                            text: "教学单元"
                            font.pixelSize: 14
                            font.bold: true
                        }
                        Item { Layout.fillWidth: true }
                        FluButton {
                            text: "+ 添加单元"
                            font.pixelSize: 11
                            onClicked: {
                                unitRows.push({
                                    order: unitRows.length + 1,
                                    name: "新单元",
                                    weight: "0",
                                    score: "100",
                                    hours: "0"
                                })
                                unitRowsChanged()
                            }
                        }
                    }

                    // Units table header
                    Rectangle {
                        Layout.fillWidth: true
                        height: 38
                        color: Qt.rgba(0,0,0,0.08)
                        radius: 6

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 0

                            FluText { Layout.preferredWidth: 40; text: "序号"; font.pixelSize: 11; font.bold: true }
                            FluText { Layout.fillWidth: true; text: "单元名称"; font.pixelSize: 11; font.bold: true }
                            FluText { Layout.preferredWidth: 80; text: "权重"; font.pixelSize: 11; font.bold: true }
                            FluText { Layout.preferredWidth: 80; text: "满分"; font.pixelSize: 11; font.bold: true }
                            FluText { Layout.preferredWidth: 80; text: "学时"; font.pixelSize: 11; font.bold: true }
                        }
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 200
                        clip: true
                        model: unitRows

                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: ListView.view.width
                            height: 38
                            color: index % 2 === 0 ? "transparent" : Qt.rgba(0,0,0,0.04)
                            radius: 4

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 0

                                FluText {
                                    Layout.preferredWidth: 40
                                    text: modelData.order
                                    font.pixelSize: 11
                                    textColor: "#8ea1ad"
                                }
                                FluTextBox {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    font.pixelSize: 11
                                    Layout.margins: 2
                                    Layout.preferredHeight: 28
                                    onTextChanged: { unitRows[index].name = text }
                                }
                                FluTextBox {
                                    Layout.preferredWidth: 80
                                    text: modelData.weight
                                    font.pixelSize: 11
                                    Layout.margins: 2
                                    Layout.preferredHeight: 28
                                    onTextChanged: { unitRows[index].weight = text }
                                }
                                FluTextBox {
                                    Layout.preferredWidth: 80
                                    text: modelData.score
                                    font.pixelSize: 11
                                    Layout.margins: 2
                                    Layout.preferredHeight: 28
                                    onTextChanged: { unitRows[index].score = text }
                                }
                                FluTextBox {
                                    Layout.preferredWidth: 80
                                    text: modelData.hours
                                    font.pixelSize: 11
                                    Layout.margins: 2
                                    Layout.preferredHeight: 28
                                    onTextChanged: { unitRows[index].hours = text }
                                }
                            }
                        }
                    }

                    FluText {
                        text: "权重合计: " + totalWeight()
                        font.pixelSize: 11
                        textColor: totalWeight() === "1.00" ? "#22c55e" : "#ef4444"
                    }
                }
            }

            // ===== Submit bar =====
            FluFrame {
                Layout.fillWidth: true
                radius: 10
                padding: 16

                RowLayout {
                    anchors.fill: parent
                    spacing: 12

                    FluText {
                        text: "提交后课程将立即创建，您可以随后添加学生成员和视频资源。"
                        font.pixelSize: 10
                        textColor: "#53636d"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    FluFilledButton {
                        Layout.preferredHeight: 42
                        Layout.preferredWidth: 140
                        text: submitting ? "提交中..." : "提交申请"
                        font.pixelSize: 13
                        font.bold: true
                        enabled: !submitting && courseName !== ""
                        onClicked: submitApplication()
                    }
                }
            }

            Item { Layout.preferredHeight: 16 }
        }
    }
}
