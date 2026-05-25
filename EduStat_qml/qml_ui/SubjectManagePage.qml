import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import FluentUI
import EduStat.Backend 1.0

// 学科管理 Subject Management Page
Item {
    required property ApiClient requiredApiClient
    required property string requiredCourseUuid



    property var currentUnits: ([])

    ListModel { id: coursesModel }
    property var pendingDeleteUuid: ""
    property string pendingDeleteName: ""

    MessageDialog {
        id: deleteConfirmDialog
        title: "确认删除"
        text: "确定要删除学科「" + pendingDeleteName + "」吗？\n此操作不可恢复。"
        buttons: MessageDialog.Ok | MessageDialog.Cancel
        onAccepted: {
            if (pendingDeleteUuid) requiredApiClient.deleteCourse(pendingDeleteUuid)
        }
    }

    Component.onCompleted: { requiredApiClient.listCourses() }

    Connections {
        target: requiredApiClient
        function onCourseListReset() { staggeredLayout.clear() }
        function onCourseListed(uuid, name, description, status, memberCount, myRole) {
            coursesModel.append({uuid: uuid, name: name, description: description,
                                 status: status, memberCount: memberCount, myRole: myRole})
        }
        function onUnitListReset() { currentUnits = [] }
        function onUnitListed(id, name, weight, fullScore, order) {
            currentUnits.push({id: id, name: name, weight: weight, fullScore: fullScore, order: order})
            currentUnitsChanged()
        }
        function onCourseDeleted(uuid) {
            for (var i = 0; i < coursesModel.count; i++) {
                if (coursesModel.get(i).uuid === uuid) {
                    coursesModel.remove(i)
                    break
                }
            }
        }
        function onCourseDeleteError(msg) { console.log("Delete error:", msg) }
    }

    function selectCourse(c) {
        currentUnits = []
        requiredApiClient.fetchUnits(c.uuid)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        // Header
        RowLayout {
            Layout.fillWidth: true
            FluText {
                text: "学科管理"
                font.pixelSize: 18
                font.bold: true
            }
            Item { Layout.fillWidth: true }
            FluButton {
                text: "刷新列表"
                font.pixelSize: 12
                onClicked: requiredApiClient.listCourses()
            }
        }

        // Subject cards area
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            padding: 0

            FluStaggeredLayout {
                id: staggeredLayout
                anchors.left: parent.left
                anchors.right: parent.right
                itemWidth: 280
                rowSpacing: 16
                colSpacing: 16
                model: coursesModel
                delegate: SubjectCard {
                    subjectName: model.name
                    subjectDescription: model.description || ""
                    subjectUuid: model.uuid
                    memberCount: model.memberCount || 0
                    myRole: model.myRole || ""
                }
            }
        }

        // Empty state
        FluText {
            visible: coursesModel.count === 0
            Layout.alignment: Qt.AlignCenter
            text: "暂无学科数据，请点击「增加学科」创建"
            font.pixelSize: 13
            textColor: "#53636d"
        }

        // Units panel for selected course
        FluFrame {
            visible: currentUnits.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: 200
            radius: 12
            padding: 16

            ColumnLayout {
                anchors.fill: parent
                spacing: 10
                FluText {
                    text: "选中课程的教学单元"
                    font.pixelSize: 13
                    font.bold: true
                }
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: currentUnits
                    delegate: RowLayout {
                        width: ListView.view.width
                        height: 32
                        spacing: 8
                        FluText {
                            text: modelData.order + ". " + modelData.name
                            font.pixelSize: 11
                            Layout.fillWidth: true
                        }
                        FluText {
                            text: "满分 " + modelData.fullScore
                            font.pixelSize: 10
                            textColor: "#8ea1ad"
                            Layout.preferredWidth: 70
                        }
                        FluText {
                            text: "权重 " + (modelData.weight * 100).toFixed(0) + "%"
                            font.pixelSize: 10
                            textColor: "#0f766e"
                            Layout.preferredWidth: 70
                        }
                    }
                }
            }
        }
    }

    // Subject card component
    component SubjectCard: FluFrame {
        property string subjectName
        property string subjectDescription
        property string subjectUuid
        property int memberCount
        property string myRole

        width: 280
        height: 180
        radius: 12

        // Background click area — must be BEFORE ColumnLayout so child buttons get events first
        MouseArea {
            anchors.fill: parent
            onClicked: selectCourse({uuid: subjectUuid})
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 8

            // Title row
            RowLayout {
                Layout.fillWidth: true
                FluText {
                    text: subjectName
                    font.pixelSize: 14
                    font.bold: true
                    Layout.fillWidth: true
                }
                FluIconButton {
                    width: 28; height: 28
                    iconSource: FluentIcons.Delete
                    onClicked: {
                        pendingDeleteUuid = subjectUuid
                        pendingDeleteName = subjectName
                        deleteConfirmDialog.open()
                    }
                }
            }

            FluText {
                text: subjectDescription
                font.pixelSize: 10
                textColor: "#8ea1ad"
                visible: subjectDescription !== ""
                Layout.fillWidth: true
                elide: Text.ElideRight
                maximumLineCount: 2
            }

            FluDivider { Layout.fillWidth: true }

            RowLayout {
                FluText {
                    text: "成员 " + memberCount
                    font.pixelSize: 11
                    textColor: "#b3c0c8"
                }
                FluText {
                    text: " · 角色 " + myRole
                    font.pixelSize: 11
                    textColor: "#8ea1ad"
                }
            }
        }
    }
}
