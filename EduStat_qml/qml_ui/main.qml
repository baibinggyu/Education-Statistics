import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import FluentUI
import EduStat.Backend 1.0

ApplicationWindow {
    id: appWindow
    visible: true
    width: 1200
    height: 800
    minimumWidth: 960
    minimumHeight: 680
    title: "EduStat 2.0 教学统计系统"

    Component.onCompleted: {
        FluTheme.darkMode = 2
        FluTheme.primaryColor = "#0f766e"
    }

    property int currentPage: 0
    property bool loggedIn: false

    // ========== LOGIN SCREEN ==========
    Loader {
        anchors.fill: parent
        active: !loggedIn
        sourceComponent: loginComp
    }

    // ========== MAIN APP ==========
    RowLayout {
        anchors.fill: parent
        spacing: 0
        visible: loggedIn

        // ===== SIDEBAR =====
        Rectangle {
            Layout.preferredWidth: 220
            Layout.minimumWidth: 200
            Layout.fillHeight: true
            color: FluTheme.dark ? Qt.rgba(28/255, 31/255, 36/255, 1) : Qt.rgba(243/255, 243/255, 243/255, 1)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 0

                FluText {
                    text: "EduStat"
                    font.pixelSize: 20
                    font.bold: true
                    textColor: "#f7fafc"
                }
                FluText {
                    text: "教学统计工作台"
                    font.pixelSize: 10
                    textColor: "#9eabb5"
                    Layout.topMargin: 4
                }

                FluDivider {
                    Layout.fillWidth: true
                    Layout.topMargin: 18
                    Layout.bottomMargin: 18
                }

                FluText {
                    text: "当前学科"
                    font.pixelSize: 11
                    font.bold: true
                    textColor: "#d7e1e8"
                    Layout.bottomMargin: 8
                }
                FluComboBox {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 20
                    model: ["电子技术基础", "学科教学设计"]
                    currentIndex: 0
                }

                FluText {
                    text: "功能导航"
                    font.pixelSize: 11
                    font.bold: true
                    textColor: "#d7e1e8"
                    Layout.bottomMargin: 10
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: navItems
                        delegate: Rectangle {
                            required property int index
                            required property string modelData
                            property bool isActive: appWindow.currentPage === index

                            Layout.fillWidth: true
                            height: 38
                            radius: 8
                            color: {
                                if (isActive) return "#0f766e"
                                if (hoverArea.containsMouse) return Qt.rgba(43/255, 50/255, 56/255, 1)
                                return "transparent"
                            }

                            FluText {
                                anchors {
                                    left: parent.left
                                    leftMargin: 14
                                    verticalCenter: parent.verticalCenter
                                }
                                text: modelData
                                font.pixelSize: 12
                                font.bold: isActive
                                textColor: isActive ? "#ffffff" : "#b3c0c8"
                            }

                            MouseArea {
                                id: hoverArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: appWindow.currentPage = index
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                FluText {
                    text: "EduStat v2.0"
                    font.pixelSize: 9
                    textColor: "#5a6570"
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        // Sidebar border
        Rectangle {
            width: 1
            Layout.fillHeight: true
            color: FluTheme.dark ? Qt.rgba(49/255, 56/255, 64/255, 1) : Qt.rgba(220/255, 220/255, 220/255, 1)
        }

        // ===== CONTENT =====
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: FluTheme.dark ? Qt.rgba(32/255, 35/255, 40/255, 1) : "#f5f5f5"

            Loader {
                anchors.fill: parent
                anchors.margins: 24
                sourceComponent: {
                    if (appWindow.currentPage >= 0 && appWindow.currentPage < pageComps.length)
                        return pageComps[appWindow.currentPage]
                    return null
                }
            }
        }
    }

    // ===== NAV ITEMS =====
    property var navItems: [
        "班级信息", "点名", "组队", "学生信息",
        "学科管理", "增加学科", "开课申请",
        "视频播放", "课程资源", "发布公告",
        "倒计时", "发消息", "AI 助手"
    ]

    // ===== PAGE COMPONENTS =====
    property var pageComps: [
        classInfoComp, rollCallComp, teamUpComp,
        studentInfoComp, subjectManageComp, addSubjectComp,
        courseAppComp, videoPlayerComp, resourceComp,
        announcementComp, countdownComp, messageComp, chatComp
    ]

    Component { id: loginComp; LoginPage { onLogin: loggedIn = true } }
    Component { id: classInfoComp; ClassInfoPage {} }
    Component { id: rollCallComp; RollCallPage {} }
    Component { id: teamUpComp; TeamUpPage {} }
    Component { id: studentInfoComp; StudentInfoPage {} }
    Component { id: subjectManageComp; SubjectManagePage {} }
    Component { id: addSubjectComp; AddSubjectPage {} }
    Component { id: courseAppComp; CourseApplicationPage {} }
    Component { id: videoPlayerComp; VideoPlayerPage {} }
    Component { id: resourceComp; ResourcePage {} }
    Component { id: announcementComp; AnnouncementPage {} }
    Component { id: countdownComp; CountdownPage {} }
    Component { id: messageComp; MessagePage {} }
    Component { id: chatComp; ChatPage {} }
}
