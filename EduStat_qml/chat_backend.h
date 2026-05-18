#pragma once

#include <QObject>

#include "../chat/chat_client.hpp"

class ChatBackend : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool loading READ loading NOTIFY chatStateChanged)
    Q_PROPERTY(int messageCount READ messageCount NOTIFY chatStateChanged)
    Q_PROPERTY(QString modelName READ modelName CONSTANT)

public:
    explicit ChatBackend(QObject* parent = nullptr);

    bool loading() const { return loading_; }
    int  messageCount() const { return static_cast<int>(history_.size()); }
    QString modelName() const { return model_name_; }

public slots:
    void sendMessage(const QString& text);
    void clearHistory();
    void compressHistory();
    void setCompressTurns(int turns);

signals:
    void messageReceived(const QString& role, const QString& content);
    void errorOccurred(const QString& message);
    void chatStateChanged();
    void compressed();

private:
    ChatClient client_;
    std::vector<Message> history_;
    QString model_name_;
    bool loading_ = false;
    int compress_turns_ = 10;

    void setLoading(bool v);
};
