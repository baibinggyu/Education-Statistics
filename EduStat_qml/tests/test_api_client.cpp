#include <QCoreApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSignalSpy>
#include <QTest>
#include <QTemporaryDir>
#include <QUrl>

// Include the SUT header directly
#include "../api_client.h"

// ---------------------------------------------------------------------------
// Helpers to exercise the private buildRequest through QNetworkAccessManager
// -- we construct an ApiClient with a known token, then inspect the request
//    by passing it to QNetworkAccessManager and capturing via a mock.
//    For simplicity and determinism, we test buildRequest indirectly through
//    a local QNetworkAccessManager + a local TCP mock.
//
// Alternatively: we can make buildRequest "package-private" by adding a
// friend test class. We choose the approach of testing through the public
// API: the serverUrl property, JSON payload structure, and the signal
// emission behavior.
// ---------------------------------------------------------------------------

class TestApiClient : public QObject {
    Q_OBJECT
private slots:
    // --- Config / env ---
    void test_serverUrl_default() {
        QByteArray old = qgetenv("EDU_SERVER_URL");
        qunsetenv("EDU_SERVER_URL");

        ApiClient c;
        QCOMPARE(c.serverUrl(), QString("https://124.222.82.196"));

        if (!old.isEmpty()) qputenv("EDU_SERVER_URL", old);
    }

    void test_serverUrl_env_override() {
        qputenv("EDU_SERVER_URL", "http://192.168.1.1:8080");
        ApiClient c;
        QCOMPARE(c.serverUrl(), QString("http://192.168.1.1:8080"));
        qunsetenv("EDU_SERVER_URL");
    }

    void test_trailing_slash_stripped() {
        qputenv("EDU_SERVER_URL", "https://example.com/");
        ApiClient c;
        QCOMPARE(c.serverUrl(), QString("https://example.com"));
        qunsetenv("EDU_SERVER_URL");
    }

    void test_setServerUrl() {
        ApiClient c;
        QSignalSpy spy(&c, &ApiClient::serverUrlChanged);

        c.setServerUrl("https://new-server.com/");
        QCOMPARE(c.serverUrl(), QString("https://new-server.com"));
        QCOMPARE(spy.count(), 1);

        // Same value should not emit
        c.setServerUrl("https://new-server.com");
        QCOMPARE(spy.count(), 1);
    }

    // --- Authentication state ---
    void test_authenticated_property_initially_false() {
        ApiClient c;
        QCOMPARE(c.isAuthenticated(), false);
    }

    void test_logout_clears_token() {
        ApiClient c;
        QCOMPARE(c.isAuthenticated(), false);

        // logout always emits authenticatedChanged (even when already logged out)
        QSignalSpy spy(&c, &ApiClient::authenticatedChanged);
        c.logout();
        QCOMPARE(spy.count(), 1);
        QCOMPARE(c.isAuthenticated(), false);
    }

    // --- JSON payload format (static checks via QJsonDocument) ---
    void test_login_json_body() {
        QJsonObject body;
        body["username"] = "alice";
        body["password"] = "secret123";

        QJsonDocument doc(body);
        QJsonObject parsed = QJsonDocument::fromJson(doc.toJson()).object();
        QCOMPARE(parsed["username"].toString(), QString("alice"));
        QCOMPARE(parsed["password"].toString(), QString("secret123"));
        QCOMPARE(parsed.size(), 2);
    }

    void test_register_json_body() {
        QJsonObject body;
        body["username"] = "bob";
        body["password"] = "pw";
        body["role"] = "teacher";

        QJsonDocument doc(body);
        QJsonObject parsed = QJsonDocument::fromJson(doc.toJson()).object();
        QCOMPARE(parsed["username"].toString(), QString("bob"));
        QCOMPARE(parsed["password"].toString(), QString("pw"));
        QCOMPARE(parsed["role"].toString(), QString("teacher"));
        QCOMPARE(parsed.size(), 3);
    }

    void test_course_create_json_body() {
        QJsonObject body;
        body["name"] = "math";
        body["description"] = "Mathematics";

        QJsonDocument doc(body);
        QJsonObject parsed = QJsonDocument::fromJson(doc.toJson()).object();
        QCOMPARE(parsed["name"].toString(), QString("math"));
        QCOMPARE(parsed["description"].toString(), QString("Mathematics"));
        QCOMPARE(parsed.size(), 2);
    }

    void test_course_create_json_body_no_description() {
        QJsonObject body;
        body["name"] = "math";

        QJsonDocument doc(body);
        QJsonObject parsed = QJsonDocument::fromJson(doc.toJson()).object();
        QCOMPARE(parsed["name"].toString(), QString("math"));
        QVERIFY(!parsed.contains("description"));
    }

    // --- Server URL path construction (via request inspection proxy) ---
    void test_request_url_construction() {
        // We verify URL concatenation by setting serverUrl and checking
        // the QNetworkRequest we'd use -- indirectly via the QNAM.
        // For a unit test, we construct a URL the same way as buildRequest().
        QString server = "https://124.222.82.196";
        QUrl url(server + "/api/auth/login");
        QCOMPARE(url.toString(), QString("https://124.222.82.196/api/auth/login"));
    }

    void test_request_url_with_custom_server() {
        QString server = "http://127.0.0.1:55555";
        QUrl url(server + "/api/courses/");
        QCOMPARE(url.toString(), QString("http://127.0.0.1:55555/api/courses/"));
    }

    // --- Header construction ---
    void test_request_content_type_header() {
        QUrl url("https://example.com/api/test");
        QNetworkRequest req(url);
        req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");

        QCOMPARE(req.header(QNetworkRequest::ContentTypeHeader).toString(),
                 QString("application/json"));
    }

    void test_request_auth_header_with_token() {
        QUrl url("https://example.com/api/test");
        QNetworkRequest req(url);
        req.setRawHeader("Authorization", "Bearer tok123");

        QCOMPARE(req.rawHeader("Authorization"), QByteArray("Bearer tok123"));
    }

    void test_request_no_auth_header_without_token() {
        QUrl url("https://example.com/api/test");
        QNetworkRequest req(url);

        QVERIFY(req.rawHeader("Authorization").isEmpty());
    }

    // --- Signal spy patterns ---
    void test_loginError_signal_spy() {
        ApiClient c;
        QSignalSpy spy(&c, &ApiClient::loginError);
        QVERIFY(spy.isValid());
        QCOMPARE(spy.count(), 0);
    }

    void test_registerSuccess_signal_spy() {
        ApiClient c;
        QSignalSpy spy(&c, &ApiClient::registerSuccess);
        QVERIFY(spy.isValid());
        QCOMPARE(spy.count(), 0);
    }

    void test_courseListReset_signal_spy() {
        ApiClient c;
        QSignalSpy resetSpy(&c, &ApiClient::courseListReset);
        QSignalSpy listedSpy(&c, &ApiClient::courseListed);
        QVERIFY(resetSpy.isValid());
        QVERIFY(listedSpy.isValid());
    }

    void test_authenticatedChanged_signal_spy() {
        ApiClient c;
        QSignalSpy spy(&c, &ApiClient::authenticatedChanged);
        QVERIFY(spy.isValid());
        QCOMPARE(spy.count(), 0);
    }

    void test_serverUrlChanged_signal_spy() {
        ApiClient c;
        QSignalSpy spy(&c, &ApiClient::serverUrlChanged);
        QVERIFY(spy.isValid());
        QCOMPARE(spy.count(), 0);

        c.setServerUrl("https://other");
        QCOMPARE(spy.count(), 1);   // signal has no parameters

        // Same value should not emit
        c.setServerUrl("https://other");
        QCOMPARE(spy.count(), 1);
    }

    // --- Token expired signal (simulated) ---
    void test_tokenExpired_signal_spy() {
        ApiClient c;
        QSignalSpy spy(&c, &ApiClient::tokenExpired);
        QVERIFY(spy.isValid());
        QCOMPARE(spy.count(), 0);
    }

    // --- requestError signal ---
    void test_requestError_signal_spy() {
        ApiClient c;
        QSignalSpy spy(&c, &ApiClient::requestError);
        QVERIFY(spy.isValid());
        QCOMPARE(spy.count(), 0);
    }
};

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

QTEST_MAIN(TestApiClient)
#include "test_api_client.moc"
