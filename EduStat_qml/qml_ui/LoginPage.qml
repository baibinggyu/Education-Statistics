import QtQuick
import QtQuick.Layouts
import FluentUI

// 登录 Login Page
Item {
    signal login()

    Rectangle {
        anchors.fill: parent
        color: FluTheme.dark ? Qt.rgba(22/255, 25/255, 30/255, 1) : "#e8ecf0"

        ColumnLayout {
            anchors.centerIn: parent
            width: 400
            spacing: 0

            // Branding
            FluText {
                text: "EduStat"
                font.pixelSize: 36
                font.bold: true
                textColor: "#0f766e"
                Layout.alignment: Qt.AlignHCenter
            }
            FluText {
                text: "AI + 教育 · 教学统计平台"
                font.pixelSize: 13
                textColor: FluTheme.dark ? "#8ea1ad" : "#666666"
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8
            }

            // Login card
            FluFrame {
                Layout.fillWidth: true
                Layout.topMargin: 40
                radius: 16
                padding: 32

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 20

                    FluText {
                        text: "账号登录"
                        font.pixelSize: 20
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }

                    ColumnLayout {
                        spacing: 6
                        FluText {
                            text: "用户名"
                            font.pixelSize: 12
                            textColor: FluTheme.dark ? "#b3c0c8" : "#555555"
                        }
                        FluTextBox {
                            Layout.fillWidth: true
                            placeholderText: "请输入用户名"
                            Layout.preferredHeight: 42
                        }
                    }

                    ColumnLayout {
                        spacing: 6
                        FluText {
                            text: "密码"
                            font.pixelSize: 12
                            textColor: FluTheme.dark ? "#b3c0c8" : "#555555"
                        }
                        FluPasswordBox {
                            Layout.fillWidth: true
                            placeholderText: "请输入密码"
                            Layout.preferredHeight: 42
                        }
                    }

                    RowLayout {
                        FluToggleSwitch { checked: true }
                        FluText {
                            text: "记住密码"
                            font.pixelSize: 12
                        }
                        Item { Layout.fillWidth: true }
                        FluTextButton {
                            text: "忘记密码？"
                            font.pixelSize: 12
                        }
                    }

                    FluFilledButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        text: "登  录"
                        font.pixelSize: 15
                        font.bold: true
                        onClicked: login()
                    }
                }
            }

            // Footer
            FluText {
                text: "EduStat v2.0 · Qt6 + FluentUI"
                font.pixelSize: 10
                textColor: FluTheme.dark ? "#5a6570" : "#999999"
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 24
            }
        }
    }
}
