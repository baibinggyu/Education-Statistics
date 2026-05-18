#include <QApplication>
#include <QMediaPlayer>
#include <QAudioOutput>
#include <QMediaDevices>
#include <QTimer>
#include <QUrl>
#include <cstdio>

int main(int argc, char *argv[]) {
    QApplication app(argc, argv);

    QMediaPlayer player;
    QAudioOutput ao;
    player.setAudioOutput(&ao);
    ao.setDevice(QMediaDevices::defaultAudioOutput());
    ao.setVolume(1.0);
    ao.setMuted(false);

    fprintf(stderr, "isMuted=%d volume=%f\n", (int)ao.isMuted(), ao.volume());

    player.setSource(QUrl::fromLocalFile(QString::fromUtf8(argv[1])));
    QTimer::singleShot(500, [&]() { player.play(); });
    QTimer::singleShot(3000, [&]() { app.quit(); });
    return app.exec();
}
