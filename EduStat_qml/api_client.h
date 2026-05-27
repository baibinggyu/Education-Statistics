#pragma once

#include <QNetworkRequest>
#include <QObject>
#include <QString>
#include <QVariantMap>

class QNetworkAccessManager;
class QNetworkReply;

class ApiClient : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString serverUrl READ serverUrl WRITE setServerUrl NOTIFY serverUrlChanged)
    Q_PROPERTY(QString token READ token NOTIFY authenticatedChanged)
    Q_PROPERTY(QString userUuid READ userUuid NOTIFY authenticatedChanged)
    Q_PROPERTY(QString role READ role NOTIFY authenticatedChanged)
    Q_PROPERTY(QString username READ username NOTIFY usernameChanged)
    Q_PROPERTY(bool authenticated READ isAuthenticated NOTIFY authenticatedChanged)
public:
    explicit ApiClient(QObject* parent = nullptr);

    Q_INVOKABLE QString serverUrl() const { return server_url_; }
    Q_INVOKABLE bool isAuthenticated() const { return !token_.isEmpty(); }
    Q_INVOKABLE QString token() const { return token_; }
    Q_INVOKABLE QString userUuid() const { return user_uuid_; }
    Q_INVOKABLE QString role() const { return role_; }
    Q_INVOKABLE QString username() const { return username_; }

public slots:
    // --- Auth ---
    void login(const QString& username, const QString& password);
    void registerUser(const QString& username, const QString& password, const QString& role,
                       const QString& studentNo = "", const QString& realName = "");
    void fetchCurrentUser();
    void logout();

    // --- Courses ---
    void listCourses();
    void createCourse(const QString& name, const QString& description);
    void fetchCourseDetail(const QString& courseUuid);
    void updateCourse(const QString& courseUuid, const QString& name, const QString& description);
    void deleteCourse(const QString& courseUuid);

    // --- Course Members ---
    void fetchCourseMembers(const QString& courseUuid);
    void addCourseMember(const QString& courseUuid, const QString& username);
    void removeCourseMember(const QString& courseUuid, const QString& userUuid);

    // --- Units ---
    void fetchUnits(const QString& courseUuid);
    void createUnit(const QString& courseUuid, const QString& name,
                    double weight, double fullScore, int unitOrder);
    void updateUnit(const QString& courseUuid, int unitId,
                    const QString& name, double weight, double fullScore, int unitOrder);
    void deleteUnit(const QString& courseUuid, int unitId);
    void reorderUnits(const QString& courseUuid, const QVariantList& orders);

    // --- Scores ---
    void fetchMyScores(const QString& courseUuid);
    void fetchScoreSummary(const QString& courseUuid);
    void fetchScoreDistribution(const QString& courseUuid);
    void upsertScore(const QString& courseUuid, const QString& studentUuid,
                     int unitId, double score);
    void batchUpsertScores(const QString& courseUuid, int unitId,
                           const QVariantList& scores);
    void generateRandomScores(const QString& courseUuid);

    // --- Videos ---
    void fetchCourseVideos(const QString& courseUuid);
    void fetchVideoDetail(const QString& videoUuid);
    void updateVideo(const QString& videoUuid, const QString& title,
                     const QString& description, const QString& status);
    void deleteVideo(const QString& videoUuid);

    // --- Play Records ---
    void updatePlayRecord(const QString& videoUuid, int progress, bool completed);
    void fetchPlayRecord(const QString& videoUuid);
    void fetchMyPlayRecords(const QString& courseUuid);

    // --- Users ---
    void updateProfile(const QString& username);
    void bindStudent(const QString& studentNo, const QString& realName);

    // --- AI ---
    void chatWithAI(const QVariantList& messages);

    // --- Announcements ---
    void fetchAnnouncements(const QString& courseUuid);
    void publishAnnouncement(const QString& courseUuid, const QString& title,
                             const QString& content, const QString& annType,
                             bool pinned, bool notify);
    void deleteAnnouncement(const QString& courseUuid, const QString& announcementUuid);

    // --- Messages ---
    void fetchMessages(const QString& courseUuid);
    void sendMessage(const QString& courseUuid, const QString& content,
                     const QString& msgType, const QString& subject,
                     const QString& recipientUsername);
    void markMessageRead(const QString& courseUuid, const QString& messageUuid);
    void deleteMessage(const QString& courseUuid, const QString& messageUuid);
    void fetchUnreadCount(const QString& courseUuid);
    void fetchConversation(const QString& courseUuid, const QString& otherUserUuid);

    // --- Attendance ---
    void fetchAttendances(const QString& courseUuid);
    void startAttendance(const QString& courseUuid, const QString& title, const QString& mode = "simple");
    void fetchAttendanceDetail(const QString& courseUuid, const QString& attendanceUuid);
    void markAttendance(const QString& courseUuid, const QString& attendanceUuid,
                        const QString& studentUuid, const QString& status,
                        const QString& note);
    void batchMarkAttendance(const QString& courseUuid, const QString& attendanceUuid,
                             const QJsonArray& marks);
    void closeAttendance(const QString& courseUuid, const QString& attendanceUuid);
    void deleteAttendance(const QString& courseUuid, const QString& attendanceUuid);

    // --- Batch Import ---
    void importStudents(const QString& courseUuid, const QJsonArray& students);

    // --- File Upload ---
    void uploadVideoFile(const QString& courseUuid, const QString& title,
                         const QString& filePath, bool addSubtitle = false);

    // --- Assignments ---
    void fetchAssignments(const QString& courseUuid);
    void publishAssignment(const QString& courseUuid, const QString& title,
                           const QString& description, const QString& dueDate,
                           double totalPoints);
    void deleteAssignment(const QString& courseUuid, const QString& assignmentUuid);
    void fetchSubmissions(const QString& courseUuid, const QString& assignmentUuid);
    void gradeSubmission(const QString& courseUuid, const QString& assignmentUuid,
                         const QString& submissionUuid, double score,
                         const QString& feedback);
    void submitAssignmentFile(const QString& courseUuid, const QString& assignmentUuid,
                              const QString& filePath, const QString& content);

    // --- Credential Persistence ---
    Q_INVOKABLE void setRememberMe(bool remember);
    Q_INVOKABLE bool hasSavedCredentials() const;
    Q_INVOKABLE QString getSavedUsername() const;
    Q_INVOKABLE void saveCredentials(const QString& username, const QString& password);
    Q_INVOKABLE void clearSavedCredentials();
    Q_INVOKABLE void tryAutoLogin();

    // --- Utilities ---
    Q_INVOKABLE bool saveTextFile(const QString& filePath, const QString& content);
    Q_INVOKABLE QString homeDir() const;
    Q_INVOKABLE bool exportScoresToExcel(const QString& filePath,
                                          const QStringList& unitNames,
                                          const QVariantList& students);

    // --- Config ---
    void setServerUrl(const QString& url);

signals:
    // Auth
    void loginSuccess(const QString& token, const QString& role);
    void loginError(const QString& message);
    void registerSuccess(const QString& uuid);
    void registerError(const QString& message);
    void userFetched(const QString& uuid, const QString& username, const QString& role);
    void tokenExpired();

    // Courses
    void courseListReset();
    void courseListed(const QString& uuid, const QString& name,
                      const QString& description, const QString& status,
                      int memberCount, const QString& myRole);
    void coursesListDone();
    void courseCreated(const QString& uuid, const QString& name);
    void courseCreateError(const QString& message);
    void courseDetailFetched(const QVariantMap& detail);
    void courseDetailError(const QString& message);
    void courseUpdated(const QString& uuid);
    void courseUpdateError(const QString& message);
    void courseDeleted(const QString& uuid);
    void courseDeleteError(const QString& message);

    // Course Members
    void courseMembersReset();
    void courseMemberListed(const QString& userUuid, const QString& username,
                            const QString& memberRole, const QString& joinedAt,
                            const QString& studentNo, const QString& realName);
    void courseMembersListDone();
    void courseMembersError(const QString& message);
    void memberAdded(const QString& userUuid, const QString& username);
    void memberAddError(const QString& message);
    void memberRemoved(const QString& userUuid);
    void memberRemoveError(const QString& message);

    // Units
    void unitListReset();
    void unitListed(int id, const QString& name, double weight,
                    double fullScore, int unitOrder);
    void unitsListDone();
    void unitListError(const QString& message);
    void unitCreated(int id, const QString& name);
    void unitCreateError(const QString& message);
    void unitUpdated(int id);
    void unitUpdateError(const QString& message);
    void unitDeleted(int id);
    void unitDeleteError(const QString& message);
    void unitsReordered();
    void unitReorderError(const QString& message);

    // Scores
    void myScoresFetched(const QVariantMap& data);
    void myScoresError(const QString& message);
    void scoreSummaryFetched(const QVariantMap& summary);
    void scoreSummaryError(const QString& message);
    void scoreDistributionFetched(const QVariantMap& distribution);
    void scoreDistributionError(const QString& message);
    void scoreUpserted(const QVariantMap& result);
    void scoreUpsertError(const QString& message);
    void batchScoresUpserted();
    void batchScoresError(const QString& message);
    void scoresGenerateProgress(int done, int total);
    void scoresGenerateDone();
    void scoresGenerateError(const QString& message);

    // Videos
    void videoListReset();
    void videoListed(const QString& uuid, const QString& title, int duration,
                     int fileSize, bool hasCover, const QString& status,
                     const QString& createdAt);
    void videosListDone();
    void videoListError(const QString& message);
    void videoDetailFetched(const QVariantMap& detail);
    void videoDetailError(const QString& message);
    void videoUpdated(const QString& uuid);
    void videoUpdateError(const QString& message);
    void videoDeleted(const QString& uuid);
    void videoDeleteError(const QString& message);

    // Play Records
    void playRecordUpdated(const QVariantMap& record);
    void playRecordUpdateError(const QString& message);
    void playRecordFetched(const QVariantMap& record);
    void playRecordFetchError(const QString& message);
    void myPlayRecordsReset();
    void myPlayRecordListed(const QString& videoUuid, const QString& videoTitle,
                            int progress, int duration, bool completed,
                            const QString& lastPlayedAt);
    void myPlayRecordsError(const QString& message);

    // Users
    void profileUpdated(const QVariantMap& user);
    void profileUpdateError(const QString& message);
    void studentBound(const QVariantMap& user);
    void studentBindError(const QString& message);

    // AI
    void chatResponseReceived(const QString& content, const QString& model);
    void chatResponseError(const QString& message);

    // Announcements
    void announcementListReset();
    void announcementListed(const QString& uuid, const QString& title,
                            const QString& content, const QString& annType,
                            bool pinned, const QString& authorName,
                            const QString& createdAt);
    void announcementsListDone();
    void announcementsError(const QString& message);
    void announcementPublished(const QString& uuid, const QString& title);
    void announcementPublishError(const QString& message);
    void announcementDeleted(const QString& uuid);
    void announcementDeleteError(const QString& message);

    // Messages
    void messageListReset();
    void messageListed(const QString& uuid, const QString& senderName,
                       const QString& content, const QString& msgType,
                       bool isRead, const QString& subject,
                       const QString& recipientName, const QString& createdAt);
    void messagesListDone();
    void messagesError(const QString& message);
    void messageSent(const QString& uuid);
    void messageSendError(const QString& message);
    void messageMarkedRead(const QString& uuid);
    void messageReadError(const QString& message);
    void messageDeleted(const QString& uuid);
    void messageDeleteError(const QString& message);
    void unreadCountFetched(int unread, int total);
    void unreadCountError(const QString& message);
    void conversationReset();
    void conversationListed(const QString& uuid, const QString& senderUuid,
                            const QString& senderName, const QString& content,
                            const QString& msgType, bool isRead,
                            const QString& subject, const QString& createdAt);
    void conversationListDone();
    void conversationError(const QString& message);

    // Attendance
    void attendanceListReset();
    void attendanceListed(const QString& uuid, const QString& title,
                          const QString& status, int total, int presentCount,
                          int absentCount, int lateCount, int leaveCount,
                          const QString& createdAt);
    void attendancesListDone();
    void attendancesError(const QString& message);
    void attendanceStarted(const QVariantMap& detail);
    void attendanceStartError(const QString& message);
    void attendanceDetailFetched(const QVariantMap& detail);
    void attendanceDetailError(const QString& message);
    void attendanceMarked(const QVariantMap& record);
    void attendanceMarkError(const QString& message);
    void attendanceBatchMarked(int count);
    void attendanceBatchMarkError(const QString& message);
    void attendanceClosed(const QString& uuid);
    void attendanceCloseError(const QString& message);
    void attendanceDeleted(const QString& uuid);
    void attendanceDeleteError(const QString& message);

    // Batch Import
    void studentsImported(int total, int created, int skipped, const QStringList& errors);
    void studentsImportError(const QString& message);

    // Assignments
    void assignmentListReset();
    void assignmentListed(const QString& uuid, const QString& title,
                          const QString& description, const QString& dueDate,
                          double totalPoints, bool hasAttachment,
                          const QString& attachmentName, const QString& status,
                          const QString& authorName, int submissionCount,
                          const QString& createdAt);
    void assignmentsListDone();
    void assignmentsError(const QString& message);
    void assignmentPublished(const QString& uuid, const QString& title);
    void assignmentPublishError(const QString& message);
    void assignmentDeleted(const QString& uuid);
    void assignmentDeleteError(const QString& message);

    // Submissions
    void submissionListReset();
    void submissionListed(const QString& uuid, const QString& studentUuid,
                          const QString& studentName, const QString& studentNo,
                          const QString& content, const QString& fileName,
                          const QString& submittedAt, double score,
                          const QString& feedback, const QString& status,
                          const QString& createdAt);
    void submissionsListDone();
    void submissionsError(const QString& message);
    void submissionGraded(const QString& uuid);
    void submissionGradeError(const QString& message);
    void assignmentFileSubmitted(const QVariantMap& submission);
    void assignmentFileSubmitError(const QString& message);

    // File Upload
    void videoUploadProgress(const QString& stage, int percent);
    void videoUploadFinished(const QVariantMap& video);
    void videoUploadError(const QString& message);

    // General
    void requestError(const QString& endpoint, int statusCode, const QString& message);
    void authenticatedChanged();
    void usernameChanged();
    void serverUrlChanged();
    void autoLoginSkipped(const QString& reason);

private:
    QNetworkRequest buildRequest(const QString& path) const;
    void handleNetworkError(QNetworkReply* reply, const QString& endpoint);

    // HTTP helpers
    void getJson(const QString& path,
                 std::function<void(int status, const QJsonObject&)> callback);
    void postJson(const QString& path, const QJsonObject& body,
                  std::function<void(int status, const QJsonObject&)> callback);
    void patchJson(const QString& path, const QJsonObject& body,
                   std::function<void(int status, const QJsonObject&)> callback);
    void putJson(const QString& path, const QJsonObject& body,
                 std::function<void(int status, const QJsonObject&)> callback);
    void deleteResource(const QString& path,
                        std::function<void(int status)> callback);

    // Crypto helpers (static — no instance state needed for key derivation)
    static QByteArray deriveEncryptionKey();
    static QByteArray encryptXor(const QByteArray& plaintext, const QByteArray& key);
    static QByteArray decryptXor(const QByteArray& ciphertext, const QByteArray& key);
    QString credentialFilePath() const;

    QNetworkAccessManager* nam_;
    QString server_url_;
    QString token_;
    QString role_;
    QString user_uuid_;
    QString username_;
    bool remember_me_ = false;
};
