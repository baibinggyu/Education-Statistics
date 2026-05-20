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
                setLoading(false);
                ChatResponse resp;
                try {
                    resp = watcher->result();
                } catch (const std::exception& e) {
                    history_.pop_back();
                    emit errorOccurred(QString::fromStdString(
                        std::string("网络异常: ") + e.what()));
                    emit chatStateChanged();
                    watcher->deleteLater();
                    return;
                } catch (...) {
                    history_.pop_back();
                    emit errorOccurred("未知异常");
                    emit chatStateChanged();
                    watcher->deleteLater();
                    return;
                }

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
    auto future = QtConcurrent::run([this, msgs]() -> ChatResponse {
        try {
            return client_.chat(msgs);
        } catch (const std::exception& e) {
            ChatResponse resp;
            resp.ok = false;
            resp.error = std::string("网络异常: ") + e.what();
            return resp;
        }
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
                ChatResponse resp;
                try {
                    resp = watcher->result();
                } catch (const std::exception& e) {
                    emit errorOccurred(QString::fromStdString(
                        std::string("压缩异常: ") + e.what()));
                    emit chatStateChanged();
                    watcher->deleteLater();
                    return;
                } catch (...) {
                    emit errorOccurred("压缩过程未知异常");
                    emit chatStateChanged();
                    watcher->deleteLater();
                    return;
                }

                if (resp.ok) {
                    emit compressed();
                } else {
                    emit errorOccurred(QString::fromStdString(resp.error));
                }
                emit chatStateChanged();
                watcher->deleteLater();
            });

    auto future = QtConcurrent::run([this, cc]() mutable -> ChatResponse {
        try {
            return client_.compress(history_, cc);
        } catch (const std::exception& e) {
            ChatResponse resp;
            resp.ok = false;
            resp.error = std::string("网络异常: ") + e.what();
            return resp;
        }
    });
    watcher->setFuture(future);
}

void ChatBackend::setCompressTurns(int turns) {
    compress_turns_ = turns;
}
