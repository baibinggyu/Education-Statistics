import QtQuick
import QtQuick.Layouts
import FluentUI
import EduStat.Backend 1.0

// 登录 Login Page
Item {
    id: loginPage
    signal login()

    // Supplied by main.qml singleton
    required property ApiClient requiredApiClient

    property string errorMessage: ""

    Connections {
        target: requiredApiClient

        function onLoginSuccess(token, role) {
            loginPage.errorMessage = ""
            loginPage.login()
        }

        function onLoginError(msg) {
            loginPage.errorMessage = msg
        }
    }

    Component.onCompleted: {
        if (requiredApiClient.hasSavedCredentials()) {
            var saved = requiredApiClient.getSavedUsername()
            if (saved) {
                usernameField.text = saved
                rememberMeSwitch.checked = true
            }
        }
    }

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
                            id: usernameField
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
                            id: passwordField
                            Layout.fillWidth: true
                            placeholderText: "请输入密码"
                            Layout.preferredHeight: 42
                        }
                    }

                    // Remember me toggle
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        FluToggleSwitch {
                            id: rememberMeSwitch
                        }
                        FluText {
                            text: "记住密码，自动登录"
                            font.pixelSize: 12
                            textColor: FluTheme.dark ? "#8ea1ad" : "#666666"
                        }
                    }

                    FluText {
                        text: loginPage.errorMessage
                        visible: loginPage.errorMessage !== ""
                        color: "#ef4444"
                        font.pixelSize: 12
                        Layout.fillWidth: true
                    }

                    FluFilledButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        text: "登  录"
                        font.pixelSize: 15
                        font.bold: true
                        onClicked: {
                            loginPage.errorMessage = ""
                            requiredApiClient.setRememberMe(rememberMeSwitch.checked)
                            requiredApiClient.login(usernameField.text, passwordField.text)
                        }
                    }
                }
            }

            // Footer
            FluText {
                text: "EduStat v2.0"
                font.pixelSize: 10
                textColor: FluTheme.dark ? "#5a6570" : "#999999"
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 24
            }
        }
    }
}
