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
    property string currentCourseUuid: ""
    property var currentCourseData: ({})

    // ========== SINGLETON API CLIENT ==========
    ApiClient {
        id: apiClient

        onLoginSuccess: function(token, role) {
            appWindow.loggedIn = true
            apiClient.listCourses()
        }

        onTokenExpired: {
            appWindow.loggedIn = false
            appWindow.currentPage = 0
        }
    }

    // ========== DYNAMIC COURSE MODEL ==========
    ListModel { id: courseModel }

    // Debounce timer: restores ComboBox selection after listCourses() completes
    Timer {
        id: restoreCourseTimer
        interval: 30
        onTriggered: {
            if (courseModel.count === 0) return
            var found = -1
            if (appWindow.currentCourseUuid !== "") {
                for (var i = 0; i < courseModel.count; i++) {
                    if (courseModel.get(i).uuid === appWindow.currentCourseUuid) {
                        found = i
                        break
                    }
                }
            }
            if (found >= 0) {
                courseSelector.currentIndex = found
            } else {
                courseSelector.currentIndex = 0
                var item = courseModel.get(0)
                appWindow.currentCourseUuid = item.uuid
                appWindow.currentCourseData = item
            }
        }
    }

    Connections {
        target: apiClient
        function onCourseListReset() {
            courseModel.clear()
            restoreCourseTimer.stop()
        }
        function onCourseListed(uuid, name, description, status, memberCount, myRole) {
            courseModel.append({
                uuid: uuid,
                name: name,
                description: description,
                status: status,
                memberCount: memberCount,
                myRole: myRole
            })
            restoreCourseTimer.restart()
        }
        function onCourseDeleted(uuid) {
            var wasSelected = (uuid === appWindow.currentCourseUuid)
            for (var i = 0; i < courseModel.count; i++) {
                if (courseModel.get(i).uuid === uuid) {
                    courseModel.remove(i)
                    break
                }
            }
            if (wasSelected) {
                if (courseModel.count > 0) {
                    courseSelector.currentIndex = 0
                    var item = courseModel.get(0)
                    appWindow.currentCourseUuid = item.uuid
                    appWindow.currentCourseData = item
                } else {
                    appWindow.currentCourseUuid = ""
                    appWindow.currentCourseData = ({})
                }
            }
        }
    }

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
                    id: courseSelector
                    Layout.fillWidth: true
                    Layout.bottomMargin: 20
                    textRole: "name"
                    valueRole: "uuid"
                    model: courseModel
                    onActivated: {
                        if (currentIndex >= 0) {
                            var item = courseModel.get(currentIndex)
                            appWindow.currentCourseUuid = item.uuid
                            appWindow.currentCourseData = item
                        }
                    }
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

                // Logout button
                FluTextButton {
                    text: "退出登录"
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: 8
                    onClicked: apiClient.logout()
                }

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
        "学科管理", "开课申请",
        "视频播放", "课程资源", "发布公告",
        "倒计时", "发消息", "AI 助手"
    ]

    // ===== PAGE COMPONENTS =====
    property var pageComps: [
        classInfoComp, rollCallComp, teamUpComp,
        studentInfoComp, subjectManageComp,
        courseAppComp, videoPlayerComp, resourceComp,
        announcementComp, countdownComp, messageComp, chatComp
    ]

    Component {
        id: loginComp
        LoginPage { requiredApiClient: apiClient }
    }
    Component { id: classInfoComp; ClassInfoPage { requiredApiClient: apiClient; requiredCourseUuid: currentCourseUuid } }
    Component { id: rollCallComp; RollCallPage { requiredApiClient: apiClient; requiredCourseUuid: currentCourseUuid } }
    Component { id: teamUpComp; TeamUpPage { requiredApiClient: apiClient; requiredCourseUuid: currentCourseUuid } }
    Component { id: studentInfoComp; StudentInfoPage { requiredApiClient: apiClient; requiredCourseUuid: currentCourseUuid } }
    Component { id: subjectManageComp; SubjectManagePage { requiredApiClient: apiClient; requiredCourseUuid: currentCourseUuid } }

    Component { id: courseAppComp; CourseApplicationPage { requiredApiClient: apiClient; requiredCourseUuid: currentCourseUuid } }
    Component { id: videoPlayerComp; VideoPlayerPage { requiredApiClient: apiClient; requiredCourseUuid: currentCourseUuid } }
    Component { id: resourceComp; ResourcePage { requiredApiClient: apiClient; requiredCourseUuid: currentCourseUuid } }
    Component { id: announcementComp; AnnouncementPage { requiredApiClient: apiClient; requiredCourseUuid: currentCourseUuid } }
    Component { id: countdownComp; CountdownPage {} }
    Component { id: messageComp; MessagePage { requiredApiClient: apiClient; requiredCourseUuid: currentCourseUuid } }
    Component { id: chatComp; ChatPage { requiredApiClient: apiClient } }
}
