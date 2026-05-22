#pragma once

#include <QNetworkRequest>
#include <QObject>
#include <QString>

class QNetworkAccessManager;
class QNetworkReply;

class ApiClient : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString serverUrl READ serverUrl WRITE setServerUrl NOTIFY serverUrlChanged)
    Q_PROPERTY(bool authenticated READ isAuthenticated NOTIFY authenticatedChanged)
public:
    explicit ApiClient(QObject* parent = nullptr);

    QString serverUrl() const { return server_url_; }
    bool isAuthenticated() const { return !token_.isEmpty(); }

public slots:
    // --- Auth ---
    void login(const QString& username, const QString& password);
    void registerUser(const QString& username, const QString& password, const QString& role);
    void fetchCurrentUser();
    void logout();

    // --- Courses ---
    void listCourses();
    void createCourse(const QString& name, const QString& description);

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
    void courseListed(const QString& uuid, const QString& name, const QString& description);
    void courseCreated(const QString& uuid, const QString& name);
    void courseCreateError(const QString& message);

    // General
    void requestError(const QString& endpoint, int statusCode, const QString& message);
    void authenticatedChanged();
    void serverUrlChanged();

private:
    QNetworkRequest buildRequest(const QString& path) const;
    void handleNetworkError(QNetworkReply* reply, const QString& endpoint);

    QNetworkAccessManager* nam_;
    QString server_url_;
    QString token_;
    QString role_;
};
