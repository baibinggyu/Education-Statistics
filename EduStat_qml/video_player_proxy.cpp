#include "video_player_proxy.h"
#include "VideoPlayer.h"

void VideoPlayerProxy::open(const QString& path) {
    auto* player = new VideoPlayer();
    player->setAttribute(Qt::WA_DeleteOnClose);
    player->setWindowTitle(QStringLiteral("EduStat - 视频播放"));
    player->resize(960, 540);
    player->loadfile(path);
    player->show();
}
