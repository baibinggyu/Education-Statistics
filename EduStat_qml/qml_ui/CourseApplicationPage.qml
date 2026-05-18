import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import FluentUI

// 开课申请 Course Application Page
// DB ref: courses (name, description, teacher_id, status)
//          units (course_id, name, weight, full_score, unit_order)
//          course_members (course_id, user_id, member_role)
Item {
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
                    text: "教师: 陈老师"
                    font.pixelSize: 11
                    textColor: "#8ea1ad"
                }
            }

            FluText {
                text: "填写课程信息并提交申请，审核通过后即可开始教学。以下信息对应数据库 courses / units 表结构。"
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
                        text: "基本信息（courses 表）"
                        font.pixelSize: 14
                        font.bold: true
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: 12
                        columnSpacing: 16

                        // Row 1
                        FluText {
                            text: "课程名称 *"
                            font.pixelSize: 11
                            textColor: "#b3c0c8"
                            Layout.alignment: Qt.AlignVCenter
                        }
                        FluTextBox {
                            Layout.fillWidth: true
                            placeholderText: "如：电子技术基础"
                        }

                        // Row 2
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

                        // Row 3
                        FluText {
                            text: "开课学期"
                            font.pixelSize: 11
                            textColor: "#b3c0c8"
                            Layout.alignment: Qt.AlignVCenter
                        }
                        FluComboBox {
                            Layout.fillWidth: true
                            model: ["2025-2026学年第一学期", "2025-2026学年第二学期"]
                            currentIndex: 0
                        }

                        // Row 4
                        FluText {
                            text: "学分"
                            font.pixelSize: 11
                            textColor: "#b3c0c8"
                            Layout.alignment: Qt.AlignVCenter
                        }
                        FluTextBox {
                            Layout.fillWidth: true
                            placeholderText: "如：3.0"
                            text: "3.0"
                        }

                        // Row 5
                        FluText {
                            text: "总学时"
                            font.pixelSize: 11
                            textColor: "#b3c0c8"
                            Layout.alignment: Qt.AlignVCenter
                        }
                        FluTextBox {
                            Layout.fillWidth: true
                            placeholderText: "如：48"
                            text: "48"
                        }

                        // Row 6
                        FluText {
                            text: "限选人数"
                            font.pixelSize: 11
                            textColor: "#b3c0c8"
                            Layout.alignment: Qt.AlignVCenter
                        }
                        FluTextBox {
                            Layout.fillWidth: true
                            placeholderText: "如：60"
                            text: "60"
                        }

                        // Row 7
                        FluText {
                            text: "上课地点"
                            font.pixelSize: 11
                            textColor: "#b3c0c8"
                            Layout.alignment: Qt.AlignVCenter
                        }
                        FluTextBox {
                            Layout.fillWidth: true
                            placeholderText: "如：教学楼A301"
                        }

                        // Row 8
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

                    // Description
                    FluText {
                        text: "课程描述（courses.description）"
                        font.pixelSize: 11
                        textColor: "#b3c0c8"
                    }
                    FluMultilineTextBox {
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
                            text: "教学单元（units 表）"
                            font.pixelSize: 14
                            font.bold: true
                        }
                        Item { Layout.fillWidth: true }
                        FluButton {
                            text: "+ 添加单元"
                            font.pixelSize: 11
                        }
                    }

                    FluText {
                        text: "每个单元对应数据库 units 表一条记录：单元名称、权重、满分、排序。"
                        font.pixelSize: 10
                        textColor: "#8ea1ad"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
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

                            FluText {
                                Layout.preferredWidth: 40
                                text: "序号"
                                font.pixelSize: 11
                                font.bold: true
                            }
                            FluText {
                                Layout.fillWidth: true
                                text: "单元名称"
                                font.pixelSize: 11
                                font.bold: true
                            }
                            FluText {
                                Layout.preferredWidth: 80
                                text: "权重"
                                font.pixelSize: 11
                                font.bold: true
                            }
                            FluText {
                                Layout.preferredWidth: 80
                                text: "满分"
                                font.pixelSize: 11
                                font.bold: true
                            }
                            FluText {
                                Layout.preferredWidth: 80
                                text: "学时"
                                font.pixelSize: 11
                                font.bold: true
                            }
                            FluText {
                                Layout.preferredWidth: 50
                                text: "操作"
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }
                    }

                    // Units rows
                    ListView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 200
                        clip: true
                        model: [
                            { order: "1", name: "绪论与基础知识", weight: "0.15", score: "100", hours: "6" },
                            { order: "2", name: "半导体器件", weight: "0.20", score: "100", hours: "10" },
                            { order: "3", name: "放大电路基础", weight: "0.25", score: "100", hours: "12" },
                            { order: "4", name: "集成运算放大器", weight: "0.25", score: "100", hours: "10" },
                            { order: "5", name: "直流电源", weight: "0.15", score: "100", hours: "10" }
                        ]

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
                                FluText {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    font.pixelSize: 11
                                }
                                FluText {
                                    Layout.preferredWidth: 80
                                    text: modelData.weight
                                    font.pixelSize: 11
                                    textColor: "#0f766e"
                                }
                                FluText {
                                    Layout.preferredWidth: 80
                                    text: modelData.score
                                    font.pixelSize: 11
                                }
                                FluText {
                                    Layout.preferredWidth: 80
                                    text: modelData.hours
                                    font.pixelSize: 11
                                    textColor: "#8ea1ad"
                                }
                                FluText {
                                    Layout.preferredWidth: 50
                                    text: "删除"
                                    font.pixelSize: 10
                                    textColor: "#ef4444"
                                }
                            }
                        }
                    }

                    RowLayout {
                        FluText {
                            text: "权重合计: 1.00"
                            font.pixelSize: 11
                            textColor: "#22c55e"
                        }
                        Item { Layout.fillWidth: true }
                        FluButton {
                            text: "按学时自动分配权重"
                            font.pixelSize: 10
                        }
                    }
                }
            }

            // ===== SECTION 3: Application notes =====
            FluFrame {
                Layout.fillWidth: true
                radius: 10
                padding: 20

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12

                    FluText {
                        text: "申请备注"
                        font.pixelSize: 14
                        font.bold: true
                    }

                    FluText {
                        text: "选填：补充说明教材选用、教学大纲、考核方式等信息，供审核人参考。"
                        font.pixelSize: 10
                        textColor: "#8ea1ad"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: 10
                        columnSpacing: 16

                        FluText {
                            text: "教材"
                            font.pixelSize: 11
                            textColor: "#b3c0c8"
                            Layout.alignment: Qt.AlignVCenter
                        }
                        FluTextBox {
                            Layout.fillWidth: true
                            placeholderText: "教材名称、作者、出版社"
                        }

                        FluText {
                            text: "考核方式"
                            font.pixelSize: 11
                            textColor: "#b3c0c8"
                            Layout.alignment: Qt.AlignVCenter
                        }
                        FluComboBox {
                            Layout.fillWidth: true
                            model: ["考试", "考查", "考试+考查"]
                            currentIndex: 0
                        }
                    }

                    FluText {
                        text: "补充说明"
                        font.pixelSize: 11
                        textColor: "#b3c0c8"
                    }
                    FluMultilineTextBox {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 80
                        placeholderText: "其他需要说明的内容..."
                        wrapMode: Text.WordWrap
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
                        text: "courses.status 默认为 'normal'，提交后等待管理员审核。审核通过后自动创建 course_members 记录。"
                        font.pixelSize: 10
                        textColor: "#53636d"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    FluButton {
                        text: "保存草稿"
                        font.pixelSize: 12
                    }

                    FluFilledButton {
                        Layout.preferredHeight: 42
                        Layout.preferredWidth: 140
                        text: "提交申请"
                        font.pixelSize: 13
                        font.bold: true
                    }
                }
            }

            // Bottom spacer
            Item { Layout.preferredHeight: 16 }
        }
    }
}
