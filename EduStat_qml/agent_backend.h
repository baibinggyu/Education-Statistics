#pragma once

#include <QObject>
#include <QString>

#include <ai/ai.h>

class ApiClient;  // forward

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

    // One-shot analysis (no conversation, no agent)
    void oneShotChat(const QString& prompt);

    // Mode
    void setAgentMode(bool enabled);

    // ApiClient integration
    void setApiClient(ApiClient* client);

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

    // One-shot analysis result
    void oneShotChatFinished(const QString& content);
    void oneShotChatError(const QString& message);

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
    void tryInitServerProxy();

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

    // Admin API sync wrappers (worker thread → main thread bridge via QEventLoop)
    nlohmann::json listCoursesSync();
    nlohmann::json createCourseSync(const std::string& name, const std::string& desc);
    nlohmann::json deleteCourseSync(const std::string& uuid);
    nlohmann::json listCourseMembersSync(const std::string& courseUuid);
    nlohmann::json addCourseMemberSync(const std::string& courseUuid, const std::string& username);
    nlohmann::json removeCourseMemberSync(const std::string& courseUuid, const std::string& userUuid);
    nlohmann::json registerUserSync(const std::string& username, const std::string& password,
                                     const std::string& role,
                                     const std::string& studentNo = "",
                                     const std::string& realName = "");
    nlohmann::json getCourseDetailSync(const std::string& courseUuid);
    nlohmann::json generateRandomScoresSync(const std::string& courseUuid);
    nlohmann::json exportScoresSync(const std::string& courseUuid, const std::string& format);
    nlohmann::json upsertScoreSync(const std::string& courseUuid, const std::string& studentUuid,
                                   int unitId, double score);
    nlohmann::json listUnitsSync(const std::string& courseUuid);
    nlohmann::json createUnitSync(const std::string& courseUuid, const std::string& name,
                                  double weight, double fullScore, int unitOrder);
    nlohmann::json updateUnitSync(const std::string& courseUuid, int unitId,
                                  const std::string& name, double weight, double fullScore, int unitOrder);
    nlohmann::json deleteUnitSync(const std::string& courseUuid, int unitId);
    nlohmann::json batchUpsertScoresSync(const std::string& courseUuid, int unitId,
                                         const std::vector<std::pair<std::string, double>>& scores);
    nlohmann::json scoreSummarySync(const std::string& courseUuid);
    nlohmann::json scoreDistributionSync(const std::string& courseUuid);
    nlohmann::json listVideosSync(const std::string& courseUuid);
    nlohmann::json fetchAnnouncementsSync(const std::string& courseUuid);
    nlohmann::json publishAnnouncementSync(const std::string& courseUuid, const std::string& title,
                                           const std::string& content, const std::string& annType,
                                           bool pinned, bool notify);
    nlohmann::json deleteAnnouncementSync(const std::string& courseUuid, const std::string& announcementUuid);
    nlohmann::json fetchMessagesSync(const std::string& courseUuid);
    nlohmann::json sendMessageSync(const std::string& courseUuid, const std::string& content,
                                   const std::string& msgType, const std::string& subject,
                                   const std::string& recipientUsername);
    nlohmann::json deleteMessageSync(const std::string& courseUuid, const std::string& messageUuid);
    nlohmann::json markMessageReadSync(const std::string& courseUuid, const std::string& messageUuid);
    nlohmann::json fetchConversationSync(const std::string& courseUuid, const std::string& otherUserUuid);

    // Attendance sync wrappers
    nlohmann::json listAttendancesSync(const std::string& courseUuid);
    nlohmann::json startAttendanceSync(const std::string& courseUuid, const std::string& title);
    nlohmann::json getAttendanceDetailSync(const std::string& courseUuid, const std::string& attendanceUuid);
    nlohmann::json markAttendanceSync(const std::string& courseUuid, const std::string& attendanceUuid,
                                       const std::string& studentUuid, const std::string& status,
                                       const std::string& note);
    nlohmann::json batchMarkAttendanceSync(const std::string& courseUuid, const std::string& attendanceUuid,
                                            const std::vector<std::pair<std::string, std::string>>& marks);
    nlohmann::json closeAttendanceSync(const std::string& courseUuid, const std::string& attendanceUuid);
    nlohmann::json deleteAttendanceSync(const std::string& courseUuid, const std::string& attendanceUuid);

    // Batch import
    nlohmann::json importStudentsSync(const std::string& courseUuid,
                                       const std::vector<std::tuple<std::string, std::string, std::string, std::string>>& students);

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

    // ApiClient (owned by QML, accessed via QPointer for safety)
    ApiClient* apiClient_ = nullptr;
};
