#include "api_client.h"

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHttpMultiPart>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMimeDatabase>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QStandardPaths>
#include <QSysInfo>
#include <QPointer>
#include <QProcess>
#include <QRandomGenerator>
#include <QSslError>
#include <QStandardPaths>
#include <QTemporaryFile>
#include <QUrl>

extern "C" {
#include <xlsxwriter.h>
}

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
    if (server_url_.endsWith('/'))
        server_url_.chop(1);

    // Accept self-signed cert on dev server
    connect(nam_, &QNetworkAccessManager::sslErrors,
            this, [](QNetworkReply* reply, const QList<QSslError>&) {
        reply->ignoreSslErrors();
    });
}

// ---------------------------------------------------------------------------
// HTTP helpers — reduce boilerplate for the common request/response pattern
// ---------------------------------------------------------------------------

QNetworkRequest ApiClient::buildRequest(const QString& path) const {
    QUrl url(server_url_ + path);
    QNetworkRequest req(url);
    req.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setTransferTimeout(30000);
    if (!token_.isEmpty()) {
        req.setRawHeader("Authorization", ("Bearer " + token_).toUtf8());
    }
    return req;
}

void ApiClient::handleNetworkError(QNetworkReply* reply, const QString& endpoint) {
    int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

    if (status == 401 && !token_.isEmpty()) {
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

void ApiClient::getJson(const QString& path,
                        std::function<void(int, const QJsonObject&)> callback) {
    QNetworkRequest req = buildRequest(path);
    QNetworkReply* reply = nam_->get(req);
    QPointer<ApiClient> self(this);
    connect(reply, &QNetworkReply::finished, this, [self, reply, callback]() {
        reply->deleteLater();
        if (!self) return;
        int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        QJsonObject obj;
        if (status >= 200 && status < 300) {
            obj = QJsonDocument::fromJson(reply->readAll()).object();
        }
        callback(status, obj);
    });
}

void ApiClient::postJson(const QString& path, const QJsonObject& body,
                         std::function<void(int, const QJsonObject&)> callback) {
    QNetworkRequest req = buildRequest(path);
    QNetworkReply* reply = nam_->post(req, QJsonDocument(body).toJson());
    QPointer<ApiClient> self(this);
    connect(reply, &QNetworkReply::finished, this, [self, reply, callback]() {
        reply->deleteLater();
        if (!self) return;
        int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        QJsonObject obj;
        QByteArray data = reply->readAll();
        if (!data.isEmpty())
            obj = QJsonDocument::fromJson(data).object();
        callback(status, obj);
    });
}

void ApiClient::patchJson(const QString& path, const QJsonObject& body,
                          std::function<void(int, const QJsonObject&)> callback) {
    QNetworkRequest req = buildRequest(path);
    QNetworkReply* reply = nam_->sendCustomRequest(req, "PATCH", QJsonDocument(body).toJson());
    QPointer<ApiClient> self(this);
    connect(reply, &QNetworkReply::finished, this, [self, reply, callback]() {
        reply->deleteLater();
        if (!self) return;
        int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        QJsonObject obj;
        QByteArray data = reply->readAll();
        if (!data.isEmpty())
            obj = QJsonDocument::fromJson(data).object();
        callback(status, obj);
    });
}

void ApiClient::putJson(const QString& path, const QJsonObject& body,
                        std::function<void(int, const QJsonObject&)> callback) {
    QNetworkRequest req = buildRequest(path);
    QNetworkReply* reply = nam_->sendCustomRequest(req, "PUT", QJsonDocument(body).toJson());
    QPointer<ApiClient> self(this);
    connect(reply, &QNetworkReply::finished, this, [self, reply, callback]() {
        reply->deleteLater();
        if (!self) return;
        int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        QJsonObject obj;
        QByteArray data = reply->readAll();
        if (!data.isEmpty())
            obj = QJsonDocument::fromJson(data).object();
        callback(status, obj);
    });
}

void ApiClient::deleteResource(const QString& path,
                               std::function<void(int)> callback) {
    QNetworkRequest req = buildRequest(path);
    QNetworkReply* reply = nam_->deleteResource(req);
    QPointer<ApiClient> self(this);
    connect(reply, &QNetworkReply::finished, this, [self, reply, callback]() {
        reply->deleteLater();
        if (!self) return;
        int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        callback(status);
    });
}

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

void ApiClient::login(const QString& username, const QString& password) {
    QJsonObject body;
    body["username"] = username;
    body["password"] = password;

    postJson("/api/auth/login", body, [this, username, password](int status, const QJsonObject& obj) {
        if (status != 200) {
            QString detail = obj.value("detail").toString("登录失败");
            emit loginError(detail);
            return;
        }
        token_ = obj["access_token"].toString();

        // Chain: fetch current user to get role
        getJson("/api/users/me", [this, username, password](int ustatus, const QJsonObject& uobj) {
            if (ustatus != 200) {
                handleNetworkError(nullptr, "/api/users/me");
                emit loginError("无法获取用户信息");
                return;
            }
            role_ = uobj["role"].toString();
            user_uuid_ = uobj["uuid"].toString();
            emit authenticatedChanged();

            // Persist encrypted credentials if "remember me" was checked
            if (remember_me_) {
                saveCredentials(username, password);
            }

            emit loginSuccess(token_, role_);
        });
    });
}

void ApiClient::registerUser(const QString& username, const QString& password, const QString& role,
                             const QString& studentNo, const QString& realName) {
    QJsonObject body;
    body["username"] = username;
    body["password"] = password;
    body["role"] = role;
    if (!studentNo.isEmpty()) body["student_no"] = studentNo;
    if (!realName.isEmpty()) body["real_name"] = realName;

    postJson("/api/auth/register", body, [this](int status, const QJsonObject& obj) {
        if (status != 201) {
            QString detail = obj.value("detail").toString("注册失败");
            emit registerError(detail);
            return;
        }
        emit registerSuccess(obj["uuid"].toString());
    });
}

void ApiClient::fetchCurrentUser() {
    getJson("/api/users/me", [this](int status, const QJsonObject& obj) {
        if (status != 200) {
            return;
        }
        role_ = obj["role"].toString();
        user_uuid_ = obj["uuid"].toString();
        username_ = obj["username"].toString();
        emit usernameChanged();
        emit userFetched(obj["uuid"].toString(), username_, role_);
    });
}

void ApiClient::logout() {
    clearSavedCredentials();
    remember_me_ = false;
    token_.clear();
    role_.clear();
    user_uuid_.clear();
    username_.clear();
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
            QJsonObject teacher = c.value("teacher").toObject();
            emit self->courseListed(
                c["uuid"].toString(),
                c["name"].toString(),
                c["description"].toString(),
                c["status"].toString(),
                c["member_count"].toInt(),
                c["my_role"].toString());
        }
        emit self->coursesListDone();
    });
}

void ApiClient::createCourse(const QString& name, const QString& description) {
    QJsonObject body;
    body["name"] = name;
    if (!description.isEmpty())
        body["description"] = description;

    postJson("/api/courses/", body, [this](int status, const QJsonObject& obj) {
        if (status == 403) {
            emit courseCreateError("无权限创建课程");
            return;
        }
        if (status != 201) {
            emit courseCreateError("创建课程失败");
            return;
        }
        emit courseCreated(obj["uuid"].toString(), obj["name"].toString());
    });
}

void ApiClient::fetchCourseDetail(const QString& courseUuid) {
    getJson("/api/courses/" + courseUuid, [this, courseUuid](int status, const QJsonObject& obj) {
        if (status != 200) {
            QString detail = obj.value("detail").toString("获取课程详情失败");
            emit courseDetailError(detail);
            return;
        }
        emit courseDetailFetched(obj.toVariantMap());
    });
}

void ApiClient::updateCourse(const QString& courseUuid, const QString& name, const QString& description) {
    QJsonObject body;
    if (!name.isEmpty()) body["name"] = name;
    if (!description.isEmpty()) body["description"] = description;

    patchJson("/api/courses/" + courseUuid, body, [this, courseUuid](int status, const QJsonObject& obj) {
        if (status != 200) {
            QString detail = obj.value("detail").toString("更新课程失败");
            emit courseUpdateError(detail);
            return;
        }
        emit courseUpdated(courseUuid);
    });
}

void ApiClient::deleteCourse(const QString& courseUuid) {
    deleteResource("/api/courses/" + courseUuid, [this, courseUuid](int status) {
        if (status != 204) {
            emit courseDeleteError("删除课程失败");
            return;
        }
        emit courseDeleted(courseUuid);
    });
}

// ---------------------------------------------------------------------------
// Course Members
// ---------------------------------------------------------------------------

void ApiClient::fetchCourseMembers(const QString& courseUuid) {
    QNetworkRequest req = buildRequest("/api/courses/" + courseUuid + "/members");
    QNetworkReply* reply = nam_->get(req);
    QPointer<ApiClient> self(this);
    connect(reply, &QNetworkReply::finished, this, [self, reply, courseUuid]() {
        reply->deleteLater();
        if (!self) return;
        int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (status != 200) {
            QJsonObject err = QJsonDocument::fromJson(reply->readAll()).object();
            emit self->courseMembersError(err.value("detail").toString("获取成员列表失败"));
            return;
        }
        QJsonArray arr = QJsonDocument::fromJson(reply->readAll()).array();
        emit self->courseMembersReset();
        for (const QJsonValue& v : arr) {
            QJsonObject m = v.toObject();
            QJsonObject st = m.value("student").toObject();
            emit self->courseMemberListed(
                m["user_uuid"].toString(),
                m["username"].toString(),
                m["member_role"].toString(),
                m["joined_at"].toString(),
                st.value("student_no").toString(),
                st.value("real_name").toString());
        }
        emit self->courseMembersListDone();
    });
}

void ApiClient::addCourseMember(const QString& courseUuid, const QString& username) {
    QJsonObject body;
    body["username"] = username;

    postJson("/api/courses/" + courseUuid + "/members", body,
             [this](int status, const QJsonObject& obj) {
        if (status != 201) {
            QString detail = obj.value("detail").toString("添加成员失败");
            emit memberAddError(detail);
            return;
        }
        emit memberAdded(obj["user_uuid"].toString(), obj["username"].toString());
    });
}

void ApiClient::removeCourseMember(const QString& courseUuid, const QString& userUuid) {
    deleteResource("/api/courses/" + courseUuid + "/members/" + userUuid,
                   [this, userUuid](int status) {
        if (status != 204) {
            emit memberRemoveError("移除成员失败");
            return;
        }
        emit memberRemoved(userUuid);
    });
}

// ---------------------------------------------------------------------------
// Units
// ---------------------------------------------------------------------------

void ApiClient::fetchUnits(const QString& courseUuid) {
    QNetworkRequest req = buildRequest("/api/courses/" + courseUuid + "/units");
    QNetworkReply* reply = nam_->get(req);
    QPointer<ApiClient> self(this);
    connect(reply, &QNetworkReply::finished, this, [self, reply, courseUuid]() {
        reply->deleteLater();
        if (!self) return;
        int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (status != 200) {
            QJsonObject err = QJsonDocument::fromJson(reply->readAll()).object();
            emit self->unitListError(err.value("detail").toString("获取单元列表失败"));
            return;
        }
        QJsonArray arr = QJsonDocument::fromJson(reply->readAll()).array();
        emit self->unitListReset();
        for (const QJsonValue& v : arr) {
            QJsonObject u = v.toObject();
            emit self->unitListed(
                u["id"].toInt(),
                u["name"].toString(),
                u["weight"].toDouble(),
                u["full_score"].toDouble(),
                u["unit_order"].toInt());
        }
        emit self->unitsListDone();
    });
}

void ApiClient::createUnit(const QString& courseUuid, const QString& name,
                           double weight, double fullScore, int unitOrder) {
    QJsonObject body;
    body["name"] = name;
    body["weight"] = weight;
    body["full_score"] = fullScore;
    body["unit_order"] = unitOrder;

    postJson("/api/courses/" + courseUuid + "/units", body,
             [this](int status, const QJsonObject& obj) {
        if (status != 201) {
            QString detail = obj.value("detail").toString("创建单元失败");
            emit unitCreateError(detail);
            return;
        }
        emit unitCreated(obj["id"].toInt(), obj["name"].toString());
    });
}

void ApiClient::updateUnit(const QString& courseUuid, int unitId,
                           const QString& name, double weight, double fullScore, int unitOrder) {
    QJsonObject body;
    body["name"] = name;
    body["weight"] = weight;
    body["full_score"] = fullScore;
    body["unit_order"] = unitOrder;

    patchJson("/api/courses/" + courseUuid + "/units/" + QString::number(unitId), body,
              [this, unitId](int status, const QJsonObject& obj) {
        if (status != 200) {
            QString detail = obj.value("detail").toString("更新单元失败");
            emit unitUpdateError(detail);
            return;
        }
        emit unitUpdated(unitId);
    });
}

void ApiClient::deleteUnit(const QString& courseUuid, int unitId) {
    deleteResource("/api/courses/" + courseUuid + "/units/" + QString::number(unitId),
                   [this, unitId](int status) {
        if (status != 204) {
            emit unitDeleteError("删除单元失败");
            return;
        }
        emit unitDeleted(unitId);
    });
}

void ApiClient::reorderUnits(const QString& courseUuid, const QVariantList& orders) {
    QJsonArray arr;
    for (const QVariant& item : orders) {
        QVariantMap m = item.toMap();
        QJsonObject o;
        o["unit_id"] = m["unit_id"].toInt();
        o["unit_order"] = m["unit_order"].toInt();
        arr.append(o);
    }
    QJsonObject body;
    // The backend expects a raw JSON array as the body root
    QNetworkRequest req = buildRequest("/api/courses/" + courseUuid + "/units/reorder");
    QNetworkReply* reply = nam_->post(req, QJsonDocument(arr).toJson());
    QPointer<ApiClient> self(this);
    connect(reply, &QNetworkReply::finished, this, [self, reply]() {
        reply->deleteLater();
        if (!self) return;
        int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (status != 204) {
            emit self->unitReorderError("排序失败");
            return;
        }
        emit self->unitsReordered();
    });
}

// ---------------------------------------------------------------------------
// Scores
// ---------------------------------------------------------------------------

void ApiClient::fetchMyScores(const QString& courseUuid) {
    getJson("/api/scores/course/" + courseUuid + "/my",
            [this](int status, const QJsonObject& obj) {
        if (status != 200) {
            QString detail = obj.value("detail").toString("获取成绩失败");
            emit myScoresError(detail);
            return;
        }
        emit myScoresFetched(obj.toVariantMap());
    });
}

void ApiClient::fetchScoreSummary(const QString& courseUuid) {
    getJson("/api/scores/course/" + courseUuid + "/summary",
            [this](int status, const QJsonObject& obj) {
        if (status != 200) {
            QString detail = obj.value("detail").toString("获取成绩汇总失败");
            emit scoreSummaryError(detail);
            return;
        }
        emit scoreSummaryFetched(obj.toVariantMap());
    });
}

void ApiClient::fetchScoreDistribution(const QString& courseUuid) {
    getJson("/api/scores/course/" + courseUuid + "/distribution",
            [this](int status, const QJsonObject& obj) {
        if (status != 200) {
            QString detail = obj.value("detail").toString("获取成绩分布失败");
            emit scoreDistributionError(detail);
            return;
        }
        emit scoreDistributionFetched(obj.toVariantMap());
    });
}

void ApiClient::upsertScore(const QString& courseUuid, const QString& studentUuid,
                            int unitId, double score) {
    QJsonObject body;
    body["course_uuid"] = courseUuid;
    body["student_uuid"] = studentUuid;
    body["unit_id"] = unitId;
    body["score"] = score;

    postJson("/api/scores/", body, [this](int status, const QJsonObject& obj) {
        if (status != 201) {
            QString detail = obj.value("detail").toString("录入成绩失败");
            emit scoreUpsertError(detail);
            return;
        }
        emit scoreUpserted(obj.toVariantMap());
    });
}

void ApiClient::batchUpsertScores(const QString& courseUuid, int unitId,
                                  const QVariantList& scores) {
    QJsonArray scoreArr;
    for (const QVariant& s : scores) {
        QVariantMap m = s.toMap();
        QJsonObject entry;
        entry["student_uuid"] = m["student_uuid"].toString();
        entry["score"] = m["score"].toDouble();
        scoreArr.append(entry);
    }
    QJsonObject body;
    body["course_uuid"] = courseUuid;
    body["unit_id"] = unitId;
    body["scores"] = scoreArr;

    postJson("/api/scores/batch", body, [this](int status, const QJsonObject& obj) {
        if (status != 204) {
            QString detail = obj.value("detail").toString("批量录入失败");
            emit batchScoresError(detail);
            return;
        }
        emit batchScoresUpserted();
    });
}

void ApiClient::generateRandomScores(const QString& courseUuid) {
    // Validate role: only admin can generate random scores (not for teachers)
    if (role_ != "admin") {
        emit scoresGenerateError(QStringLiteral("仅教师或管理员可以生成成绩"));
        return;
    }

    struct GenState {
        QList<QPair<int, double>> units;    // (unitId, fullScore)
        QList<QString> studentUuids;         // student user uuids
        bool unitsDone = false;
        bool membersDone = false;
    };
    auto state = std::make_shared<GenState>();
    QPointer<ApiClient> self(this);

    // Cleanup helper: disconnect a list of temporary signal connections
    struct ConnGroup {
        std::shared_ptr<QMetaObject::Connection> a;
        std::shared_ptr<QMetaObject::Connection> b;
        std::shared_ptr<QMetaObject::Connection> c;
        void disconnectAll() {
            if (a) QObject::disconnect(*a);
            if (b) QObject::disconnect(*b);
            if (c) QObject::disconnect(*c);
        }
    };

    // Shared "both done" checker: when both fetches complete, start batch generation
    auto tryStart = [this, courseUuid, state, self]() {
        if (!state->unitsDone || !state->membersDone) return;
        if (!self) return;

        if (state->units.isEmpty()) {
            emit scoresGenerateError(QStringLiteral("该课程暂无教学单元，请先创建单元"));
            return;
        }
        if (state->studentUuids.isEmpty()) {
            emit scoresGenerateError(QStringLiteral("该课程暂无学生"));
            return;
        }

        // ---- Sequential batch generation per unit ----
        auto unitIdx = std::make_shared<int>(0);
        const int total = state->units.size();
        emit scoresGenerateProgress(0, total);

        // Recursive lambda: process one unit, then connect signal for next
        auto processNext = std::make_shared<std::function<void()>>();
        auto batchOkConn = std::make_shared<QMetaObject::Connection>();
        auto batchErrConn = std::make_shared<QMetaObject::Connection>();

        *processNext = [this, courseUuid, state, self, unitIdx, total,
                        processNext, batchOkConn, batchErrConn]() {
            if (!self) return;
            int i = *unitIdx;
            if (i >= total) {
                // All done
                disconnect(*batchOkConn);
                disconnect(*batchErrConn);
                emit scoresGenerateDone();
                return;
            }

            auto [unitId, fullScore] = state->units[i];
            QVariantList scoreEntries;

            for (const QString& studentUuid : state->studentUuids) {
                // Generate random score: normal-like distribution around 78, clamped to [30, 100]
                double r = QRandomGenerator::global()->generateDouble();
                // Box-Muller-like: sum of 3 uniforms gives a bell-ish curve
                double r2 = QRandomGenerator::global()->generateDouble();
                double r3 = QRandomGenerator::global()->generateDouble();
                double raw = 55.0 + (r + r2 + r3) * 15.0;  // mean ~77.5, range [55, 100]
                int score = qBound(30, static_cast<int>(raw + 0.5), static_cast<int>(fullScore));

                QVariantMap entry;
                entry["student_uuid"] = studentUuid;
                entry["score"] = score;
                scoreEntries.append(entry);
            }

            emit scoresGenerateProgress(i + 1, total);

            // Connect one-shot handlers for this batch
            disconnect(*batchOkConn);
            disconnect(*batchErrConn);
            *batchOkConn = connect(this, &ApiClient::batchScoresUpserted, this,
                                   [processNext, unitIdx]() {
                (*unitIdx)++;
                (*processNext)();
            }, Qt::SingleShotConnection);
            *batchErrConn = connect(this, &ApiClient::batchScoresError, this,
                                    [this, batchOkConn, batchErrConn](const QString& msg) {
                disconnect(*batchOkConn);
                disconnect(*batchErrConn);
                emit scoresGenerateError(QStringLiteral("批量录入失败: %1").arg(msg));
            }, Qt::SingleShotConnection);

            batchUpsertScores(courseUuid, unitId, scoreEntries);
        };

        (*processNext)();
    };

    // ---- Collect units from signals ----
    auto unitConns = std::make_shared<ConnGroup>();
    unitConns->a = std::make_shared<QMetaObject::Connection>(
        connect(this, &ApiClient::unitListReset, this, [state]() {
            state->units.clear();
        }));
    unitConns->b = std::make_shared<QMetaObject::Connection>(
        connect(this, &ApiClient::unitListed, this,
            [state](int id, const QString&, double, double fullScore, int) {
                state->units.append({id, fullScore > 0 ? fullScore : 100.0});
            }));
    unitConns->c = std::make_shared<QMetaObject::Connection>(
        connect(this, &ApiClient::unitsListDone, this,
            [state, unitConns, tryStart]() {
                unitConns->disconnectAll();
                state->unitsDone = true;
                tryStart();
            }));

    // ---- Collect student members from signals ----
    auto memberConns = std::make_shared<ConnGroup>();
    memberConns->a = std::make_shared<QMetaObject::Connection>(
        connect(this, &ApiClient::courseMembersReset, this, [state]() {
            state->studentUuids.clear();
        }));
    memberConns->b = std::make_shared<QMetaObject::Connection>(
        connect(this, &ApiClient::courseMemberListed, this,
            [state](const QString& userUuid, const QString&, const QString& memberRole,
                    const QString&, const QString&, const QString&) {
                if (memberRole == QStringLiteral("student"))
                    state->studentUuids.append(userUuid);
            }));
    memberConns->c = std::make_shared<QMetaObject::Connection>(
        connect(this, &ApiClient::courseMembersListDone, this,
            [state, memberConns, tryStart]() {
                memberConns->disconnectAll();
                state->membersDone = true;
                tryStart();
            }));

    // Kick off both fetches in parallel
    fetchUnits(courseUuid);
    fetchCourseMembers(courseUuid);
}

// ---------------------------------------------------------------------------
// Videos
// ---------------------------------------------------------------------------

void ApiClient::fetchCourseVideos(const QString& courseUuid) {
    QNetworkRequest req = buildRequest("/api/videos/course/" + courseUuid);
    QNetworkReply* reply = nam_->get(req);
    QPointer<ApiClient> self(this);
    connect(reply, &QNetworkReply::finished, this, [self, reply]() {
        reply->deleteLater();
        if (!self) return;
        int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (status != 200) {
            QJsonObject err = QJsonDocument::fromJson(reply->readAll()).object();
            emit self->videoListError(err.value("detail").toString("获取视频列表失败"));
            return;
        }
        QJsonArray arr = QJsonDocument::fromJson(reply->readAll()).array();
        emit self->videoListReset();
        for (const QJsonValue& v : arr) {
            QJsonObject vid = v.toObject();
            emit self->videoListed(
                vid["uuid"].toString(),
                vid["title"].toString(),
                vid["duration"].toInt(),
                vid["file_size"].toInt(),
                vid["has_cover"].toBool(),
                vid["status"].toString(),
                vid["created_at"].toString());
        }
        emit self->videosListDone();
    });
}

void ApiClient::fetchVideoDetail(const QString& videoUuid) {
    getJson("/api/videos/" + videoUuid, [this](int status, const QJsonObject& obj) {
        if (status != 200) {
            QString detail = obj.value("detail").toString("获取视频详情失败");
            emit videoDetailError(detail);
            return;
        }
        emit videoDetailFetched(obj.toVariantMap());
    });
}

void ApiClient::updateVideo(const QString& videoUuid, const QString& title,
                            const QString& description, const QString& status) {
    QJsonObject body;
    if (!title.isEmpty()) body["title"] = title;
    if (!description.isEmpty()) body["description"] = description;
    if (!status.isEmpty()) body["status"] = status;

    patchJson("/api/videos/" + videoUuid, body, [this, videoUuid](int s, const QJsonObject& obj) {
        if (s != 200) {
            QString detail = obj.value("detail").toString("更新视频失败");
            emit videoUpdateError(detail);
            return;
        }
        emit videoUpdated(videoUuid);
    });
}

void ApiClient::deleteVideo(const QString& videoUuid) {
    deleteResource("/api/videos/" + videoUuid, [this, videoUuid](int status) {
        if (status != 204) {
            emit videoDeleteError("删除视频失败");
            return;
        }
        emit videoDeleted(videoUuid);
    });
}

// ---------------------------------------------------------------------------
// Play Records
// ---------------------------------------------------------------------------

void ApiClient::updatePlayRecord(const QString& videoUuid, int progress, bool completed) {
    QJsonObject body;
    body["video_uuid"] = videoUuid;
    body["progress"] = progress;
    body["completed"] = completed;

    postJson("/api/play-records/update", body, [this](int status, const QJsonObject& obj) {
        if (status != 200) {
            QString detail = obj.value("detail").toString("更新播放记录失败");
            emit playRecordUpdateError(detail);
            return;
        }
        emit playRecordUpdated(obj.toVariantMap());
    });
}

void ApiClient::fetchPlayRecord(const QString& videoUuid) {
    getJson("/api/play-records/" + videoUuid, [this](int status, const QJsonObject& obj) {
        if (status != 200) {
            // Returns default values on 404, but server should always return 200
            emit playRecordFetched(obj.toVariantMap());
            return;
        }
        emit playRecordFetched(obj.toVariantMap());
    });
}

void ApiClient::fetchMyPlayRecords(const QString& courseUuid) {
    QNetworkRequest req = buildRequest("/api/play-records/course/" + courseUuid + "/my");
    QNetworkReply* reply = nam_->get(req);
    QPointer<ApiClient> self(this);
    connect(reply, &QNetworkReply::finished, this, [self, reply]() {
        reply->deleteLater();
        if (!self) return;
        int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (status != 200) {
            QJsonObject err = QJsonDocument::fromJson(reply->readAll()).object();
            emit self->myPlayRecordsError(err.value("detail").toString("获取播放记录失败"));
            return;
        }
        QJsonArray arr = QJsonDocument::fromJson(reply->readAll()).array();
        emit self->myPlayRecordsReset();
        for (const QJsonValue& v : arr) {
            QJsonObject r = v.toObject();
            emit self->myPlayRecordListed(
                r["video_uuid"].toString(),
                r["video_title"].toString(),
                r["progress"].toInt(),
                r["duration"].toInt(),
                r["completed"].toBool(),
                r["last_played_at"].toString());
        }
    });
}

// ---------------------------------------------------------------------------
// Users
// ---------------------------------------------------------------------------

void ApiClient::updateProfile(const QString& username) {
    QJsonObject body;
    body["username"] = username;

    patchJson("/api/users/me", body, [this](int status, const QJsonObject& obj) {
        if (status != 200) {
            QString detail = obj.value("detail").toString("更新资料失败");
            emit profileUpdateError(detail);
            return;
        }
        emit profileUpdated(obj.toVariantMap());
    });
}

void ApiClient::bindStudent(const QString& studentNo, const QString& realName) {
    QJsonObject body;
    body["student_no"] = studentNo;
    body["real_name"] = realName;

    postJson("/api/users/bind", body, [this](int status, const QJsonObject& obj) {
        if (status != 201) {
            QString detail = obj.value("detail").toString("绑定学生档案失败");
            emit studentBindError(detail);
            return;
        }
        emit studentBound(obj.toVariantMap());
    });
}

// ---------------------------------------------------------------------------
// AI Chat
// ---------------------------------------------------------------------------

void ApiClient::chatWithAI(const QVariantList& messages) {
    // 通过服务器 /api/ai/chat 代理调用 DeepSeek（API key 只保存在服务器）
    QJsonArray msgArr;
    for (const QVariant& m : messages) {
        QVariantMap mm = m.toMap();
        QJsonObject mo;
        mo["role"] = mm["role"].toString();
        mo["content"] = mm["content"].toString();
        msgArr.append(mo);
    }

    QJsonObject body;
    body["messages"] = msgArr;

    QNetworkRequest req = buildRequest("/api/ai/chat");
    QJsonDocument doc(body);
    QNetworkReply* reply = nam_->post(req, doc.toJson(QJsonDocument::Compact));

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            QByteArray raw = reply->readAll();
            QString detail;
            QJsonDocument errDoc = QJsonDocument::fromJson(raw);
            if (errDoc.isObject()) {
                QJsonObject errObj = errDoc.object();
                detail = errObj.value("detail").toString();
            }
            if (detail.isEmpty())
                detail = QStringLiteral("AI 请求失败 (HTTP %1)").arg(statusCode);
            emit chatResponseError(detail);
            return;
        }

        QByteArray raw = reply->readAll();
        QJsonDocument respDoc = QJsonDocument::fromJson(raw);
        if (!respDoc.isObject()) {
            emit chatResponseError(QStringLiteral("AI 返回无效 JSON"));
            return;
        }

        QJsonObject obj = respDoc.object();
        QString content = obj.value("content").toString();
        QString model = obj.value("model").toString();

        if (content.isEmpty()) {
            emit chatResponseError(QStringLiteral("AI 响应无文本内容"));
            return;
        }

        emit chatResponseReceived(content, model);
    });
}

// ---------------------------------------------------------------------------
// Announcements
// ---------------------------------------------------------------------------

void ApiClient::fetchAnnouncements(const QString& courseUuid) {
    QNetworkRequest req = buildRequest("/api/courses/" + courseUuid + "/announcements");
    QNetworkReply* reply = nam_->get(req);
    QPointer<ApiClient> self(this);
    connect(reply, &QNetworkReply::finished, this, [self, reply]() {
        reply->deleteLater();
        if (!self) return;
        int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (status != 200) {
            self->handleNetworkError(reply, "/api/courses/.../announcements");
            emit self->announcementsError("获取公告列表失败");
            return;
        }
        QJsonArray arr = QJsonDocument::fromJson(reply->readAll()).array();
        emit self->announcementListReset();
        for (const QJsonValue& v : arr) {
            QJsonObject a = v.toObject();
            QJsonObject author = a.value("author").toObject();
            emit self->announcementListed(
                a["uuid"].toString(),
                a["title"].toString(),
                a["content"].toString(),
                a["ann_type"].toString(),
                a["pinned"].toBool(),
                author["username"].toString(),
                a["created_at"].toString());
        }
        emit self->announcementsListDone();
    });
}

void ApiClient::publishAnnouncement(const QString& courseUuid, const QString& title,
                                     const QString& content, const QString& annType,
                                     bool pinned, bool notify) {
    QJsonObject body;
    body["title"] = title;
    body["content"] = content;
    body["ann_type"] = annType;
    body["pinned"] = pinned;
    body["notify"] = notify;

    postJson("/api/courses/" + courseUuid + "/announcements", body,
             [this](int status, const QJsonObject& obj) {
        if (status == 403) {
            emit announcementPublishError("无权限发布公告（仅教师/管理员）");
            return;
        }
        if (status != 201) {
            emit announcementPublishError(obj.value("detail").toString("发布公告失败"));
            return;
        }
        emit announcementPublished(obj["uuid"].toString(), obj["title"].toString());
    });
}

void ApiClient::deleteAnnouncement(const QString& courseUuid, const QString& announcementUuid) {
    deleteResource("/api/courses/" + courseUuid + "/announcements/" + announcementUuid,
                   [this, announcementUuid](int status) {
        if (status != 204) {
            emit announcementDeleteError("删除公告失败");
            return;
        }
        emit announcementDeleted(announcementUuid);
    });
}

// ---------------------------------------------------------------------------
// Assignments
// ---------------------------------------------------------------------------

void ApiClient::fetchAssignments(const QString& courseUuid) {
    QNetworkRequest req = buildRequest("/api/courses/" + courseUuid + "/assignments");
    QNetworkReply* reply = nam_->get(req);
    QPointer<ApiClient> self(this);
    connect(reply, &QNetworkReply::finished, this, [self, reply]() {
        reply->deleteLater();
        if (!self) return;
        int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (status != 200) {
            self->handleNetworkError(reply, "/api/courses/.../assignments");
            emit self->assignmentsError("获取作业列表失败");
            return;
        }
        QJsonArray arr = QJsonDocument::fromJson(reply->readAll()).array();
        emit self->assignmentListReset();
        for (const QJsonValue& v : arr) {
            QJsonObject a = v.toObject();
            QJsonObject author = a.value("author").toObject();
            emit self->assignmentListed(
                a["uuid"].toString(),
                a["title"].toString(),
                a["description"].toString(),
                a["due_date"].toString(),
                a["total_points"].toDouble(),
                a["has_attachment"].toBool(),
                a["attachment_name"].toString(),
                a["status"].toString(),
                author["username"].toString(),
                a["submission_count"].toInt(),
                a["created_at"].toString());
        }
        emit self->assignmentsListDone();
    });
}

void ApiClient::publishAssignment(const QString& courseUuid, const QString& title,
                                   const QString& description, const QString& dueDate,
                                   double totalPoints) {
    QJsonObject body;
    body["title"] = title;
    body["description"] = description;
    if (!dueDate.isEmpty()) body["due_date"] = dueDate;
    if (totalPoints > 0) body["total_points"] = totalPoints;

    postJson("/api/courses/" + courseUuid + "/assignments", body,
             [this](int status, const QJsonObject& obj) {
        if (status == 403) {
            emit assignmentPublishError("无权限发布作业（仅教师/管理员）");
            return;
        }
        if (status != 200 && status != 201) {
            emit assignmentPublishError(obj.value("detail").toString("发布作业失败"));
            return;
        }
        emit assignmentPublished(obj["uuid"].toString(), obj["title"].toString());
    });
}

void ApiClient::deleteAssignment(const QString& courseUuid, const QString& assignmentUuid) {
    deleteResource("/api/courses/" + courseUuid + "/assignments/" + assignmentUuid,
                   [this, assignmentUuid](int status) {
        if (status != 204) {
            emit assignmentDeleteError("删除作业失败");
            return;
        }
        emit assignmentDeleted(assignmentUuid);
    });
}

void ApiClient::fetchSubmissions(const QString& courseUuid, const QString& assignmentUuid) {
    QNetworkRequest req = buildRequest(
        "/api/courses/" + courseUuid + "/assignments/" + assignmentUuid + "/submissions");
    QNetworkReply* reply = nam_->get(req);
    QPointer<ApiClient> self(this);
    connect(reply, &QNetworkReply::finished, this, [self, reply]() {
        reply->deleteLater();
        if (!self) return;
        int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (status != 200) {
            self->handleNetworkError(reply, "/api/courses/.../submissions");
            emit self->submissionsError("获取提交列表失败");
            return;
        }
        QJsonArray arr = QJsonDocument::fromJson(reply->readAll()).array();
        emit self->submissionListReset();
        for (const QJsonValue& v : arr) {
            QJsonObject s = v.toObject();
            emit self->submissionListed(
                s["uuid"].toString(),
                s["student_uuid"].toString(),
                s["student_name"].toString(),
                s["student_no"].toString(),
                s["content"].toString(),
                s["file_name"].toString(),
                s["submitted_at"].toString(),
                s["score"].toDouble(),
                s["feedback"].toString(),
                s["status"].toString(),
                s["created_at"].toString());
        }
        emit self->submissionsListDone();
    });
}

void ApiClient::gradeSubmission(const QString& courseUuid, const QString& assignmentUuid,
                                 const QString& submissionUuid, double score,
                                 const QString& feedback) {
    QJsonObject body;
    body["score"] = score;
    if (!feedback.isEmpty()) body["feedback"] = feedback;

    patchJson("/api/courses/" + courseUuid + "/assignments/" + assignmentUuid
              + "/submissions/" + submissionUuid, body,
              [this, submissionUuid](int status, const QJsonObject& obj) {
        if (status == 403) {
            emit submissionGradeError("无权限评分（仅教师/管理员）");
            return;
        }
        if (status != 200) {
            emit submissionGradeError(obj.value("detail").toString("评分失败"));
            return;
        }
        emit submissionGraded(submissionUuid);
    });
}

// ---------------------------------------------------------------------------
// Messages
// ---------------------------------------------------------------------------

void ApiClient::fetchMessages(const QString& courseUuid) {
    QNetworkRequest req = buildRequest("/api/courses/" + courseUuid + "/messages");
    QNetworkReply* reply = nam_->get(req);
    QPointer<ApiClient> self(this);
    connect(reply, &QNetworkReply::finished, this, [self, reply]() {
        reply->deleteLater();
        if (!self) return;
        int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (status != 200) {
            self->handleNetworkError(reply, "/api/courses/.../messages");
            emit self->messagesError("获取消息列表失败");
            return;
        }
        QJsonArray arr = QJsonDocument::fromJson(reply->readAll()).array();
        emit self->messageListReset();
        for (const QJsonValue& v : arr) {
            QJsonObject m = v.toObject();
            QJsonObject sender = m.value("sender").toObject();
            QJsonObject recipient = m.value("recipient").toObject();
            emit self->messageListed(
                m["uuid"].toString(),
                sender["username"].toString(),
                m["content"].toString(),
                m["msg_type"].toString(),
                m["is_read"].toBool(),
                m["subject"].toString(),
                recipient["username"].toString(),
                m["created_at"].toString());
        }
        emit self->messagesListDone();
    });
}

void ApiClient::sendMessage(const QString& courseUuid, const QString& content,
                             const QString& msgType, const QString& subject,
                             const QString& recipientUsername) {
    QJsonObject body;
    body["content"] = content;
    body["msg_type"] = msgType;
    if (!subject.isEmpty()) body["subject"] = subject;
    if (!recipientUsername.isEmpty()) body["recipient_username"] = recipientUsername;

    postJson("/api/courses/" + courseUuid + "/messages", body,
             [this](int status, const QJsonObject& obj) {
        if (status == 403) {
            emit messageSendError("无权限发送消息（仅教师/管理员）");
            return;
        }
        if (status != 201) {
            emit messageSendError(obj.value("detail").toString("发送消息失败"));
            return;
        }
        emit messageSent(obj["uuid"].toString());
    });
}

void ApiClient::markMessageRead(const QString& courseUuid, const QString& messageUuid) {
    postJson("/api/courses/" + courseUuid + "/messages/" + messageUuid + "/read",
             QJsonObject(), [this, messageUuid](int status, const QJsonObject& obj) {
        if (status != 200) {
            emit messageReadError(obj.value("detail").toString("标记已读失败"));
            return;
        }
        emit messageMarkedRead(messageUuid);
    });
}

void ApiClient::deleteMessage(const QString& courseUuid, const QString& messageUuid) {
    deleteResource("/api/courses/" + courseUuid + "/messages/" + messageUuid,
                   [this, messageUuid](int status) {
        if (status != 204) {
            emit messageDeleteError("删除消息失败");
            return;
        }
        emit messageDeleted(messageUuid);
    });
}

void ApiClient::fetchUnreadCount(const QString& courseUuid) {
    getJson("/api/courses/" + courseUuid + "/messages/unread-count",
            [this](int status, const QJsonObject& obj) {
        if (status != 200) {
            emit unreadCountError(obj.value("detail").toString("获取未读数失败"));
            return;
        }
        emit unreadCountFetched(obj["unread"].toInt(), obj["total"].toInt());
    });
}

void ApiClient::fetchConversation(const QString& courseUuid, const QString& otherUserUuid) {
    QNetworkRequest req = buildRequest(
        "/api/courses/" + courseUuid + "/messages/conversation/" + otherUserUuid);
    QNetworkReply* reply = nam_->get(req);
    QPointer<ApiClient> self(this);
    connect(reply, &QNetworkReply::finished, this, [self, reply]() {
        reply->deleteLater();
        if (!self) return;
        int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (status != 200) {
            QJsonObject obj = QJsonDocument::fromJson(reply->readAll()).object();
            emit self->conversationError(obj.value("detail").toString("获取对话失败"));
            return;
        }
        QJsonArray arr = QJsonDocument::fromJson(reply->readAll()).array();
        emit self->conversationReset();
        for (const QJsonValue& v : arr) {
            QJsonObject m = v.toObject();
            QJsonObject sender = m.value("sender").toObject();
            emit self->conversationListed(
                m["uuid"].toString(),
                sender["uuid"].toString(),
                sender["username"].toString(),
                m["content"].toString(),
                m["msg_type"].toString(),
                m["is_read"].toBool(),
                m["subject"].toString(),
                m["created_at"].toString());
        }
        emit self->conversationListDone();
    });
}

// ---------------------------------------------------------------------------
// Attendance
// ---------------------------------------------------------------------------

void ApiClient::fetchAttendances(const QString& courseUuid) {
    emit attendanceListReset();
    // Server returns a JSON array directly, not wrapped in an object.
    // We need to read the raw response as an array.
    QNetworkRequest req = buildRequest(
        QStringLiteral("/api/courses/%1/attendance").arg(courseUuid));
    QNetworkReply* reply = nam_->get(req);
    QPointer<ApiClient> self(this);
    connect(reply, &QNetworkReply::finished, this, [this, self, reply]() {
        reply->deleteLater();
        if (!self) return;
        int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        QByteArray data = reply->readAll();
        if (httpStatus == 200) {
            QJsonArray arr = QJsonDocument::fromJson(data).array();
            for (const auto& v : arr) {
                QJsonObject a = v.toObject();
                emit attendanceListed(
                    a["uuid"].toString(),
                    a["title"].toString(),
                    a["status"].toString(),
                    a["total"].toInt(),
                    a["present_count"].toInt(),
                    a["absent_count"].toInt(),
                    a["late_count"].toInt(),
                    a["leave_count"].toInt(),
                    a["created_at"].toString()
                );
            }
        } else {
            QJsonObject obj = QJsonDocument::fromJson(data).object();
            emit attendancesError(obj["detail"].toString());
        }
        emit attendancesListDone();
    });
}

void ApiClient::startAttendance(const QString& courseUuid, const QString& title) {
    QJsonObject req;
    req["title"] = title;
    postJson(QStringLiteral("/api/courses/%1/attendance").arg(courseUuid), req,
             [this](int status, const QJsonObject& body) {
        if (status == 201) {
            emit attendanceStarted(body.toVariantMap());
        } else {
            emit attendanceStartError(body["detail"].toString());
        }
    });
}

void ApiClient::fetchAttendanceDetail(const QString& courseUuid, const QString& attendanceUuid) {
    getJson(QStringLiteral("/api/courses/%1/attendance/%2").arg(courseUuid, attendanceUuid),
            [this](int status, const QJsonObject& body) {
        if (status == 200) {
            emit attendanceDetailFetched(body.toVariantMap());
        } else {
            emit attendanceDetailError(body["detail"].toString());
        }
    });
}

void ApiClient::markAttendance(const QString& courseUuid, const QString& attendanceUuid,
                                const QString& studentUuid, const QString& status,
                                const QString& note) {
    QJsonObject req;
    req["student_uuid"] = studentUuid;
    req["status"] = status;
    if (!note.isEmpty())
        req["note"] = note;
    putJson(QStringLiteral("/api/courses/%1/attendance/%2/mark").arg(courseUuid, attendanceUuid),
            req,
            [this](int httpStatus, const QJsonObject& body) {
        if (httpStatus == 200) {
            emit attendanceMarked(body.toVariantMap());
        } else {
            emit attendanceMarkError(body["detail"].toString());
        }
    });
}

void ApiClient::batchMarkAttendance(const QString& courseUuid, const QString& attendanceUuid,
                                     const QJsonArray& marks) {
    // Send the array directly as the body (server accepts list[AttendanceMark])
    QNetworkRequest req = buildRequest(
        QStringLiteral("/api/courses/%1/attendance/%2/mark-batch")
            .arg(courseUuid, attendanceUuid));
    req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    QNetworkReply* reply = nam_->put(req, QJsonDocument(marks).toJson());
    QPointer<ApiClient> self(this);
    connect(reply, &QNetworkReply::finished, this, [this, self, reply]() {
        reply->deleteLater();
        if (!self) return;
        int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        QByteArray data = reply->readAll();
        QJsonObject body = QJsonDocument::fromJson(data).object();
        if (httpStatus == 200) {
            emit attendanceBatchMarked(body["marked"].toInt());
        } else if (!body["detail"].isUndefined()) {
            emit attendanceBatchMarkError(body["detail"].toString());
        } else {
            emit attendanceBatchMarkError(reply->errorString());
        }
    });
}

void ApiClient::closeAttendance(const QString& courseUuid, const QString& attendanceUuid) {
    QJsonObject emptyBody;
    putJson(QStringLiteral("/api/courses/%1/attendance/%2/close").arg(courseUuid, attendanceUuid),
            emptyBody,
            [this](int httpStatus, const QJsonObject& body) {
        if (httpStatus == 200) {
            emit attendanceClosed(body["uuid"].toString());
        } else {
            emit attendanceCloseError(body["detail"].toString());
        }
    });
}

void ApiClient::deleteAttendance(const QString& courseUuid, const QString& attendanceUuid) {
    deleteResource(
        QStringLiteral("/api/courses/%1/attendance/%2").arg(courseUuid, attendanceUuid),
        [this, attendanceUuid](int httpStatus) {
            if (httpStatus == 204) {
                emit attendanceDeleted(attendanceUuid);
            } else {
                emit attendanceDeleteError(QStringLiteral("删除失败"));
            }
        });
}

// ---------------------------------------------------------------------------
// Batch Student Import
// ---------------------------------------------------------------------------

void ApiClient::importStudents(const QString& courseUuid, const QJsonArray& students) {
    QNetworkRequest req = buildRequest(
        QStringLiteral("/api/courses/%1/import-students").arg(courseUuid));
    req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    QNetworkReply* reply = nam_->post(req, QJsonDocument(students).toJson());
    QPointer<ApiClient> self(this);
    connect(reply, &QNetworkReply::finished, this, [this, self, reply]() {
        reply->deleteLater();
        if (!self) return;
        int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        QByteArray data = reply->readAll();
        QJsonObject body = QJsonDocument::fromJson(data).object();
        if (httpStatus == 200) {
            int total = body["total"].toInt();
            int created = body["created"].toInt();
            int skipped = body["skipped"].toInt();
            QStringList errors;
            if (body.contains("errors")) {
                for (const auto& e : body["errors"].toArray())
                    errors.append(e.toString());
            }
            emit studentsImported(total, created, skipped, errors);
        } else {
            emit studentsImportError(body["detail"].toString());
        }
    });
}

// ---------------------------------------------------------------------------
// File Upload — client-side compress (ffmpeg) then multipart POST
// ---------------------------------------------------------------------------

void ApiClient::uploadVideoFile(const QString& courseUuid,
                                const QString& title,
                                const QString& filePath,
                                bool addSubtitle) {
    QFileInfo fi(filePath);
    if (!fi.exists()) {
        emit videoUploadError(QStringLiteral("文件不存在: %1").arg(filePath));
        return;
    }

    constexpr qint64 MAX_RAW = 500LL * 1024 * 1024; // 500 MB raw
    if (fi.size() > MAX_RAW) {
        emit videoUploadError(QStringLiteral("原始文件过大 (%1 MB)，最大 500 MB")
                                  .arg(fi.size() / 1024.0 / 1024.0, 0, 'f', 1));
        return;
    }

    // Helper lambda: do the actual multipart upload + video record creation
    auto doUpload = [this](QTemporaryFile* tmp, const QString& uploadPath,
                           const QString& courseUuid, const QString& title,
                           QPointer<ApiClient> self) {
        QFileInfo upFi(uploadPath);
        emit videoUploadProgress(QStringLiteral("uploading"), 0);

        QHttpMultiPart* multi = new QHttpMultiPart(QHttpMultiPart::FormDataType);

        QHttpPart uuidPart;
        uuidPart.setHeader(QNetworkRequest::ContentDispositionHeader,
                           QStringLiteral("form-data; name=\"course_uuid\""));
        uuidPart.setBody(courseUuid.toUtf8());
        multi->append(uuidPart);

        QHttpPart titlePart;
        titlePart.setHeader(QNetworkRequest::ContentDispositionHeader,
                            QStringLiteral("form-data; name=\"title\""));
        titlePart.setBody(title.toUtf8());
        multi->append(titlePart);

        QHttpPart filePart;
        filePart.setHeader(QNetworkRequest::ContentDispositionHeader,
                           QStringLiteral("form-data; name=\"file\"; filename=\"%1\"")
                               .arg(upFi.fileName()));
        QMimeDatabase mimeDb;
        const QString mimeType = mimeDb.mimeTypeForFile(uploadPath).name();
        filePart.setHeader(QNetworkRequest::ContentTypeHeader, mimeType);

        QFile* uploadFile = new QFile(uploadPath);
        if (!uploadFile->open(QIODevice::ReadOnly)) {
            delete multi;
            delete uploadFile;
            tmp->deleteLater();
            emit videoUploadError(QStringLiteral("无法读取文件"));
            return;
        }
        filePart.setBodyDevice(uploadFile);
        uploadFile->setParent(multi);
        multi->append(filePart);

        QNetworkRequest uploadReq(QUrl(server_url_ + "/api/files/upload/video"));
        uploadReq.setTransferTimeout(60000);
        if (!token_.isEmpty())
            uploadReq.setRawHeader("Authorization", ("Bearer " + token_).toUtf8());

        QNetworkReply* reply = nam_->post(uploadReq, multi);
        multi->setParent(reply);

        connect(reply, &QNetworkReply::uploadProgress, this,
                [this, self](qint64 sent, qint64 total) {
                    if (!self) return;
                    int pct = total > 0 ? static_cast<int>(sent * 100 / total) : -1;
                    emit videoUploadProgress(QStringLiteral("uploading"), pct);
                });

        connect(reply, &QNetworkReply::finished, this,
                [this, reply, tmp, courseUuid, title, self]() {
            if (!self) return;

            int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            QByteArray body = reply->isOpen() ? reply->readAll() : QByteArray();

            reply->deleteLater();
            tmp->deleteLater();

            if (status == 201) {
                QJsonObject uploadResult = QJsonDocument::fromJson(body).object();
                const QString savedPath = uploadResult["file_path"].toString();
                const int savedSize = uploadResult["file_size"].toInt();

                QJsonObject videoBody;
                videoBody["course_uuid"] = courseUuid;
                videoBody["title"] = title;
                videoBody["file_path"] = savedPath;
                videoBody["file_size"] = savedSize;

                QPointer<ApiClient> self2(self);
                postJson("/api/videos/", videoBody,
                          [this, self2](int vStatus, const QJsonObject& vObj) {
                    if (!self2) return;
                    if (vStatus == 201) {
                        QVariantMap result;
                        result["uuid"] = vObj["uuid"].toString();
                        result["title"] = vObj["title"].toString();
                        result["file_path"] = vObj["file_path"].toString();
                        result["file_size"] = vObj["file_size"].toInt();
                        result["status"] = vObj["status"].toString();
                        emit videoUploadProgress(QStringLiteral("done"), 100);
                        emit videoUploadFinished(result);
                    } else {
                        QString detail = vObj.value("detail").toString(
                            QStringLiteral("视频记录创建失败"));
                        emit videoUploadError(detail);
                    }
                });
            } else if (status == 413) {
                emit videoUploadError(
                    QStringLiteral("文件过大被服务器拒绝。请压缩后再上传（最大 500MB）。"));
            } else if (status == 0) {
                emit videoUploadError(
                    QStringLiteral("网络连接失败，请检查服务器是否可达"));
            } else {
                QString detail = body.isEmpty()
                    ? QStringLiteral("上传失败 (HTTP %1)").arg(status)
                    : QJsonDocument::fromJson(body).object()
                          .value("detail").toString(QStringLiteral("上传失败"));
                emit videoUploadError(detail);
            }
        });
    };

    // ---- Cache: avoid re-processing on upload retry ----
    // Key = hash of (absolute path + size + mod time)
    const QString cacheKey = QString::fromLatin1(
        QCryptographicHash::hash(
            (fi.absoluteFilePath() + QString::number(fi.size())
             + QString::number(fi.lastModified().toMSecsSinceEpoch()))
                .toUtf8(),
            QCryptographicHash::Md5).toHex());
    const QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation)
                             + QStringLiteral("/edu_cache");
    QDir().mkpath(cacheDir);
    const QString cacheSuffix = addSubtitle ? QStringLiteral("_sub.mp4") : QStringLiteral("_cmp.mp4");
    const QString cachePath = cacheDir + QStringLiteral("/") + cacheKey + cacheSuffix;

    // If cache hit, skip to upload directly
    if (QFileInfo::exists(cachePath) && QFileInfo(cachePath).size() > 0) {
        // Launch upload directly from cached file (no temp → persistent file)
        QTemporaryFile* tmp = new QTemporaryFile(this); // dummy, deleted after upload
        tmp->open(); tmp->close();
        QPointer<ApiClient> self(this);
        doUpload(tmp, cachePath, courseUuid, title, self);
        return;
    }

    // ---- Kick off ffmpeg compression in a temp file ----
    QTemporaryFile* tmp = new QTemporaryFile(this);
    tmp->setFileTemplate(QDir::tempPath() + QStringLiteral("/edu_compress_XXXXXX.mp4"));
    if (!tmp->open()) {
        emit videoUploadError(QStringLiteral("无法创建临时文件"));
        delete tmp;
        return;
    }
    const QString outPath = tmp->fileName();
    tmp->close();

    QProcess* proc = new QProcess(this);
    QPointer<ApiClient> self(this);

    // Shared state for ffmpeg progress tracking
    auto durationSecs = std::make_shared<double>(-1.0);

    // Read Duration from stderr (initial scan header)
    connect(proc, &QProcess::readyReadStandardError, this,
            [this, proc, durationSecs]() {
        QByteArray data = proc->readAllStandardError();
        if (*durationSecs < 0) {
            QString text = QString::fromUtf8(data);
            static QRegularExpression durRe(QStringLiteral(
                "Duration:\\s*(\\d+):(\\d+):(\\d+)\\.(\\d+)"));
            auto m = durRe.match(text);
            if (m.hasMatch()) {
                *durationSecs = m.captured(1).toDouble() * 3600 +
                                m.captured(2).toDouble() * 60 +
                                m.captured(3).toDouble() +
                                m.captured(4).toDouble() / 100.0;
            }
        }
    });

    // Parse ffmpeg stdout: -progress pipe:1 gives machine-readable key=value blocks
    connect(proc, &QProcess::readyReadStandardOutput, this,
            [this, proc, durationSecs]() {
        QByteArray data = proc->readAllStandardOutput();
        QString text = QString::fromUtf8(data);

        // out_time=HH:MM:SS.MICROSECONDS (e.g. out_time=00:02:30.123456)
        static QRegularExpression timeRe(QStringLiteral(
            "out_time=(\\d+):(\\d+):(\\d+)\\.(\\d+)"));
        auto it = timeRe.globalMatch(text);
        double lastTimeSecs = -1;
        while (it.hasNext()) {
            auto m = it.next();
            lastTimeSecs = m.captured(1).toDouble() * 3600 +
                           m.captured(2).toDouble() * 60 +
                           m.captured(3).toDouble() +
                           m.captured(4).toDouble() / 1000000.0;
        }
        if (lastTimeSecs >= 0 && *durationSecs > 0) {
            int pct = qBound(0, static_cast<int>(lastTimeSecs * 100 / *durationSecs), 99);
            emit videoUploadProgress(QStringLiteral("compressing"), pct);
        } else if (lastTimeSecs >= 0) {
            emit videoUploadProgress(QStringLiteral("compressing"), -1);
        }
    });

    connect(proc, &QProcess::finished, this,
            [this, tmp, outPath, proc, courseUuid, title, cachePath,
             self, addSubtitle, doUpload](int exitCode) {
        if (!self) return;
        proc->deleteLater();

        if (exitCode != 0) {
            tmp->deleteLater();
            emit videoUploadError(QStringLiteral("视频压缩失败 (exit %1)").arg(exitCode));
            return;
        }

        QFileInfo outFi(outPath);
        if (!outFi.exists() || outFi.size() == 0) {
            tmp->deleteLater();
            emit videoUploadError(QStringLiteral("压缩输出文件为空"));
            return;
        }

        if (!addSubtitle) {
            // Save to cache and upload
            QFile::copy(outPath, cachePath);
            doUpload(tmp, cachePath, courseUuid, title, self);
            return;
        }

        // ---- Smart subtitle via FunASR ----
        emit videoUploadProgress(QStringLiteral("subtitle"), 0);

        // Find Python + asr.py: try paths relative to executable, then source tree
        const QString appDir = QCoreApplication::applicationDirPath();
        QString python;
        QString asrScript;
        const char* funasrSource = FUNASR_SOURCE_DIR;

        // Candidate base directories (first match wins)
        const QString candidates[] = {
            appDir + QStringLiteral("/FunASR"),       // bundled alongside binary
            QString::fromLocal8Bit(funasrSource),      // source tree (dev)
        };

        for (const auto& dir : candidates) {
            const QString pyPath =
#ifdef __linux__
                dir + QStringLiteral("/venv/bin/python");
#elif _WIN32
                dir + QStringLiteral("/venv/Scripts/python.exe");
#else
                dir + QStringLiteral("/venv/bin/python");
#endif
            const QString scriptPath = dir + QStringLiteral("/asr.py");
            if (QFileInfo(pyPath).exists() && QFileInfo(scriptPath).exists()) {
                python = pyPath;
                asrScript = scriptPath;
                break;
            }
        }
        if (python.isEmpty()) {
            // Last resort: system python (must have funasr + ffmpeg-python installed)
#ifdef _WIN32
            python = QStringLiteral("python");
#else
            python = QStringLiteral("python3");
#endif
            // Try bundled script first, then source
            asrScript = appDir + QStringLiteral("/FunASR/asr.py");
            if (!QFileInfo(asrScript).exists())
                asrScript = QString::fromLocal8Bit(funasrSource) + QStringLiteral("/asr.py");
        }

        QTemporaryFile* subTmp = new QTemporaryFile(this);
        subTmp->setFileTemplate(QDir::tempPath() + QStringLiteral("/edu_subtitle_XXXXXX.mp4"));
        if (!subTmp->open()) {
            emit videoUploadError(QStringLiteral("无法创建字幕临时文件"));
            delete subTmp;
            tmp->deleteLater();
            return;
        }
        const QString subPath = subTmp->fileName();
        subTmp->close();

        QProcess* subProc = new QProcess(this);
        connect(subProc, &QProcess::readyReadStandardOutput, this,
                [this, subProc]() {
            QByteArray data = subProc->readAllStandardOutput();
            QString text = QString::fromUtf8(data);
            if (text.contains(QStringLiteral("STAGE:extract")))
                emit videoUploadProgress(QStringLiteral("subtitle"), 10);
            else if (text.contains(QStringLiteral("STAGE:asr")))
                emit videoUploadProgress(QStringLiteral("subtitle"), 40);
            else if (text.contains(QStringLiteral("STAGE:overlay")))
                emit videoUploadProgress(QStringLiteral("subtitle"), 70);
            else if (text.contains(QStringLiteral("STAGE:done")))
                emit videoUploadProgress(QStringLiteral("subtitle"), 95);
        });

        connect(subProc, &QProcess::finished, this,
                [this, subProc, subTmp, subPath, tmp, courseUuid, title,
                 cachePath, self, doUpload](int subExitCode) {
            if (!self) return;
            subProc->deleteLater();

            if (subExitCode != 0) {
                subTmp->deleteLater();
                tmp->deleteLater();
                emit videoUploadError(
                    QStringLiteral("字幕生成失败 (exit %1)").arg(subExitCode));
                return;
            }

            QFileInfo subFi(subPath);
            if (!subFi.exists() || subFi.size() == 0) {
                subTmp->deleteLater();
                tmp->deleteLater();
                emit videoUploadError(QStringLiteral("字幕输出文件为空"));
                return;
            }

            // Compressed-only temp is no longer needed; subTmp has the final video
            tmp->deleteLater();

            // Save subtitled video to cache so retry won't re-process ASR
            QFile::copy(subPath, cachePath);

            // Upload from cache (tmp=subTmp so doUpload cleans up subTmp)
            doUpload(subTmp, cachePath, courseUuid, title, self);
        });

        subProc->start(python, {asrScript, QStringLiteral("--progress"),
                                outPath, subPath});
    });

    // Start ffmpeg compression
    // -progress pipe:1 sends machine-readable progress (out_time=) to stdout
    // -nostats suppresses the default \r-overwritten progress on stderr
    QStringList args;
    args << "-y" << "-i" << filePath
         << "-vf" << "scale=1920:1080:force_original_aspect_ratio=decrease"
         << "-c:v" << "libx264" << "-crf" << "23"
         << "-maxrate" << "1M" << "-bufsize" << "2M"
         << "-c:a" << "aac" << "-b:a" << "128k"
         << "-movflags" << "+faststart"
         << "-progress" << "pipe:1" << "-nostats"
         << outPath;

    emit videoUploadProgress(QStringLiteral("compressing"), 0);
    proc->start("ffmpeg", args);
}

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

bool ApiClient::saveTextFile(const QString& filePath, const QString& content) {
    QFile f(filePath);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text))
        return false;
    f.write(content.toUtf8());
    f.close();
    return true;
}

QString ApiClient::homeDir() const {
    return QDir::homePath();
}

bool ApiClient::exportScoresToExcel(const QString& filePath,
                                     const QStringList& unitNames,
                                     const QVariantList& students) {
    lxw_workbook* workbook = workbook_new(filePath.toUtf8().constData());
    if (!workbook) return false;

    lxw_worksheet* sheet = workbook_add_worksheet(workbook, "成绩单");
    if (!sheet) { workbook_close(workbook); return false; }

    // Header format: bold + green bg + border
    lxw_format* hdr = workbook_add_format(workbook);
    format_set_bold(hdr);
    format_set_bg_color(hdr, LXW_COLOR_LIME);
    format_set_border(hdr, LXW_BORDER_THIN);

    // Number format: 1 decimal place
    lxw_format* numFmt = workbook_add_format(workbook);
    format_set_num_format(numFmt, "0.0");

    // Write header
    int col = 0;
    worksheet_write_string(sheet, 0, col++, "序号", hdr);
    worksheet_write_string(sheet, 0, col++, "学号", hdr);
    worksheet_write_string(sheet, 0, col++, "姓名", hdr);
    worksheet_write_string(sheet, 0, col++, "用户名", hdr);

    std::vector<int> unitCols;
    for (const QString& u : unitNames) {
        unitCols.push_back(col);
        worksheet_write_string(sheet, 0, col++, u.toUtf8().constData(), hdr);
    }
    int totalCol = col;
    worksheet_write_string(sheet, 0, col++, "加权总分", hdr);
    int rankCol = col;
    worksheet_write_string(sheet, 0, col++, "排名", hdr);
    int numCols = col;

    // Write data rows
    for (int r = 0; r < students.size(); r++) {
        QVariantMap s = students[r].toMap();
        int c = 0;
        worksheet_write_number(sheet, r + 1, c++, r + 1, nullptr);

        QString studentNo = s["student_no"].toString();
        worksheet_write_string(sheet, r + 1, c++,
            studentNo.isEmpty() ? "-" : studentNo.toUtf8().constData(), nullptr);

        QString realName = s["real_name"].toString();
        worksheet_write_string(sheet, r + 1, c++,
            realName.isEmpty() ? "-" : realName.toUtf8().constData(), nullptr);

        QString username = s["username"].toString();
        worksheet_write_string(sheet, r + 1, c++,
            username.isEmpty() ? "-" : username.toUtf8().constData(), nullptr);

        QVariantList entries = s["scoreEntries"].toList();
        for (int j = 0; j < entries.size() && c <= totalCol; j++) {
            QVariant val = entries[j].toMap()["value"];
            if (!val.isNull()) {
                bool ok;
                double v = val.toDouble(&ok);
                if (ok) worksheet_write_number(sheet, r + 1, c, v, numFmt);
            }
            c++;
        }
        while (c <= totalCol) c++;

        QVariant wt = s["weighted_total"];
        if (!wt.isNull())
            worksheet_write_number(sheet, r + 1, totalCol, wt.toDouble(), numFmt);
        c++;

        QVariant rk = s["rank"];
        if (!rk.isNull())
            worksheet_write_number(sheet, r + 1, rankCol, rk.toDouble(), nullptr);
    }

    // Column widths
    worksheet_set_column(sheet, 0, 0, 5, nullptr);
    worksheet_set_column(sheet, 1, 1, 14, nullptr);
    worksheet_set_column(sheet, 2, 2, 10, nullptr);
    worksheet_set_column(sheet, 3, 3, 14, nullptr);
    for (int uc : unitCols)
        worksheet_set_column(sheet, uc, uc, 9, nullptr);
    worksheet_set_column(sheet, totalCol, totalCol, 10, nullptr);
    worksheet_set_column(sheet, rankCol, rankCol, 6, nullptr);

    lxw_error err = workbook_close(workbook);
    return err == LXW_NO_ERROR;
}

void ApiClient::setServerUrl(const QString& url) {
    if (server_url_ != url) {
        server_url_ = url;
        if (server_url_.endsWith('/'))
            server_url_.chop(1);
        emit serverUrlChanged();
    }
}

// ---------------------------------------------------------------------------
// Credential Persistence (encrypted auto-login)
// ---------------------------------------------------------------------------

static const char* CRED_FILE = "/auth.cred";
static const int CRED_VERSION = 1;
static const char* CRED_SALT = "EduStat_Cred_V1_Salt_2026";

QByteArray ApiClient::deriveEncryptionKey() {
    QByteArray machineId = QSysInfo::machineUniqueId().toHex();
    if (machineId.isEmpty()) {
        machineId = QByteArrayLiteral("edu_stat_v2_fallback_id");
    }
    QByteArray material = machineId
        + QByteArrayLiteral("::")
        + QCoreApplication::organizationName().toUtf8()
        + QByteArrayLiteral("::")
        + QCoreApplication::applicationName().toUtf8()
        + QByteArrayLiteral("::")
        + QByteArrayLiteral("EduStat_Cred_V1_Salt_2026");

    return QCryptographicHash::hash(material, QCryptographicHash::Sha256);
}

QByteArray ApiClient::encryptXor(const QByteArray& plaintext, const QByteArray& key) {
    QByteArray ciphertext;
    ciphertext.resize(plaintext.size());
    for (int i = 0; i < plaintext.size(); ++i) {
        ciphertext[i] = plaintext[i] ^ key[i % key.size()];
    }
    return ciphertext;
}

QByteArray ApiClient::decryptXor(const QByteArray& ciphertext, const QByteArray& key) {
    return encryptXor(ciphertext, key);  // XOR is symmetric
}

QString ApiClient::credentialFilePath() const {
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
           + QString::fromLatin1(CRED_FILE);
}

void ApiClient::setRememberMe(bool remember) {
    remember_me_ = remember;
}

bool ApiClient::hasSavedCredentials() const {
    return QFile::exists(credentialFilePath());
}

QString ApiClient::getSavedUsername() const {
    QFile file(credentialFilePath());
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    QJsonObject cred = QJsonDocument::fromJson(file.readAll()).object();
    file.close();
    return cred["username"].toString();
}

void ApiClient::saveCredentials(const QString& username, const QString& password) {
    QByteArray key = deriveEncryptionKey();
    QByteArray encrypted = encryptXor(password.toUtf8(), key);

    QJsonObject cred;
    cred["version"] = CRED_VERSION;
    cred["server_url"] = server_url_;
    cred["username"] = username;
    cred["encrypted_password"] = QString::fromUtf8(encrypted.toBase64());

    QDir().mkpath(QFileInfo(credentialFilePath()).absolutePath());

    QFile file(credentialFilePath());
    if (file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        file.write(QJsonDocument(cred).toJson());
        file.close();
        file.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    }
}

void ApiClient::clearSavedCredentials() {
    QFile::remove(credentialFilePath());
}

void ApiClient::tryAutoLogin() {
    QFile file(credentialFilePath());
    if (!file.exists()) {
        emit autoLoginSkipped("no_saved_credentials");
        return;
    }
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        emit autoLoginSkipped("file_read_error");
        return;
    }

    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    file.close();

    if (doc.isNull() || !doc.isObject()) {
        clearSavedCredentials();
        emit autoLoginSkipped("parse_error");
        return;
    }

    QJsonObject cred = doc.object();

    if (cred["version"].toInt() != CRED_VERSION) {
        emit autoLoginSkipped("version_mismatch");
        return;
    }

    QString savedUrl = cred["server_url"].toString();
    if (savedUrl != server_url_) {
        emit autoLoginSkipped("server_url_changed");
        return;
    }

    QString username = cred["username"].toString();
    QString encryptedB64 = cred["encrypted_password"].toString();
    if (username.isEmpty() || encryptedB64.isEmpty()) {
        emit autoLoginSkipped("invalid_credentials");
        return;
    }

    QByteArray key = deriveEncryptionKey();
    QByteArray decrypted = decryptXor(QByteArray::fromBase64(encryptedB64.toUtf8()), key);

    if (decrypted.isEmpty()) {
        emit autoLoginSkipped("decrypt_failed");
        return;
    }

    QString password = QString::fromUtf8(decrypted);

    // Proceed with normal login flow (no remember_me since already saved)
    login(username, password);
}
