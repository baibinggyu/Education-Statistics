#ifndef VIDEOPLAYER_H
#define VIDEOPLAYER_H

#include <QWidget>
#include <QMediaPlayer>
#include <QAudioOutput>
#include <QVideoWidget>
#include <QProcess>
#include <QSlider>
#include <QLabel>
#include <QPushButton>
#include <QComboBox>
#include <QHBoxLayout>
#include <QVBoxLayout>
#include <QTime>
#include <QMouseEvent>
#include <QStyle>

// ============================================================
// 支持点击轨道跳转的进度条
// ============================================================
class SeekSlider : public QSlider
{
    Q_OBJECT
public:
    using QSlider::QSlider;

protected:
    void mousePressEvent(QMouseEvent *event) override
    {
        if (event->button() == Qt::LeftButton) {
            int value = QStyle::sliderValueFromPosition(
                minimum(), maximum(), event->pos().x(), width());
            setValue(value);
            emit sliderMoved(value);
            emit sliderReleased();
            event->accept();
            return;
        }
        QSlider::mousePressEvent(event);
    }
};

class VideoPlayer : public QWidget
{
    Q_OBJECT

public:
    explicit VideoPlayer(QWidget *parent = nullptr);
    ~VideoPlayer() override;

    /// 加载视频文件，支持本地路径和网络 URL
    void loadfile(const QString &path);

signals:
    void positionChanged(qint64 position);
    void durationChanged(qint64 duration);
    void stateChanged(QMediaPlayer::PlaybackState state);
    void errorOccurred(const QString &message);

protected:
    bool eventFilter(QObject *obj, QEvent *event) override;

private slots:
    void onPlayPause();
    void onStop();
    void onPositionChanged(qint64 position);
    void onDurationChanged(qint64 duration);
    void onSliderMoved(qint64 position);
    void onSliderPressed();
    void onSliderReleased();
    void onSpeedChanged(int index);
    void onVolumeChanged(int value);
    void onMediaError(QMediaPlayer::Error error, const QString &errorString);
    void onPlaybackStateChanged(QMediaPlayer::PlaybackState state);
    void onFullscreen();
    void onSeekForward();
    void onSeekBackward();
    void onVolumeUp();
    void onVolumeDown();

private:
    void setupUI();
    void setupConnections();
    void updateTimeLabels();

    QMediaPlayer  *m_player;
    QAudioOutput  *m_audioOutput;
    QVideoWidget  *m_videoWidget;

    // Control widgets
    SeekSlider   *m_progressSlider;
    QLabel        *m_currentTimeLabel;
    QLabel        *m_totalTimeLabel;
    QPushButton   *m_playPauseBtn;
    QPushButton   *m_stopBtn;
    QComboBox     *m_speedCombo;
    QSlider       *m_volumeSlider;
    QPushButton   *m_fullscreenBtn;
    QLabel        *m_volumeLabel;
    QLabel        *m_statusLabel;

    bool           m_isDragging;
    QString        m_mediaPath;

    QWidget       *m_controlsWidget;
};

#endif // VIDEOPLAYER_H
