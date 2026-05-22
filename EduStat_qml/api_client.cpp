#include "api_client.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QPointer>
#include <QSslSocket>
#include <QUrl>

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

static QString envStr(const char* name, const QString& fallback = {}) {
    auto v = qgetenv(name);
    return v.isEmpty() ? fallback : QString::fromLocal8Bit(v);
}

// ---------------------------------------------------------------------------
// Constructor
// ---------------------------------------------------------------------------

ApiClient::ApiClient(QObject* parent)
    : QObject(parent)
    , nam_(new QNetworkAccessManager(this))
    , server_url_(envStr("EDU_SERVER_URL", "https://124.222.82.196"))
{
    // Strip trailing slash
    if (server_url_.endsWith('/'))
        server_url_.chop(1);

    // Allow self-signed certs in dev
    if (envStr("EDU_INSECURE_SSL").toLower() == "true") {
        // Will be handled per-reply if needed; flag is stored for future use
    }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

QNetworkRequest ApiClient::buildRequest(const QString& path) const {
    QUrl url(server_url_ + path);
    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setTransferTimeout(15000);
    if (!token_.isEmpty()) {
        req.setRawHeader("Authorization", ("Bearer " + token_).toUtf8());
    }
    return req;
}

void ApiClient::handleNetworkError(QNetworkReply* reply, const QString& endpoint) {
    int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

    if (status == 401 && !token_.isEmpty()) {
        // Server says token is invalid/expired
        token_.clear();
        role_.clear();
        emit tokenExpired();
        emit authenticatedChanged();
    }

    QByteArray data = reply->readAll();
    QJsonObject err = QJsonDocument::fromJson(data).object();
    QString detail = err.value("detail").toString();
    if (detail.isEmpty())
        detail = reply->errorString();

    emit requestError(endpoint, status > 0 ? status : 0, detail);
}

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

void ApiClient::login(const QString& username, const QString& password) {
    QJsonObject body;
    body["username"] = username;
    body["password"] = password;

    QNetworkRequest req = buildRequest("/api/auth/login");
    QNetworkReply* reply = nam_->post(req, QJsonDocument(body).toJson());

    QPointer<ApiClient> self(this);
    connect(reply, &QNetworkReply::finished, this, [self, reply]() {
        reply->deleteLater();
        if (!self) return;

        int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (status != 200) {
            self->handleNetworkError(reply, "/api/auth/login");
            QByteArray data = reply->readAll();
            QJsonObject err = QJsonDocument::fromJson(data).object();
            QString detail = err.value("detail").toString("登录失败");
            emit self->loginError(detail);
            return;
        }

        QJsonObject resp = QJsonDocument::fromJson(reply->readAll()).object();
        self->token_ = resp["access_token"].toString();

        // Chain: fetch current user to get role
        QNetworkRequest ureq = self->buildRequest("/api/users/me");
        QNetworkReply* ureply = self->nam_->get(ureq);

        connect(ureply, &QNetworkReply::finished, self, [self, ureply]() {
            ureply->deleteLater();
            if (!self) return;

            int ustatus = ureply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            if (ustatus != 200) {
                self->handleNetworkError(ureply, "/api/users/me");
                emit self->loginError("无法获取用户信息");
                return;
            }

            QJsonObject uresp = QJsonDocument::fromJson(ureply->readAll()).object();
            self->role_ = uresp["role"].toString();

            emit self->authenticatedChanged();
            emit self->loginSuccess(self->token_, self->role_);
        });
    });
}

void ApiClient::registerUser(const QString& username, const QString& password, const QString& role) {
    QJsonObject body;
    body["username"] = username;
    body["password"] = password;
    body["role"] = role;

    QNetworkRequest req = buildRequest("/api/auth/register");
    QNetworkReply* reply = nam_->post(req, QJsonDocument(body).toJson());

    QPointer<ApiClient> self(this);
    connect(reply, &QNetworkReply::finished, this, [self, reply]() {
        reply->deleteLater();
        if (!self) return;

        int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (status != 201) {
            self->handleNetworkError(reply, "/api/auth/register");
            QByteArray data = reply->readAll();
            QJsonObject err = QJsonDocument::fromJson(data).object();
            QString detail = err.value("detail").toString("注册失败");
            emit self->registerError(detail);
            return;
        }

        QJsonObject resp = QJsonDocument::fromJson(reply->readAll()).object();
        QString uuid = resp["uuid"].toString();
        emit self->registerSuccess(uuid);
    });
}

void ApiClient::fetchCurrentUser() {
    QNetworkRequest req = buildRequest("/api/users/me");
    QNetworkReply* reply = nam_->get(req);

    QPointer<ApiClient> self(this);
    connect(reply, &QNetworkReply::finished, this, [self, reply]() {
        reply->deleteLater();
        if (!self) return;

        int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (status != 200) {
            self->handleNetworkError(reply, "/api/users/me");
            return;
        }

        QJsonObject resp = QJsonDocument::fromJson(reply->readAll()).object();
        self->role_ = resp["role"].toString();
        emit self->userFetched(
            resp["uuid"].toString(),
            resp["username"].toString(),
            self->role_);
    });
}

void ApiClient::logout() {
    token_.clear();
    role_.clear();
    emit authenticatedChanged();
}

// ---------------------------------------------------------------------------
// Courses
// ---------------------------------------------------------------------------

void ApiClient::listCourses() {
    QNetworkRequest req = buildRequest("/api/courses/");
    QNetworkReply* reply = nam_->get(req);

    QPointer<ApiClient> self(this);
    connect(reply, &QNetworkReply::finished, this, [self, reply]() {
        reply->deleteLater();
        if (!self) return;

        int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (status != 200) {
            self->handleNetworkError(reply, "/api/courses/");
            return;
        }

        QJsonArray arr = QJsonDocument::fromJson(reply->readAll()).array();
        emit self->courseListReset();
        for (const QJsonValue& v : arr) {
            QJsonObject c = v.toObject();
            emit self->courseListed(
                c["uuid"].toString(),
                c["name"].toString(),
                c["description"].toString());
        }
    });
}

void ApiClient::createCourse(const QString& name, const QString& description) {
    QJsonObject body;
    body["name"] = name;
    if (!description.isEmpty())
        body["description"] = description;

    QNetworkRequest req = buildRequest("/api/courses/");
    QNetworkReply* reply = nam_->post(req, QJsonDocument(body).toJson());

    QPointer<ApiClient> self(this);
    connect(reply, &QNetworkReply::finished, this, [self, reply]() {
        reply->deleteLater();
        if (!self) return;

        int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (status == 403) {
            emit self->courseCreateError("无权限创建课程");
            return;
        }
        if (status != 201 && status != 200) {
            self->handleNetworkError(reply, "/api/courses/");
            emit self->courseCreateError("创建课程失败");
            return;
        }

        QJsonObject resp = QJsonDocument::fromJson(reply->readAll()).object();
        emit self->courseCreated(
            resp["uuid"].toString(),
            resp["name"].toString());
    });
}

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

void ApiClient::setServerUrl(const QString& url) {
    if (server_url_ != url) {
        server_url_ = url;
        if (server_url_.endsWith('/'))
            server_url_.chop(1);
        emit serverUrlChanged();
    }
}
