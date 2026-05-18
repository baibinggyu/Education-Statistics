#include <QApplication>
#include <QQmlApplicationEngine>

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    app.setApplicationName("EduStat 2.0 教学统计系统");
    app.setOrganizationName("Edu");

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
