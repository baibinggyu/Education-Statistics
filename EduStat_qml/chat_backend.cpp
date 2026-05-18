#include "chat_backend.h"

#include <QFutureWatcher>
#include <QtConcurrent/QtConcurrentRun>

ChatBackend::ChatBackend(QObject* parent)
    : QObject(parent)
    , client_(Config::from_env())
    , model_name_(QString::fromStdString(client_.model()))
{
    client_.setTimeout(Config::from_env().timeout_ms);
}

void ChatBackend::setLoading(bool v) {
    if (loading_ != v) {
        loading_ = v;
        emit chatStateChanged();
    }
}

void ChatBackend::sendMessage(const QString& text) {
    if (text.trimmed().isEmpty() || loading_) return;

    setLoading(true);
    history_.push_back({"user", text.toStdString()});
    emit chatStateChanged();

    auto* watcher = new QFutureWatcher<ChatResponse>(this);
    connect(watcher, &QFutureWatcher<ChatResponse>::finished, this,
            [this, watcher]() {
                ChatResponse resp = watcher->result();
                setLoading(false);

                if (resp.ok) {
                    history_.push_back({"assistant", resp.content});
                    emit messageReceived("assistant",
                        QString::fromStdString(resp.content));
                } else {
                    history_.pop_back();
                    emit errorOccurred(QString::fromStdString(resp.error));
                }
                emit chatStateChanged();
                watcher->deleteLater();
            });

    auto msgs = history_;
    auto future = QtConcurrent::run([this, msgs]() {
        return client_.chat(msgs);
    });
    watcher->setFuture(future);
}

void ChatBackend::clearHistory() {
    history_.clear();
    emit chatStateChanged();
}

void ChatBackend::compressHistory() {
    CompressConfig cc;
    cc.max_turns = compress_turns_;

    auto* watcher = new QFutureWatcher<ChatResponse>(this);
    connect(watcher, &QFutureWatcher<ChatResponse>::finished, this,
            [this, watcher]() {
                ChatResponse resp = watcher->result();
                if (resp.ok) {
                    emit compressed();
                } else {
                    emit errorOccurred(QString::fromStdString(resp.error));
                }
                emit chatStateChanged();
                watcher->deleteLater();
            });

    auto future = QtConcurrent::run([this, cc]() mutable {
        return client_.compress(history_, cc);
    });
    watcher->setFuture(future);
}

void ChatBackend::setCompressTurns(int turns) {
    compress_turns_ = turns;
}
