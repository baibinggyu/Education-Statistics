#include "VideoPlayer.h"
#include <QApplication>
#include <QFileDialog>
#include <QUrl>

int main(int argc, char *argv[]) {
  QApplication app(argc, argv);

  VideoPlayer player;
  player.setWindowTitle(QStringLiteral("VideoPlayer Demo"));
  player.resize(800, 520);
  player.show();

  // 支持命令行传参直接播放
  if (argc > 1) {
    player.loadfile(argv[1]);
  }

  return app.exec();
}
