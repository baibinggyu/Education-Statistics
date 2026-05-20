#include "chat_backend.h"

#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QFutureWatcher>
#include <QStandardPaths>
#include <QUuid>
#include <QtConcurrent/QtConcurrentRun>

#include <algorithm>
#include <boost/json.hpp>
#include <fstream>

namespace json = boost::json;

static constexpr const char* ASSISTANT_SYSTEM_PROMPT =
    "你是 EduStat 教学统计系统内置的 AI 助手。"
    "请使用中文回答，支持 Markdown 排版，但不要使用 LaTeX 公式语法。"
    "涉及数学内容时，用普通文本、列表或代码块表达，不要输出 $...$、$$...$$、\\(...\\) 或 \\[...\\]。";

ChatBackend::ChatBackend(QObject* parent)
    : QObject(parent)
    , client_(Config::from_default_locations())
    , model_name_(QString::fromStdString(client_.model()))
{
    savePath_ = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
                + "/chat_history.json";
    loadStore();
}

// ---- save / load ----

static json::array messagesToJson(const std::vector<Message>& messages) {
    json::array arr;
    for (const auto& m : messages) {
        arr.push_back({{"role", m.role}, {"content", m.content}});
    }
    return arr;
}

static std::vector<Message> messagesFromJson(const json::array& arr) {
    std::vector<Message> messages;
    for (const auto& item : arr) {
        if (!item.is_object()) continue;
        const auto& obj = item.as_object();
        auto r_it = obj.find("role");
        auto c_it = obj.find("content");
        if (r_it == obj.end() || c_it == obj.end()) continue;
        if (!r_it->value().is_string() || !c_it->value().is_string()) continue;
        messages.push_back({
            json::value_to<std::string>(r_it->value()),
            json::value_to<std::string>(c_it->value())
        });
    }
    return messages;
}

static QString nowIso() {
    return QDateTime::currentDateTime().toString(Qt::ISODate);
}

void ChatBackend::saveStore() {
    json::array sessions;
    for (const auto& s : sessions_) {
        sessions.push_back({
            {"id", s.id.toStdString()},
            {"title", s.title.toStdString()},
            {"updated_at", s.updatedAt.toStdString()},
            {"messages", messagesToJson(s.messages)}
        });
    }

    json::object root;
    root["active_id"] = current_session_id_.toStdString();
    root["sessions"] = sessions;

    QDir().mkpath(QFileInfo(savePath_).absolutePath());
    std::ofstream ofs(savePath_.toStdString());
    if (ofs) {
        ofs << json::serialize(root);
    }
}

void ChatBackend::loadStore() {
    std::ifstream ifs(savePath_.toStdString());
    if (!ifs) return;

    std::string content((std::istreambuf_iterator<char>(ifs)),
                         std::istreambuf_iterator<char>());
    if (content.empty()) return;

    boost::system::error_code ec;
    json::value jv = json::parse(content, ec);
    if (ec) return;

    if (jv.is_array()) {
        ChatSession migrated;
        migrated.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
        migrated.title = "历史对话";
        migrated.updatedAt = nowIso();
        migrated.messages = messagesFromJson(jv.as_array());
        if (!migrated.messages.empty()) {
            sessions_.push_back(migrated);
            current_session_id_ = migrated.id;
            history_ = migrated.messages;
            saveStore();
        }
        return;
    }

    if (!jv.is_object()) return;
    const auto& root = jv.as_object();
    auto active_it = root.find("active_id");
    if (active_it != root.end() && active_it->value().is_string()) {
        current_session_id_ = QString::fromStdString(
            json::value_to<std::string>(active_it->value()));
    }

    auto sessions_it = root.find("sessions");
    if (sessions_it == root.end() || !sessions_it->value().is_array()) return;

    for (const auto& item : sessions_it->value().as_array()) {
        if (!item.is_object()) continue;
        const auto& obj = item.as_object();
        auto id_it = obj.find("id");
        auto title_it = obj.find("title");
        auto updated_it = obj.find("updated_at");
        auto messages_it = obj.find("messages");
        if (id_it == obj.end() || title_it == obj.end() ||
            updated_it == obj.end() || messages_it == obj.end()) {
            continue;
        }
        if (!id_it->value().is_string() || !title_it->value().is_string() ||
            !updated_it->value().is_string() || !messages_it->value().is_array()) {
            continue;
        }

        ChatSession session;
        session.id = QString::fromStdString(json::value_to<std::string>(id_it->value()));
        session.title = QString::fromStdString(json::value_to<std::string>(title_it->value()));
        session.updatedAt = QString::fromStdString(json::value_to<std::string>(updated_it->value()));
        session.messages = messagesFromJson(messages_it->value().as_array());
        sessions_.push_back(session);
    }

    if (ChatSession* active = currentSession()) {
        history_ = active->messages;
    } else {
        current_session_id_.clear();
        history_.clear();
    }
}

ChatBackend::ChatSession* ChatBackend::findSession(const QString& id) {
    auto it = std::find_if(sessions_.begin(), sessions_.end(),
        [&](const ChatSession& s) { return s.id == id; });
    return it == sessions_.end() ? nullptr : &(*it);
}

ChatBackend::ChatSession* ChatBackend::currentSession() {
    return findSession(current_session_id_);
}

QString ChatBackend::makeTitle(const QString& text) const {
    QString title = text.simplified();
    if (title.isEmpty()) return "新对话";
    if (title.size() > 24) title = title.left(24) + "...";
    return title;
}

void ChatBackend::ensureCurrentSession(const QString& firstMessage) {
    if (currentSession()) return;

    ChatSession session;
    session.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    session.title = makeTitle(firstMessage);
    session.updatedAt = nowIso();
    sessions_.insert(sessions_.begin(), session);
    current_session_id_ = session.id;
}

void ChatBackend::updateCurrentSession() {
    ChatSession* session = currentSession();
    if (!session) return;
    session->messages = history_;
    session->updatedAt = nowIso();
}

void ChatBackend::emitCurrentHistory() {
    emit conversationReset();
    for (const auto& m : history_) {
        emit historyLoaded(QString::fromStdString(m.role),
                           QString::fromStdString(m.content));
    }
}

// ---- send / clear / compress ----

void ChatBackend::setLoading(bool v) {
    if (loading_ != v) {
        loading_ = v;
        emit chatStateChanged();
    }
}

void ChatBackend::sendMessage(const QString& text) {
    if (text.trimmed().isEmpty() || loading_) return;

    if (!client_.hasApiKey()) {
        emit errorOccurred(
            "未读取到 DeepSeek API Key。请确认 ~/.bashrc 中存在 "
            "export ANTHROPIC_AUTH_TOKEN=sk-...，并重新启动 EduStat_qml。");
        return;
    }

    ensureCurrentSession(text);
    emit sessionSelected(current_session_id_);
    setLoading(true);
    history_.push_back({"user", text.toStdString()});
    updateCurrentSession();
    saveStore();
    refreshSessions();
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
                    updateCurrentSession();
                    saveStore();
                    refreshSessions();
                    emit errorOccurred(QString::fromStdString(
                        std::string("网络异常: ") + e.what()));
                    emit chatStateChanged();
                    watcher->deleteLater();
                    return;
                } catch (...) {
                    history_.pop_back();
                    updateCurrentSession();
                    saveStore();
                    refreshSessions();
                    emit errorOccurred("未知异常");
                    emit chatStateChanged();
                    watcher->deleteLater();
                    return;
                }

                if (resp.ok) {
                    history_.push_back({"assistant", resp.content});
                    updateCurrentSession();
                    saveStore();
                    refreshSessions();
                    emit messageReceived("assistant",
                        QString::fromStdString(resp.content));
                } else {
                    history_.pop_back();
                    updateCurrentSession();
                    saveStore();
                    refreshSessions();
                    emit errorOccurred(QString::fromStdString(resp.error));
                }
                emit chatStateChanged();
                watcher->deleteLater();
            });

    auto msgs = history_;
    auto future = QtConcurrent::run([this, msgs]() -> ChatResponse {
        try {
            std::vector<Message> request_msgs;
            request_msgs.push_back({"system", ASSISTANT_SYSTEM_PROMPT});
            request_msgs.insert(request_msgs.end(), msgs.begin(), msgs.end());
            return client_.chat(request_msgs);
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
    updateCurrentSession();
    saveStore();
    refreshSessions();
    emit conversationReset();
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
                    updateCurrentSession();
                    saveStore();
                    refreshSessions();
                    emitCurrentHistory();
                    emit compressed(QString::fromStdString(resp.content));
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

void ChatBackend::newConversation() {
    current_session_id_.clear();
    history_.clear();
    saveStore();
    emit conversationReset();
    emit sessionSelected("");
    refreshSessions();
    emit chatStateChanged();
}

void ChatBackend::loadConversation(const QString& id) {
    ChatSession* session = findSession(id);
    if (!session || loading_) return;

    current_session_id_ = id;
    history_ = session->messages;
    saveStore();
    emit sessionSelected(id);
    emitCurrentHistory();
    refreshSessions();
    emit chatStateChanged();
}

void ChatBackend::deleteConversation(const QString& id) {
    if (loading_) return;

    auto it = std::remove_if(sessions_.begin(), sessions_.end(),
        [&](const ChatSession& s) { return s.id == id; });
    if (it == sessions_.end()) return;
    sessions_.erase(it, sessions_.end());

    if (current_session_id_ == id) {
        current_session_id_.clear();
        history_.clear();
        emit conversationReset();
        emit sessionSelected("");
    }

    saveStore();
    refreshSessions();
    emit chatStateChanged();
}

void ChatBackend::refreshSessions() {
    std::vector<ChatSession> sorted = sessions_;
    std::sort(sorted.begin(), sorted.end(), [](const ChatSession& a, const ChatSession& b) {
        return a.updatedAt > b.updatedAt;
    });

    emit sessionListReset();
    for (const auto& s : sorted) {
        QString preview;
        if (!s.messages.empty()) {
            preview = QString::fromStdString(s.messages.back().content).simplified();
            if (preview.size() > 42) preview = preview.left(42) + "...";
        }
        emit sessionListed(s.id, s.title, preview, s.updatedAt,
                           s.id == current_session_id_);
    }
}

void ChatBackend::restoreLastConversation() {
    if (ChatSession* session = currentSession()) {
        history_ = session->messages;
        emit sessionSelected(current_session_id_);
        emitCurrentHistory();
    } else {
        emit conversationReset();
        emit sessionSelected("");
    }
    refreshSessions();
    emit chatStateChanged();
}
