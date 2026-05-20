#pragma once

#include <QObject>
#include <QString>

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
    void newConversation();
    void loadConversation(const QString& id);
    void deleteConversation(const QString& id);
    void refreshSessions();
    void restoreLastConversation();

signals:
    void messageReceived(const QString& role, const QString& content);
    void errorOccurred(const QString& message);
    void chatStateChanged();
    void compressed(const QString& summary);
    void conversationReset();
    void sessionListReset();
    void sessionListed(const QString& id, const QString& title,
                       const QString& preview, const QString& updatedAt,
                       bool active);
    void sessionSelected(const QString& id);
    /// 加载会话时恢复历史记录，QML 侧据此重建 msgModel
    void historyLoaded(const QString& role, const QString& content);

private:
    struct ChatSession {
        QString id;
        QString title;
        QString updatedAt;
        std::vector<Message> messages;
    };

    ChatClient client_;
    std::vector<ChatSession> sessions_;
    std::vector<Message> history_;
    QString current_session_id_;
    QString model_name_;
    bool loading_ = false;
    int compress_turns_ = 10;
    QString savePath_;

    void setLoading(bool v);
    void saveStore();
    void loadStore();
    void ensureCurrentSession(const QString& firstMessage);
    void updateCurrentSession();
    ChatSession* currentSession();
    ChatSession* findSession(const QString& id);
    QString makeTitle(const QString& text) const;
    void emitCurrentHistory();
};
