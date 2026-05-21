#include "agent_backend.h"

#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QMetaObject>
#include <QPointer>
#include <QStandardPaths>
#include <QUuid>
#include <QtConcurrent/QtConcurrentRun>

#include <array>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <nlohmann/json.hpp>
#include <thread>

#include <QDebug>

using json = nlohmann::json;

// ---------------------------------------------------------------------------
// System prompt
// ---------------------------------------------------------------------------
static constexpr const char* ASSISTANT_SYSTEM_PROMPT =
    "你是 EduStat 教学统计系统内置的 AI 助手。"
    "请使用中文回答，支持 Markdown 排版，但不要使用 LaTeX 公式语法。"
    "涉及数学内容时，用普通文本、列表或代码块表达，不要输出 $...$、$$...$$、\\(...\\) 或 \\[...\\]";

// ---------------------------------------------------------------------------
// Constructor
// ---------------------------------------------------------------------------
AgentBackend::AgentBackend(QObject* parent)
    : QObject(parent)
{
    initLLM();

    savePath_ = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
                + "/chat_history.json";
    loadStore();
}

// ---------------------------------------------------------------------------
// LLM initialization
// ---------------------------------------------------------------------------
static QString envStr(const char* name, const QString& fallback = {}) {
    auto v = qgetenv(name);
    return v.isEmpty() ? fallback : QString::fromLocal8Bit(v);
}

void AgentBackend::initLLM() {
    // Detect provider from available API keys.
    // Priority: Anthropic > DeepSeek > OpenAI generic
    QString anthropic_key = envStr("ANTHROPIC_API_KEY");
    if (anthropic_key.isEmpty()) anthropic_key = envStr("ANTHROPIC_AUTH_TOKEN");

    QString deepseek_key = envStr("DEEPSEEK_API_KEY");
    QString openai_key = envStr("OPENAI_API_KEY");

    // Universal overrides (can be used with any provider)
    QString model_override = envStr("LLM_MODEL");
    QString base_override = envStr("LLM_BASE_URL");

    if (!anthropic_key.isEmpty()) {
        // --- Anthropic provider ---
        QString model = !model_override.isEmpty() ? model_override : envStr("ANTHROPIC_MODEL");
        if (model.isEmpty()) model = "claude-sonnet-4-6";

        QString base_url = !base_override.isEmpty() ? base_override : envStr("ANTHROPIC_BASE_URL");
        // ai::anthropic has its own default; only pass if explicitly set
        if (!base_url.isEmpty()) {
            // Anthropic client only has create_client(key) and create_client(key, url)
            // We need to check what overloads are available
            client_ = ai::anthropic::create_client(anthropic_key.toStdString(), base_url.toStdString());
        } else {
            client_ = ai::anthropic::create_client(anthropic_key.toStdString());
        }

        model_name_ = model;
        qDebug() << "[AgentBackend] Provider: Anthropic | Model:" << model
                 << "| Base URL:" << (base_url.isEmpty() ? "(default)" : base_url);

    } else if (!deepseek_key.isEmpty()) {
        // --- DeepSeek (OpenAI-compatible) provider ---
        QString model = !model_override.isEmpty() ? model_override : envStr("LLM_MODEL");
        if (model.isEmpty()) model = "deepseek-chat";

        QString base_url = !base_override.isEmpty() ? base_override : envStr("LLM_BASE_URL");
        if (base_url.isEmpty()) base_url = "https://api.deepseek.com";

        client_ = ai::openai::create_client(
            deepseek_key.toStdString(), base_url.toStdString());

        model_name_ = model;
        qDebug() << "[AgentBackend] Provider: DeepSeek (OpenAI) | Model:" << model
                 << "| Base URL:" << base_url;

    } else if (!openai_key.isEmpty()) {
        // --- Generic OpenAI provider ---
        QString model = !model_override.isEmpty() ? model_override : envStr("OPENAI_MODEL");
        if (model.isEmpty()) model = "gpt-4.1-mini";

        QString base_url = !base_override.isEmpty() ? base_override : envStr("OPENAI_BASE_URL");
        if (!base_url.isEmpty()) {
            client_ = ai::openai::create_client(
                openai_key.toStdString(), base_url.toStdString());
        } else {
            client_ = ai::openai::create_client(openai_key.toStdString());
        }

        model_name_ = model;
        qDebug() << "[AgentBackend] Provider: OpenAI | Model:" << model
                 << "| Base URL:" << (base_url.isEmpty() ? "(default)" : base_url);

    } else {
        qDebug() << "[AgentBackend] No API key found in environment";
    }
}

// ---------------------------------------------------------------------------
// Mode
// ---------------------------------------------------------------------------
void AgentBackend::setAgentMode(bool enabled) {
    if (agent_mode_ != enabled) {
        agent_mode_ = enabled;
        emit chatStateChanged();
    }
}

// ---------------------------------------------------------------------------
// sendMessage — dispatch to streaming chat or agent
// ---------------------------------------------------------------------------
void AgentBackend::sendMessage(const QString& text) {
    if (text.trimmed().isEmpty() || loading_) return;

    if (!client_.is_valid()) {
        emit errorOccurred("未读取到 API Key。请设置 DEEPSEEK_API_KEY 或 OPENAI_API_KEY 环境变量。");
        return;
    }

    ensureCurrentSession(text);
    emit sessionSelected(current_session_id_);

    // Add user message to history
    history_.push_back({QStringLiteral("user"), text});

    // Persist
    ChatSession* session = currentSession();
    if (session) {
        session->messages = history_;
        session->updatedAt = QDateTime::currentDateTime().toString(Qt::ISODate);
    }
    saveStore();

    qDebug() << "[AgentBackend] sendMessage, mode:" << (agent_mode_ ? "agent" : "simple")
             << ", model:" << model_name_
             << ", history size:" << history_.size();

    loading_ = true;
    should_stop_ = false;
    emit chatStateChanged();

    if (agent_mode_) {
        runAgent(text);
    } else {
        runStreamingChat(text);
    }
}

void AgentBackend::stopGeneration() {
    should_stop_ = true;
}

// ============================================================================
// Streaming chat (simple mode)
// ============================================================================
void AgentBackend::runStreamingChat(const QString& userText) {
    Q_UNUSED(userText);
    QPointer<AgentBackend> self(this);
    std::string model = model_name_.toStdString();

    // Build ai::Message list from stored history
    std::vector<ai::Message> aiMsgs;
    for (const auto& m : history_) {
        if (m.role == QLatin1String("user")) {
            aiMsgs.push_back(ai::Message::user(m.content.toStdString()));
        } else if (m.role == QLatin1String("assistant")) {
            aiMsgs.push_back(ai::Message::assistant(m.content.toStdString()));
        }
    }

    // Client pointer for worker thread
    ai::Client* clientPtr = &client_;

    QtConcurrent::run([self, aiMsgs = std::move(aiMsgs), model, clientPtr, this]() {
        ai::GenerateOptions genOpts(model, aiMsgs);
        genOpts.system = ASSISTANT_SYSTEM_PROMPT;
        genOpts.max_tokens = 4096;

        ai::StreamOptions streamOpts(std::move(genOpts));
        auto stream = clientPtr->stream_text(streamOpts);

        std::string fullResponse;
        bool hasError = false;
        std::string errorMsg;

        for (const auto& event : stream) {
            if (should_stop_) break;

            if (event.is_text_delta()) {
                fullResponse += event.text_delta;
                if (self) {
                    std::string chunk = event.text_delta;
                    QMetaObject::invokeMethod(self, [self, chunk]() {
                        if (self) {
                            self->streaming_ = true;
                            emit self->streamChunk(QString::fromStdString(chunk));
                            emit self->chatStateChanged();
                        }
                    }, Qt::QueuedConnection);
                }
            } else if (event.is_finish()) {
                break;
            } else if (event.is_error()) {
                hasError = true;
                errorMsg = event.error.value_or("Unknown error");
                break;
            }
        }

        if (hasError && self) {
            std::string err = errorMsg;
            QString fullErr = QStringLiteral("[model=%1] 网络异常: %2")
                .arg(QString::fromStdString(model), QString::fromStdString(err));
            QMetaObject::invokeMethod(self, [self, fullErr]() {
                if (self) {
                    emit self->errorOccurred(fullErr);
                }
            }, Qt::QueuedConnection);
        }

        // Finalize on main thread
        if (self) {
            std::string response = fullResponse;
            QMetaObject::invokeMethod(self, [self, response]() {
                if (!self) return;
                self->streaming_ = false;
                self->loading_ = false;

                if (!response.empty()) {
                    self->history_.push_back({QStringLiteral("assistant"),
                        QString::fromStdString(response)});
                    emit self->messageReceived("assistant",
                        QString::fromStdString(response));
                    emit self->streamFinished();

                    AgentBackend::ChatSession* s = self->currentSession();
                    if (s) {
                        s->messages = self->history_;
                        s->updatedAt = QDateTime::currentDateTime().toString(Qt::ISODate);
                    }
                    self->saveStore();
                }
                self->refreshSessions();
                emit self->chatStateChanged();
            }, Qt::QueuedConnection);
        }
    });
}

// ============================================================================
// Agent mode
// ============================================================================
void AgentBackend::runAgent(const QString& userText) {
    Q_UNUSED(userText);
    QPointer<AgentBackend> self(this);
    std::string model = model_name_.toStdString();

    // Build ai::Message list from stored history
    std::vector<ai::Message> aiMsgs;
    for (const auto& m : history_) {
        if (m.role == QLatin1String("user")) {
            aiMsgs.push_back(ai::Message::user(m.content.toStdString()));
        } else if (m.role == QLatin1String("assistant")) {
            aiMsgs.push_back(ai::Message::assistant(m.content.toStdString()));
        }
    }

    ai::Client* clientPtr = &client_;

    QtConcurrent::run([self, aiMsgs = std::move(aiMsgs), model, clientPtr, this]() {
        ai::ToolSet toolSet;

        // Calculator tool
        auto calcSchema = ai::create_object_schema({{"expression", "string"}});
        calcSchema["properties"]["expression"]["description"] = "数学表达式，如 '(3+5)*12'";
        toolSet["calculator"] = ai::create_tool(
            "计算数学表达式。支持 +, -, *, /, ^, 括号和基本数学函数。",
            calcSchema,
            [](const json& args, const ai::ToolExecutionContext& /*ctx*/) -> json {
                std::string expr = args.value("expression", "");
                // Safe evaluation
                auto evalExpr = [](const std::string& s) -> double {
                    // Simple recursive descent parser
                    auto skip = [](const std::string& str, size_t& i) {
                        while (i < str.size() && std::isspace(static_cast<unsigned char>(str[i]))) ++i;
                    };
                    std::function<double()> parseAtom, parseFactor, parseTerm;
                    size_t pos = 0;
                    const std::string* sp = &s;

                    parseAtom = [&]() -> double {
                        skip(*sp, pos);
                        if (pos >= sp->size()) throw std::runtime_error("Unexpected end");
                        if ((*sp)[pos] == '(') {
                            ++pos;
                            double v = parseTerm();
                            skip(*sp, pos);
                            if (pos >= sp->size() || (*sp)[pos] != ')')
                                throw std::runtime_error("Missing )");
                            ++pos;
                            return v;
                        }
                        if ((*sp)[pos] == '-') { ++pos; return -parseAtom(); }
                        if ((*sp)[pos] == '+') { ++pos; return parseAtom(); }
                        size_t start = pos;
                        bool dot = false;
                        while (pos < sp->size() &&
                               (std::isdigit(static_cast<unsigned char>((*sp)[pos])) || (*sp)[pos] == '.')) {
                            if ((*sp)[pos] == '.') {
                                if (dot) throw std::runtime_error("Multiple dots");
                                dot = true;
                            }
                            ++pos;
                        }
                        if (pos == start) throw std::runtime_error("Expected number");
                        return std::stod(sp->substr(start, pos - start));
                    };
                    parseFactor = [&]() -> double {
                        double v = parseAtom();
                        skip(*sp, pos);
                        while (pos < sp->size() && (*sp)[pos] == '^') {
                            ++pos;
                            v = std::pow(v, parseAtom());
                            skip(*sp, pos);
                        }
                        return v;
                    };
                    parseTerm = [&]() -> double {
                        double v = parseFactor();
                        skip(*sp, pos);
                        while (pos < sp->size()) {
                            char op = (*sp)[pos];
                            if (op != '+' && op != '-' && op != '*' && op != '/') break;
                            ++pos;
                            double rhs = parseFactor();
                            if (op == '+') v += rhs;
                            else if (op == '-') v -= rhs;
                            else if (op == '*') v *= rhs;
                            else {
                                if (rhs == 0.0) throw std::runtime_error("Division by zero");
                                v /= rhs;
                            }
                            skip(*sp, pos);
                        }
                        return v;
                    };
                    double result = parseTerm();
                    skip(s, pos);
                    if (pos != s.size()) throw std::runtime_error("Trailing characters");
                    return result;
                };
                try {
                    double result = evalExpr(expr);
                    return {{"result", result}, {"expression", expr}};
                } catch (const std::exception& e) {
                    return {{"error", e.what()}, {"expression", expr}};
                }
            }
        );

        // Datetime tool
        auto datetimeSchema = ai::create_object_schema({{"query", "string"}});
        datetimeSchema["properties"]["query"]["description"] = "查询类型: 'now', 'today', 'tomorrow', 'yesterday'";
        toolSet["datetime"] = ai::create_tool(
            "获取当前日期、时间或相对日期。",
            datetimeSchema,
            [](const json& args, const ai::ToolExecutionContext& /*ctx*/) -> json {
                std::string query = args.value("query", "now");
                auto now = QDateTime::currentDateTime();
                if (query == "tomorrow") now = now.addDays(1);
                else if (query == "yesterday") now = now.addDays(-1);
                return {
                    {"date", now.toString("yyyy-MM-dd").toStdString()},
                    {"time", now.toString("HH:mm:ss").toStdString()},
                    {"weekday", now.toString("dddd").toStdString()},
                    {"timestamp", now.toSecsSinceEpoch()}
                };
            }
        );

        // --- File system tools ---
        // Ensure workspace directory exists
        std::string workspace = (std::filesystem::temp_directory_path() / "edu_agent_ws").string();
        std::error_code ec;
        std::filesystem::create_directories(workspace, ec);

        // read_file tool
        auto readSchema = ai::create_object_schema({{"path", "string"}});
        readSchema["properties"]["path"]["description"] =
            "文件路径（绝对路径或相对于工作目录 " + workspace + " 的路径）";
        toolSet["read_file"] = ai::create_tool(
            "读取文件内容。支持绝对路径和相对路径。最大读取 1MB。",
            readSchema,
            [workspace](const json& args, const ai::ToolExecutionContext& /*ctx*/) -> json {
                std::string path = args.value("path", "");
                if (path.empty()) return {{"error", "缺少 path 参数"}};

                std::filesystem::path file_path(path);
                // Resolve relative paths against workspace
                if (file_path.is_relative()) {
                    file_path = std::filesystem::path(workspace) / file_path;
                }
                file_path = std::filesystem::weakly_canonical(file_path);

                std::error_code ec2;
                if (!std::filesystem::exists(file_path, ec2)) {
                    return {{"error", "文件不存在: " + file_path.string()}};
                }
                if (!std::filesystem::is_regular_file(file_path, ec2)) {
                    return {{"error", "不是普通文件: " + file_path.string()}};
                }
                auto fsize = std::filesystem::file_size(file_path, ec2);
                if (ec2) return {{"error", "无法获取文件大小: " + ec2.message()}};
                constexpr size_t kMaxRead = 1024 * 1024; // 1 MB
                if (fsize > kMaxRead) {
                    return {{"error", "文件过大 (" + std::to_string(fsize) +
                        " bytes)，最大允许 " + std::to_string(kMaxRead) + " bytes"}};
                }

                std::ifstream ifs(file_path, std::ios::binary);
                if (!ifs) return {{"error", "无法打开文件: " + file_path.string()}};
                std::string content((std::istreambuf_iterator<char>(ifs)),
                                     std::istreambuf_iterator<char>());
                return {
                    {"path", file_path.string()},
                    {"size", fsize},
                    {"content", content}
                };
            }
        );

        // write_file tool
        auto writeSchema = ai::create_object_schema({
            {"path", "string"},
            {"content", "string"}
        });
        writeSchema["properties"]["path"]["description"] =
            "文件路径（绝对路径或相对于工作目录 " + workspace + " 的路径）";
        writeSchema["properties"]["content"]["description"] = "要写入的内容";
        toolSet["write_file"] = ai::create_tool(
            "写入内容到文件。如果文件已存在则覆盖。",
            writeSchema,
            [workspace](const json& args, const ai::ToolExecutionContext& /*ctx*/) -> json {
                std::string path = args.value("path", "");
                std::string content = args.value("content", "");
                if (path.empty()) return {{"error", "缺少 path 参数"}};

                std::filesystem::path file_path(path);
                if (file_path.is_relative()) {
                    file_path = std::filesystem::path(workspace) / file_path;
                }
                file_path = std::filesystem::weakly_canonical(file_path);

                // Create parent directories
                std::error_code ec2;
                std::filesystem::create_directories(file_path.parent_path(), ec2);

                std::ofstream ofs(file_path, std::ios::binary | std::ios::trunc);
                if (!ofs) return {{"error", "无法写入文件: " + file_path.string()}};
                ofs << content;
                ofs.close();

                auto fsize = std::filesystem::file_size(file_path, ec2);
                return {
                    {"path", file_path.string()},
                    {"written", content.size()},
                    {"file_size", ec2 ? json(nullptr) : json(fsize)}
                };
            }
        );

        // execute_command tool
        auto execSchema = ai::create_object_schema({
            {"command", "string"}
        });
        execSchema["properties"]["command"]["description"] =
            "要执行的 shell 命令（运行在工作目录 " + workspace + " 中，hard 超时 30 秒后自动杀死）";
        toolSet["execute_command"] = ai::create_tool(
            "执行 shell 命令并返回标准输出和标准错误。超时 30 秒（自动杀死），输出截断至 512KB。"
            "请勿执行危险或破坏性命令。",
            execSchema,
            [workspace](const json& args, const ai::ToolExecutionContext& /*ctx*/) -> json {
                std::string command = args.value("command", "");
                if (command.empty()) return {{"error", "缺少 command 参数"}};

                // timeout(1) enforces a 30s wall-clock limit; 2>&1 merges stderr
                std::string full_cmd = "cd " + workspace + " && timeout 30 " + command + " 2>&1";

                std::array<char, 4096> buffer{};
                std::string output;
                FILE* pipe = popen(full_cmd.c_str(), "r");
                if (!pipe) return {{"error", "无法执行命令: " + std::string(strerror(errno))}};

                while (fgets(buffer.data(), static_cast<int>(buffer.size()), pipe) != nullptr) {
                    output += buffer.data();
                    if (output.size() > 512 * 1024) {
                        output += "\n...[truncated at 512KB]";
                        break;
                    }
                }
                int status = pclose(pipe);
                int exit_code = WIFEXITED(status) ? WEXITSTATUS(status) : -1;

                // timeout(1) returns 124 when it kills the command
                if (exit_code == 124) {
                    output += "\n[命令执行超时，已被终止]";
                }

                return {
                    {"stdout", output},
                    {"exit_code", exit_code},
                    {"timed_out", exit_code == 124},
                    {"workspace", workspace}
                };
            }
        );

        ai::GenerateOptions opts(model, aiMsgs);
        opts.system =
            "你是 EduStat 教学统计系统内置的智能 Agent，基于 DeepSeek 模型，"
            "通过 ReAct（思考 → 行动 → 观察）循环自主完成任务。\n"
            "\n"
            "## 项目背景\n"
            "EduStat 是一个 Qt6/C++ 桌面教育平台，包含班级管理、点名、组队、"
            "学生信息、学科管理、视频播放、课程资源、公告、倒计时等功能模块。"
            "服务端为 FastAPI + MariaDB，提供 JWT 鉴权的 REST API。"
            "你运行在 C++ 后端的 Agent 线程中，通过工具与系统交互。\n"
            "\n"
            "## 工作目录\n"
            "- 文件操作的工作空间：/tmp/edu_agent_ws\n"
            "- 用户主目录（~ / $HOME）：/home/bai-yu\n"
            "- 项目根目录：/home/bai-yu/codeProject/edu/EduStat_qml\n"
            "- write_file / read_file 的相对路径会解析到工作空间\n"
            "- execute_command 会自动 cd 到工作空间再执行命令\n"
            "- 用户说\"~\"或\"我的目录\"时，指的是 /home/bai-yu\n"
            "\n"
            "## 工具使用指南\n"
            "- calculator：安全计算数学表达式，支持 +-*/^ 和括号\n"
            "- datetime：获取当前日期时间，支持 now/today/tomorrow/yesterday\n"
            "- read_file：读取文件内容（最大 1MB），支持绝对路径或相对工作空间的路径\n"
            "- write_file：写入文件，自动创建父目录，覆盖已有文件\n"
            "- execute_command：执行 shell 命令，30 秒硬超时自动杀死进程。\n"
            "  适合：cat、ls、grep、python3、node 等短命令。\n"
            "  不适合：需要 GUI 的命令（xdg-open、浏览器）或长时间服务（http.server）\n"
            "\n"
            "## 行为准则\n"
            "1. 每次行动前先思考：分析用户意图 → 选择最合适的工具 → 解读结果 → 给用户清晰回复\n"
            "2. 写文件后，用 execute_command 执行 'cat 文件名' 或 'ls -la' 验证\n"
            "3. 用户要求\"运行\"或\"打开\" HTML/网页时，用 execute_command 启动 Python HTTP 服务器，"
            "告诉用户用浏览器访问 http://localhost:端口\n"
            "4. 使用中文回答，支持 Markdown 排版\n"
            "5. 数学内容用普通文本、列表或代码块表达，不要用 LaTeX $...$ 语法\n"
            "6. 路径相关：绝对路径用完整路径，相对路径会解析到 /tmp/edu_agent_ws";
        opts.max_steps = 10;
        opts.max_tokens = 8192;
        opts.tools = std::move(toolSet);
        opts.tool_choice = ai::ToolChoice::auto_choice();

        // Step callback — respects should_stop_
        int step_num = 0;  // captured by reference, increments per step
        opts.on_step_finish = [self, this, &step_num](const ai::GenerateStep& step) {
            if (!self || should_stop_) return;
            step_num++;
            json stepJson;
            stepJson["step"] = step_num;
            stepJson["max_steps"] = 10;
            json toolCallsArr = json::array();
            for (const auto& tc : step.tool_calls) {
                toolCallsArr.push_back({
                    {"tool_name", tc.tool_name},
                    {"arguments", tc.arguments}
                });
            }
            stepJson["tool_calls"] = toolCallsArr;
            json toolResultsArr = json::array();
            for (const auto& tr : step.tool_results) {
                toolResultsArr.push_back({
                    {"tool_name", tr.tool_name},
                    {"result", tr.result},
                    {"error", tr.error_message()}
                });
            }
            stepJson["tool_results"] = toolResultsArr;

            std::string desc;
            if (!step.text.empty()) {
                auto preview = step.text.size() > 70 ? step.text.substr(0, 70) + "..." : step.text;
                desc = "Step " + std::to_string(step_num) + "/10: " + preview;
            } else if (!step.tool_calls.empty()) {
                desc = "Step " + std::to_string(step_num) + "/10: 调用工具...";
            } else {
                desc = "Step " + std::to_string(step_num) + "/10: 思考中...";
            }
            std::string status = step.tool_calls.empty() ? "思考" : "执行工具";
            // Prepend step info to result JSON
            stepJson["text"] = step.text;
            bool ok = std::all_of(step.tool_results.begin(), step.tool_results.end(),
                                  [](const auto& r) { return r.is_success(); });
            std::string resultJson = step.tool_calls.empty() ? "" : stepJson.dump(2);

            QMetaObject::invokeMethod(self, [self, desc, status, ok, resultJson]() {
                if (self) {
                    emit self->stepUpdated(
                        QString::fromStdString(desc),
                        QString::fromStdString(status),
                        ok,
                        QString::fromStdString(resultJson));
                }
            }, Qt::QueuedConnection);
        };

        auto result = clientPtr->generate_text(opts);

        // Discard result if user pressed stop
        if (should_stop_) {
            if (self) {
                QMetaObject::invokeMethod(self, [self]() {
                    if (!self) return;
                    self->loading_ = false;
                    self->streaming_ = false;
                    emit self->chatStateChanged();
                }, Qt::QueuedConnection);
            }
            return;
        }

        if (self) {
            if (result) {
                std::string answer = result.text;
                QMetaObject::invokeMethod(self, [self, answer]() {
                    if (!self) return;
                    self->history_.push_back({QStringLiteral("assistant"),
                        QString::fromStdString(answer)});
                    emit self->messageReceived("assistant",
                        QString::fromStdString(answer));

                    AgentBackend::ChatSession* s = self->currentSession();
                    if (s) {
                        s->messages = self->history_;
                        s->updatedAt = QDateTime::currentDateTime().toString(Qt::ISODate);
                    }
                    self->saveStore();
                }, Qt::QueuedConnection);
            } else {
                std::string err = result.error_message();
                QMetaObject::invokeMethod(self, [self, err]() {
                    if (self) {
                        emit self->errorOccurred(
                            QString::fromStdString("Agent 执行异常: " + err));
                    }
                }, Qt::QueuedConnection);
            }
        }

        // Finalize
        if (self) {
            QMetaObject::invokeMethod(self, [self]() {
                if (!self) return;
                self->loading_ = false;
                self->streaming_ = false;
                self->saveStore();
                self->refreshSessions();
                emit self->chatStateChanged();
            }, Qt::QueuedConnection);
        }
    });
}

// ============================================================================
// Session helpers
// ============================================================================
AgentBackend::ChatSession* AgentBackend::findSession(const QString& id) {
    auto it = std::find_if(sessions_.begin(), sessions_.end(),
        [&](const ChatSession& s) { return s.id == id; });
    return it == sessions_.end() ? nullptr : &(*it);
}

AgentBackend::ChatSession* AgentBackend::currentSession() {
    return findSession(current_session_id_);
}

QString AgentBackend::makeTitle(const QString& text) const {
    QString title = text.simplified();
    if (title.isEmpty()) return QStringLiteral("新对话");
    if (title.size() > 24) title = title.left(24) + "...";
    return title;
}

void AgentBackend::ensureCurrentSession(const QString& firstMessage) {
    if (currentSession()) return;
    ChatSession session;
    session.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    session.title = makeTitle(firstMessage);
    session.updatedAt = QDateTime::currentDateTime().toString(Qt::ISODate);
    sessions_.insert(sessions_.begin(), session);
    current_session_id_ = session.id;
}

void AgentBackend::updateCurrentSession() {
    ChatSession* session = currentSession();
    if (!session) return;
    session->messages = history_;
    session->updatedAt = QDateTime::currentDateTime().toString(Qt::ISODate);
}

void AgentBackend::emitCurrentHistory() {
    emit conversationReset();
    for (const auto& m : history_) {
        emit historyLoaded(m.role, m.content);
    }
}

// ============================================================================
// Session save/load
// ============================================================================
void AgentBackend::saveStore() {
    json root;
    root["active_id"] = current_session_id_.toStdString();
    json sessionsArr = json::array();

    for (const auto& s : sessions_) {
        json sessionObj;
        sessionObj["id"] = s.id.toStdString();
        sessionObj["title"] = s.title.toStdString();
        sessionObj["updated_at"] = s.updatedAt.toStdString();
        json messagesArr = json::array();
        for (const auto& m : s.messages) {
            messagesArr.push_back({
                {"role", m.role.toStdString()},
                {"content", m.content.toStdString()}
            });
        }
        sessionObj["messages"] = messagesArr;
        sessionsArr.push_back(sessionObj);
    }
    root["sessions"] = sessionsArr;

    QDir().mkpath(QFileInfo(savePath_).absolutePath());
    std::ofstream ofs(savePath_.toStdString());
    if (ofs) {
        ofs << root.dump(2);
    }
}

void AgentBackend::loadStore() {
    std::ifstream ifs(savePath_.toStdString());
    if (!ifs) return;

    json root;
    try {
        root = json::parse(ifs);
    } catch (...) {
        return;
    }

    if (!root.is_object()) return;

    auto activeIt = root.find("active_id");
    if (activeIt != root.end() && activeIt->is_string()) {
        current_session_id_ = QString::fromStdString(activeIt->get<std::string>());
    }

    auto sessionsIt = root.find("sessions");
    if (sessionsIt == root.end() || !sessionsIt->is_array()) return;

    for (const auto& item : *sessionsIt) {
        if (!item.is_object()) continue;
        ChatSession session;
        session.id = QString::fromStdString(item.value("id", ""));
        session.title = QString::fromStdString(item.value("title", "未命名"));
        session.updatedAt = QString::fromStdString(item.value("updated_at", ""));

        auto messagesIt = item.find("messages");
        if (messagesIt != item.end() && messagesIt->is_array()) {
            for (const auto& m : *messagesIt) {
                if (!m.is_object()) continue;
                std::string role = m.value("role", "");
                std::string content = m.value("content", "");
                session.messages.push_back({
                    QString::fromStdString(role),
                    QString::fromStdString(content)
                });
            }
        }
        sessions_.push_back(session);
    }

    // Load current session messages into history
    if (ChatSession* active = currentSession()) {
        history_ = active->messages;
    } else {
        current_session_id_.clear();
    }
}

// ============================================================================
// Session management slots
// ============================================================================
void AgentBackend::newConversation() {
    current_session_id_.clear();
    history_.clear();
    saveStore();
    emit conversationReset();
    emit sessionSelected("");
    refreshSessions();
    emit chatStateChanged();
}

void AgentBackend::clearHistory() {
    history_.clear();
    updateCurrentSession();
    saveStore();
    refreshSessions();
    emit conversationReset();
    emit chatStateChanged();
}

void AgentBackend::loadConversation(const QString& id) {
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

void AgentBackend::deleteConversation(const QString& id) {
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

void AgentBackend::refreshSessions() {
    std::vector<ChatSession> sorted = sessions_;
    std::sort(sorted.begin(), sorted.end(),
        [](const ChatSession& a, const ChatSession& b) {
            return a.updatedAt > b.updatedAt;
        });

    emit sessionListReset();
    for (const auto& s : sorted) {
        QString preview;
        if (!s.messages.empty()) {
            preview = s.messages.back().content.simplified();
            if (preview.size() > 42) preview = preview.left(42) + "...";
        }
        emit sessionListed(s.id, s.title, preview, s.updatedAt,
                           s.id == current_session_id_);
    }
}

void AgentBackend::restoreLastConversation() {
    history_.clear();
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

// ---------------------------------------------------------------------------
// Conversion helpers (not currently used externally, kept for reference)
// ---------------------------------------------------------------------------
std::vector<ai::Message> AgentBackend::storedToAi(
    const std::vector<ChatSession::StoredMessage>& stored) const
{
    std::vector<ai::Message> result;
    for (const auto& m : stored) {
        if (m.role == QLatin1String("user")) {
            result.push_back(ai::Message::user(m.content.toStdString()));
        } else if (m.role == QLatin1String("assistant")) {
            result.push_back(ai::Message::assistant(m.content.toStdString()));
        }
    }
    return result;
}

std::vector<AgentBackend::ChatSession::StoredMessage> AgentBackend::aiToStored(
    const std::vector<ai::Message>& aiMsgs) const
{
    std::vector<ChatSession::StoredMessage> result;
    for (const auto& m : aiMsgs) {
        QString role;
        switch (m.role) {
            case ai::kMessageRoleUser: role = QStringLiteral("user"); break;
            case ai::kMessageRoleAssistant: role = QStringLiteral("assistant"); break;
            default: continue;
        }
        result.push_back({role, QString::fromStdString(m.get_text())});
    }
    return result;
}
