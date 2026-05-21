#pragma once

#include <QObject>
#include <QString>

#include <ai/ai.h>

class AgentBackend : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool loading READ loading NOTIFY chatStateChanged)
    Q_PROPERTY(bool streaming READ streaming NOTIFY chatStateChanged)
    Q_PROPERTY(bool agentMode READ agentMode NOTIFY chatStateChanged)
    Q_PROPERTY(QString modelName READ modelName CONSTANT)
public:
    explicit AgentBackend(QObject* parent = nullptr);

    bool loading() const { return loading_; }
    bool streaming() const { return streaming_; }
    bool agentMode() const { return agent_mode_; }
    QString modelName() const { return model_name_; }

public slots:
    // Core messaging
    void sendMessage(const QString& text);
    void stopGeneration();

    // Mode
    void setAgentMode(bool enabled);

    // Session management
    void newConversation();
    void clearHistory();
    void loadConversation(const QString& id);
    void deleteConversation(const QString& id);
    void refreshSessions();
    void restoreLastConversation();

signals:
    // Streaming
    void streamChunk(const QString& chunk);
    void streamFinished();

    // Messages
    void messageReceived(const QString& role, const QString& content);
    void errorOccurred(const QString& message);
    void chatStateChanged();

    // Agent progress
    void stepUpdated(const QString& description, const QString& status,
                     bool success, const QString& resultJson);

    // Session list
    void sessionListReset();
    void sessionListed(const QString& id, const QString& title,
                       const QString& preview, const QString& updatedAt,
                       bool active);
    void sessionSelected(const QString& id);
    void conversationReset();
    void historyLoaded(const QString& role, const QString& content);

private:
    struct ChatSession {
        QString id;
        QString title;
        QString updatedAt;
        // Store messages as role+text for JSON persistence
        struct StoredMessage {
            QString role;
            QString content;
        };
        std::vector<StoredMessage> messages;
    };

    // LLM initialization
    void initLLM();

    // Worker thread runners
    void runStreamingChat(const QString& userText);
    void runAgent(const QString& userText);

    // Session helpers
    ChatSession* currentSession();
    ChatSession* findSession(const QString& id);
    QString makeTitle(const QString& text) const;
    void ensureCurrentSession(const QString& firstMessage);
    void updateCurrentSession();
    void saveStore();
    void loadStore();
    void emitCurrentHistory();

    // Convert between stored messages and ai::Message
    std::vector<ai::Message> storedToAi(const std::vector<ChatSession::StoredMessage>& stored) const;
    std::vector<ChatSession::StoredMessage> aiToStored(const std::vector<ai::Message>& aiMsgs) const;

    // SDK objects
    ai::Client client_;

    // State
    std::vector<ChatSession> sessions_;
    std::vector<ChatSession::StoredMessage> history_;  // current conversation history
    QString current_session_id_;
    QString model_name_;
    bool loading_ = false;
    bool streaming_ = false;
    bool agent_mode_ = false;
    std::atomic<bool> should_stop_{false};

    // Session persistence
    QString savePath_;
};
