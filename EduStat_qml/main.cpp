#include <QApplication>
#include <QByteArray>
#include <QQmlApplicationEngine>
#include <QString>

#include <cstdlib>

#include "chat_backend.h"

static void configureInputMethod()
{
    if (qEnvironmentVariableIsSet("QT_IM_MODULE"))
        return;

    const QString modifiers = QString::fromLocal8Bit(qgetenv("XMODIFIERS")).toLower();
    if (modifiers.contains("fcitx")) {
        qputenv("QT_IM_MODULE", QByteArray("fcitx"));
    } else if (modifiers.contains("ibus")) {
        qputenv("QT_IM_MODULE", QByteArray("ibus"));
    } else if (qEnvironmentVariableIsSet("GTK_IM_MODULE")) {
        qputenv("QT_IM_MODULE", qgetenv("GTK_IM_MODULE"));
    }
}

int main(int argc, char *argv[])
{
    // 中文输入法: 保留用户环境；缺失时按桌面会话推断 fcitx/ibus。
    configureInputMethod();

    QApplication app(argc, argv);
    app.setApplicationName("EduStat 2.0 教学统计系统");
    app.setOrganizationName("Edu");

    qmlRegisterType<ChatBackend>("EduStat.Backend", 1, 0, "ChatBackend");

    QQmlApplicationEngine engine;
    engine.addImportPath(QCoreApplication::applicationDirPath());

    const QUrl url(QStringLiteral("qrc:/qt/qml/EduStat/qml_ui/main.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
        &app, []() { QCoreApplication::exit(-1); }, Qt::QueuedConnection);

    engine.load(url);

    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
