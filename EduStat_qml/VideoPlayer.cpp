#include "VideoPlayer.h"

#include <QFileInfo>
#include <QUrl>
#include <QStyle>
#include <QShortcut>
#include <QMediaDevices>
#include <QAudioDevice>
#include <QTimer>
#include <QProcess>
#include <QSpacerItem>
#include <QFrame>
#include <QApplication>

// ============================================================
// 速度倍率选项
// ============================================================
static constexpr double kSpeedValues[] = { 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0 };
static constexpr int    kSpeedCount    = sizeof(kSpeedValues) / sizeof(kSpeedValues[0]);

// ============================================================
// 辅助：毫秒 → 时间字符串  hh:mm:ss  or  mm:ss
// ============================================================
static QString msToString(qint64 ms)
{
    int secs = static_cast<int>(ms / 1000);
    int h    = secs / 3600;
    int m    = (secs % 3600) / 60;
    int s    = secs % 60;

    if (h > 0)
        return QStringLiteral("%1:%2:%3")
            .arg(h, 2, 10, QLatin1Char('0'))
            .arg(m, 2, 10, QLatin1Char('0'))
            .arg(s, 2, 10, QLatin1Char('0'));
    else
        return QStringLiteral("%1:%2")
            .arg(m, 2, 10, QLatin1Char('0'))
            .arg(s, 2, 10, QLatin1Char('0'));
}

// ============================================================
// Construction
// ============================================================
VideoPlayer::VideoPlayer(QWidget *parent)
    : QWidget(parent)
    , m_player(new QMediaPlayer(this))
    , m_audioOutput(new QAudioOutput(this))
    , m_videoWidget(nullptr)
    , m_progressSlider(nullptr)
    , m_currentTimeLabel(nullptr)
    , m_totalTimeLabel(nullptr)
    , m_playPauseBtn(nullptr)
    , m_stopBtn(nullptr)
    , m_speedCombo(nullptr)
    , m_volumeSlider(nullptr)
    , m_volumeLabel(nullptr)
    , m_statusLabel(nullptr)
    , m_isDragging(false)
    , m_controlsWidget(nullptr)
{
    setupUI();
    setupConnections();

    // 关联音频 / 视频输出
    m_player->setAudioOutput(m_audioOutput);
    m_player->setVideoOutput(m_videoWidget);

    // 显式指定默认音频设备（Qt6 某些环境需要）
    m_audioOutput->setDevice(QMediaDevices::defaultAudioOutput());
    // Qt6 FFmpeg 后端在某些 PipeWire 环境下默认静音，尝试在 Qt 层取消
    m_audioOutput->setMuted(false);

    // 默认音量 50%
    m_volumeSlider->setValue(50);
    onVolumeChanged(50);
}

VideoPlayer::~VideoPlayer()
{
    m_player->stop();
}

// ============================================================
// 公开接口
// ============================================================
void VideoPlayer::loadfile(const QString &path)
{
    m_mediaPath = path;
    QFileInfo fi(path);

    if (fi.exists()) {
        m_player->setSource(QUrl::fromLocalFile(fi.absoluteFilePath()));
    } else {
        m_player->setSource(QUrl(path));
    }

    m_statusLabel->clear();
    m_playPauseBtn->setText(QStringLiteral("▶"));
    m_progressSlider->setValue(0);
    updateTimeLabels();
    m_player->play();

    // 强制取消 PipeWire/PulseAudio 层静音（Qt6 FFmpeg 后端有时会静音）
    QTimer::singleShot(500, this, [this]() {
        QProcess::execute(
            QStringLiteral(
                "pactl set-sink-input-mute "
                "$(pactl list sink-inputs short | tail -1 | "
                "awk '{print $1}') 0 2>/dev/null || true"));
    });
}

// ============================================================
// UI 搭建
// ============================================================
void VideoPlayer::setupUI()
{
    // ----- 视频显示区域 -----
    m_videoWidget = new QVideoWidget(this);
    m_videoWidget->setStyleSheet(QStringLiteral("background: black;"));
    m_videoWidget->setMinimumSize(320, 180);
    m_videoWidget->setMouseTracking(true);
    m_videoWidget->installEventFilter(this);

    // ----- 进度条 + 时间 -----
    m_currentTimeLabel = new QLabel(QStringLiteral("00:00"));
    m_currentTimeLabel->setFixedWidth(50);
    m_currentTimeLabel->setAlignment(Qt::AlignCenter);

    m_progressSlider = new SeekSlider(Qt::Horizontal);
    m_progressSlider->setRange(0, 0);

    m_totalTimeLabel = new QLabel(QStringLiteral("00:00"));
    m_totalTimeLabel->setFixedWidth(50);
    m_totalTimeLabel->setAlignment(Qt::AlignCenter);

    QHBoxLayout *timeRow = new QHBoxLayout;
    timeRow->setContentsMargins(4, 2, 4, 2);
    timeRow->addWidget(m_currentTimeLabel);
    timeRow->addWidget(m_progressSlider, 1);
    timeRow->addWidget(m_totalTimeLabel);

    // ----- 控制按钮行 -----
    m_playPauseBtn = new QPushButton(QStringLiteral("▶"));
    m_playPauseBtn->setFixedWidth(36);
    m_playPauseBtn->setToolTip(tr("播放 / 暂停"));

    m_stopBtn = new QPushButton;
    m_stopBtn->setFixedWidth(36);
    m_stopBtn->setText(QStringLiteral("■"));
    m_stopBtn->setToolTip(tr("停止"));

    m_speedCombo = new QComboBox;
    m_speedCombo->setFixedWidth(80);
    for (int i = 0; i < kSpeedCount; ++i) {
        m_speedCombo->addItem(QStringLiteral("%1x").arg(kSpeedValues[i], 0, 'f', 2));
    }
    m_speedCombo->setCurrentIndex(3); // 1.0x
    m_speedCombo->setToolTip(tr("播放速度"));

    m_volumeLabel = new QLabel(QStringLiteral("🔊"));
    m_volumeLabel->setFixedWidth(24);

    m_volumeSlider = new QSlider(Qt::Horizontal);
    m_volumeSlider->setRange(0, 100);
    m_volumeSlider->setFixedWidth(100);
    m_volumeSlider->setToolTip(tr("音量"));

    m_fullscreenBtn = new QPushButton(QStringLiteral("⛶"));
    m_fullscreenBtn->setFixedWidth(36);
    m_fullscreenBtn->setToolTip(tr("全屏"));

    QHBoxLayout *ctrlRow = new QHBoxLayout;
    ctrlRow->setContentsMargins(4, 2, 4, 2);
    ctrlRow->addWidget(m_playPauseBtn);
    ctrlRow->addWidget(m_stopBtn);
    ctrlRow->addSpacing(8);
    ctrlRow->addWidget(m_speedCombo);
    ctrlRow->addStretch(1);
    ctrlRow->addWidget(m_volumeLabel);
    ctrlRow->addWidget(m_volumeSlider);
    ctrlRow->addWidget(m_fullscreenBtn);

    // ----- 底部控制面板 -----
    m_controlsWidget = new QWidget(this);
    m_controlsWidget->setStyleSheet(QStringLiteral(
        "QLabel { color: black; }"
        "QPushButton { background: transparent; color: black; border: none; font-size: 13px; }"
        "QPushButton:hover { color: #00a8ff; }"
        "QComboBox { background: transparent; color: black; border: none; padding: 1px 4px; font-size: 12px; }"
        "QComboBox::drop-down { border: none; }"
        "QComboBox::down-arrow { image: none; }"
        "QSlider::handle:horizontal { background: #333; width: 12px; margin: -4px 0; border-radius: 6px; }"
        "QSlider::sub-page:horizontal { background: #555; }"
        "QSlider::add-page:horizontal { background: #ddd; }"
    ));
    // 状态提示（播放视频后自动隐藏）
    m_statusLabel = new QLabel(tr("请调用 loadfile() 加载视频"));
    m_statusLabel->setAlignment(Qt::AlignCenter);
    m_statusLabel->setFixedHeight(16);
    m_statusLabel->setStyleSheet(QStringLiteral("color: #aaa; font-size: 11px;"));

    QVBoxLayout *ctrlPanelLayout = new QVBoxLayout(m_controlsWidget);
    ctrlPanelLayout->setContentsMargins(0, 0, 0, 0);
    ctrlPanelLayout->setSpacing(0);
    ctrlPanelLayout->addLayout(timeRow);
    ctrlPanelLayout->addLayout(ctrlRow);
    ctrlPanelLayout->addWidget(m_statusLabel);

    // ----- 主布局 -----
    QVBoxLayout *mainLayout = new QVBoxLayout(this);
    mainLayout->setContentsMargins(0, 0, 0, 0);
    mainLayout->setSpacing(0);
    mainLayout->addWidget(m_videoWidget, 1);
    mainLayout->addWidget(m_controlsWidget);

}

// ============================================================
// 信号连接
// ============================================================
void VideoPlayer::setupConnections()
{
    // Player → UI
    connect(m_player, &QMediaPlayer::positionChanged, this, &VideoPlayer::onPositionChanged);
    connect(m_player, &QMediaPlayer::durationChanged,  this, &VideoPlayer::onDurationChanged);
    connect(m_player, &QMediaPlayer::errorOccurred, this, &VideoPlayer::onMediaError);
    connect(m_player, &QMediaPlayer::playbackStateChanged, this, &VideoPlayer::onPlaybackStateChanged);

    // 进度条拖动
    connect(m_progressSlider, &QSlider::sliderPressed,  this, &VideoPlayer::onSliderPressed);
    connect(m_progressSlider, &QSlider::sliderMoved,    this, &VideoPlayer::onSliderMoved);
    connect(m_progressSlider, &QSlider::sliderReleased, this, &VideoPlayer::onSliderReleased);

    // 控制按钮
    connect(m_playPauseBtn, &QPushButton::clicked, this, &VideoPlayer::onPlayPause);
    connect(m_stopBtn,      &QPushButton::clicked, this, &VideoPlayer::onStop);

    // 倍速
    connect(m_speedCombo, QOverload<int>::of(&QComboBox::currentIndexChanged),
            this, &VideoPlayer::onSpeedChanged);

    // 音量
    connect(m_volumeSlider, &QSlider::valueChanged, this, &VideoPlayer::onVolumeChanged);

    // 全屏按钮
    connect(m_fullscreenBtn, &QPushButton::clicked, this, &VideoPlayer::onFullscreen);

    // ---- 快捷键 ----
    auto *spaceKey = new QShortcut(QKeySequence(Qt::Key_Space), this);
    connect(spaceKey, &QShortcut::activated, this, &VideoPlayer::onPlayPause);

    auto *leftKey  = new QShortcut(QKeySequence(Qt::Key_Left), this);
    connect(leftKey, &QShortcut::activated, this, &VideoPlayer::onSeekBackward);

    auto *rightKey = new QShortcut(QKeySequence(Qt::Key_Right), this);
    connect(rightKey, &QShortcut::activated, this, &VideoPlayer::onSeekForward);

    auto *upKey   = new QShortcut(QKeySequence(Qt::Key_Up), this);
    connect(upKey, &QShortcut::activated, this, &VideoPlayer::onVolumeUp);

    auto *downKey = new QShortcut(QKeySequence(Qt::Key_Down), this);
    connect(downKey, &QShortcut::activated, this, &VideoPlayer::onVolumeDown);

    auto *fKey = new QShortcut(QKeySequence(Qt::Key_F), this);
    connect(fKey, &QShortcut::activated, this, &VideoPlayer::onFullscreen);

    auto *escKey = new QShortcut(QKeySequence(Qt::Key_Escape), this);
    connect(escKey, &QShortcut::activated, this, [this]() {
        auto *w = window();
        if (w->isFullScreen())
            w->showNormal();
    });
}

// ============================================================
// 事件过滤器 — 双击视频切换全屏
// ============================================================
bool VideoPlayer::eventFilter(QObject *obj, QEvent *event)
{
    if (event->type() == QEvent::MouseButtonDblClick && obj == m_videoWidget) {
        onFullscreen();
        return true;
    }
    return QWidget::eventFilter(obj, event);
}

// ============================================================
// 播放控制槽
// ============================================================
void VideoPlayer::onPlayPause()
{
    switch (m_player->playbackState()) {
    case QMediaPlayer::PlayingState:
        m_player->pause();
        break;
    case QMediaPlayer::PausedState:
    case QMediaPlayer::StoppedState:
    default:
        m_player->play();
        break;
    }
}

void VideoPlayer::onStop()
{
    m_player->stop();
    m_progressSlider->setValue(0);
    updateTimeLabels();
}

void VideoPlayer::onFullscreen()
{
    auto *w = window();

    qint64 pos         = m_player->position();
    bool   wasPlaying  = (m_player->playbackState() == QMediaPlayer::PlayingState);

    // 停止播放，断开视频输出，释放 GPU surface
    m_player->stop();
    m_player->setVideoOutput(nullptr);
    QApplication::processEvents(QEventLoop::ExcludeUserInputEvents);

    // 切换窗口模式
    if (!w->isFullScreen())
        w->showFullScreen();
    else
        w->showNormal();

    QApplication::processEvents(QEventLoop::ExcludeUserInputEvents);

    // 重新绑定视频输出（source 不变，可直接 seek）
    m_player->setVideoOutput(m_videoWidget);
    m_player->setPosition(pos);
    if (wasPlaying)
        m_player->play();
}

// ============================================================
// 进度相关
// ============================================================
void VideoPlayer::onPositionChanged(qint64 position)
{
    if (!m_isDragging) {
        m_progressSlider->setValue(static_cast<int>(position));
    }
    updateTimeLabels();
    emit positionChanged(position);
}

void VideoPlayer::onDurationChanged(qint64 duration)
{
    m_progressSlider->setRange(0, static_cast<int>(duration));
    updateTimeLabels();
    emit durationChanged(duration);
}

void VideoPlayer::onSliderMoved(qint64 position)
{
    m_currentTimeLabel->setText(msToString(position));
}

void VideoPlayer::onSliderPressed()
{
    m_isDragging = true;
}

void VideoPlayer::onSliderReleased()
{
    m_isDragging = false;
    m_player->setPosition(m_progressSlider->value());
}

void VideoPlayer::onSeekForward()
{
    m_player->setPosition(m_player->position() + 10000);
}

void VideoPlayer::onSeekBackward()
{
    m_player->setPosition(qMax(qint64(0), m_player->position() - 10000));
}

// ============================================================
// 倍速
// ============================================================
void VideoPlayer::onSpeedChanged(int index)
{
    if (index >= 0 && index < kSpeedCount) {
        m_player->setPlaybackRate(kSpeedValues[index]);
    }
}

// ============================================================
// 音量
// ============================================================
void VideoPlayer::onVolumeChanged(int value)
{
    m_audioOutput->setVolume(value / 100.0);
    bool hasVolume = value > 0;
    m_audioOutput->setMuted(!hasVolume);
    m_volumeLabel->setText(hasVolume ? QStringLiteral("🔊") : QStringLiteral("🔇"));
}

void VideoPlayer::onVolumeUp()
{
    int v = qMin(100, m_volumeSlider->value() + 5);
    m_volumeSlider->setValue(v);
}

void VideoPlayer::onVolumeDown()
{
    int v = qMax(0, m_volumeSlider->value() - 5);
    m_volumeSlider->setValue(v);
}

// ============================================================
// 错误处理
// ============================================================
void VideoPlayer::onMediaError(QMediaPlayer::Error error, const QString &errorString)
{
    if (error == QMediaPlayer::NoError) {
        m_statusLabel->clear();
        return;
    }

    QString msg;
    switch (error) {
    case QMediaPlayer::ResourceError:
        msg = tr("无法解析或找不到视频文件");
        break;
    case QMediaPlayer::FormatError:
        msg = tr("视频格式不支持");
        break;
    case QMediaPlayer::NetworkError:
        msg = tr("网络错误，请检查链接");
        break;
    case QMediaPlayer::AccessDeniedError:
        msg = tr("无权限访问该文件");
        break;
    default:
        msg = tr("未知错误");
        break;
    }

    m_statusLabel->setText(QStringLiteral("⚠ ") + msg);
    emit errorOccurred(msg);
}

void VideoPlayer::onPlaybackStateChanged(QMediaPlayer::PlaybackState state)
{
    switch (state) {
    case QMediaPlayer::PlayingState:
        m_playPauseBtn->setText(QStringLiteral("⏸"));
        m_statusLabel->setVisible(false);
        break;
    case QMediaPlayer::PausedState:
        m_playPauseBtn->setText(QStringLiteral("▶"));
        break;
    case QMediaPlayer::StoppedState:
        m_playPauseBtn->setText(QStringLiteral("▶"));
        m_statusLabel->setVisible(true);
        m_statusLabel->setText(tr("已停止"));
        break;
    }
    emit stateChanged(state);
}

// ============================================================
// 辅助
// ============================================================
void VideoPlayer::updateTimeLabels()
{
    qint64 pos  = m_player->position();
    qint64 dur  = m_player->duration();

    m_currentTimeLabel->setText(msToString(pos));
    if (dur > 0)
        m_totalTimeLabel->setText(msToString(dur));
    else
        m_totalTimeLabel->setText(QStringLiteral("--:--"));
}
