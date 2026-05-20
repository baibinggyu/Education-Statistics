#include "chat_client.hpp"

#include <boost/asio/connect.hpp>
#include <boost/asio/ip/tcp.hpp>
#include <boost/asio/ssl/stream.hpp>
#include <boost/beast/core.hpp>
#include <boost/beast/http.hpp>
#include <boost/beast/ssl.hpp>
#include <boost/beast/version.hpp>
#include <boost/json.hpp>
#include <sstream>
#include <string>

namespace beast = boost::beast;
namespace http  = beast::http;
namespace net   = boost::asio;
namespace ssl   = net::ssl;
namespace json  = boost::json;
using tcp = net::ip::tcp;

// ---------- 工具：解析 https://host:port/path ----------
static void parseUrl(const std::string& url,
                     std::string& host,
                     std::string& port,
                     std::string& target) {
    auto pos = url.find("://");
    std::string rest = (pos != std::string::npos) ? url.substr(pos + 3) : url;
    auto slash = rest.find('/');
    std::string hostport = (slash != std::string::npos)
                               ? rest.substr(0, slash)
                               : rest;
    target = (slash != std::string::npos) ? rest.substr(slash) : "/";

    auto colon = hostport.find(':');
    if (colon != std::string::npos) {
        host = hostport.substr(0, colon);
        port = hostport.substr(colon + 1);
    } else {
        host = hostport;
        port = "443";
    }
}

// ---------- ChatClient ----------
ChatClient::ChatClient(const Config& config)
    : config_(config), timeout_ms_(config.timeout_ms) {}

ChatResponse ChatClient::chat(const std::vector<Message>& messages) {
    ChatResponse resp;

    // 1. 解析 URL
    std::string host, port, target;
    parseUrl(config_.base_url, host, port, target);
    target += "/v1/messages";

    // 2. 构造 JSON 请求体
    json::array msgs;
    for (auto& m : messages) {
        msgs.push_back({{"role", m.role}, {"content", m.content}});
    }
    json::object body;
    body["model"]      = config_.model;
    body["max_tokens"] = 4096;
    body["messages"]   = msgs;
    body["stream"]     = false;
    std::string body_str = json::serialize(body);

    // 3. IO + SSL
    net::io_context ioc;
    ssl::context ssl_ctx(ssl::context::tlsv12_client);
    ssl_ctx.set_default_verify_paths();

    beast::tcp_stream stream(ioc);
    beast::ssl_stream<beast::tcp_stream&> ssl_stream(stream, ssl_ctx);

    // 连接超时
    if (timeout_ms_ > 0) {
        beast::get_lowest_layer(ssl_stream)
            .expires_after(std::chrono::milliseconds(timeout_ms_));
    }

    // SNI
    if (!SSL_set_tlsext_host_name(ssl_stream.native_handle(), host.c_str())) {
        resp.error = "SSL SNI 设置失败";
        return resp;
    }

    // DNS + TCP
    tcp::resolver resolver(ioc);
    auto results = resolver.resolve(host, port);
    beast::get_lowest_layer(ssl_stream).connect(results);
    ssl_stream.handshake(ssl::stream_base::client);

    // 4. 构造 HTTP 请求
    http::request<http::string_body> req{http::verb::post, target, 11};
    req.set(http::field::host, host);
    req.set(http::field::user_agent, BOOST_BEAST_VERSION_STRING);
    req.set(http::field::content_type, "application/json");
    req.set("x-api-key", config_.api_key);
    req.set("anthropic-version", "2023-06-01");
    req.body() = body_str;
    req.prepare_payload();

    // 读超时（重新设置，因为 connect 可能消耗了部分时间）
    if (timeout_ms_ > 0) {
        beast::get_lowest_layer(ssl_stream)
            .expires_after(std::chrono::milliseconds(timeout_ms_));
    }

    // 5. 发送
    http::write(ssl_stream, req);

    // 6. 接收
    beast::flat_buffer buffer;
    http::response<http::dynamic_body> http_resp;
    http::read(ssl_stream, buffer, http_resp);

    // 7. 关闭
    beast::error_code ec;
    beast::get_lowest_layer(ssl_stream).cancel();
    ssl_stream.shutdown(ec);

    // 8. 解析响应
    std::string resp_body = beast::buffers_to_string(http_resp.body().data());
    boost::system::error_code jec;
    json::value jv = json::parse(resp_body, jec);
    if (jec) {
        resp.error = "JSON 解析失败: " + jec.message();
        return resp;
    }
    if (!jv.is_object()) {
        resp.error = "响应不是 JSON 对象: " + resp_body;
        return resp;
    }
    auto obj = jv.as_object();

    // 辅助：安全提取字符串字段
    auto safe_str = [](const json::value& v) -> std::string {
        if (v.is_string()) return json::value_to<std::string>(v);
        if (v.is_int64()) return std::to_string(v.as_int64());
        if (v.is_double()) return std::to_string(v.as_double());
        if (v.is_bool()) return v.as_bool() ? "true" : "false";
        if (v.is_null()) return "";
        return json::serialize(v);
    };

    // HTTP 错误状态码（非 200）
    if (http_resp.result() != http::status::ok) {
        resp.ok = false;
        if (obj.find("error") != obj.end()) {
            try {
                auto err = obj["error"];
                if (err.is_object() && err.as_object().find("message") != err.as_object().end())
                    resp.error = safe_str(err.as_object().at("message"));
                else if (err.is_string())
                    resp.error = safe_str(err);
                else
                    resp.error = json::serialize(err);
            } catch (...) {
                resp.error = resp_body;
            }
        } else {
            resp.error = "HTTP " + std::to_string(http_resp.result_int()) + ": " + resp_body;
        }
        return resp;
    }

    // 提取 content[].text (Anthropic 格式，可能混有 thinking 块)
    try {
        auto it = obj.find("content");
        if (it != obj.end() && it->value().is_array()) {
            for (auto& item : it->value().as_array()) {
                if (!item.is_object()) continue;
                auto& fobj = item.as_object();
                auto type_it = fobj.find("type");
                if (type_it == fobj.end()) continue;
                if (type_it->value().is_string() &&
                    json::value_to<std::string>(type_it->value()) == "text") {
                    auto text_it = fobj.find("text");
                    if (text_it != fobj.end()) {
                        resp.content = safe_str(text_it->value());
                        break;
                    }
                }
            }
        }
    } catch (...) {}

    // 回退: OpenAI 兼容格式 (choices[0].message.content)
    if (resp.content.empty()) {
        try {
            auto choices_it = obj.find("choices");
            if (choices_it != obj.end() && choices_it->value().is_array()) {
                auto& choices = choices_it->value().as_array();
                if (!choices.empty()) {
                    auto& first = choices[0];
                    if (first.is_object()) {
                        auto msg_it = first.as_object().find("message");
                        if (msg_it != first.as_object().end() && msg_it->value().is_object()) {
                            auto content_it = msg_it->value().as_object().find("content");
                            if (content_it != msg_it->value().as_object().end())
                                resp.content = safe_str(content_it->value());
                        }
                    }
                }
            }
        } catch (...) {}
    }

    // 两个格式都失败 → 把原始响应当 error 返回，方便排查
    if (resp.content.empty()) {
        resp.ok = false;
        resp.error = "无法解析响应内容，原始响应: " + resp_body;
        return resp;
    }

    // stop_reason (可选)
    auto sr_it = obj.find("stop_reason");
    if (sr_it != obj.end())
        resp.stop_reason = safe_str(sr_it->value());

    // usage (可选)
    auto usage_it = obj.find("usage");
    if (usage_it != obj.end() && usage_it->value().is_object()) {
        try {
            auto& u = usage_it->value().as_object();
            resp.input_tokens  = static_cast<int>(json::value_to<int64_t>(u.at("input_tokens")));
            resp.output_tokens = static_cast<int>(json::value_to<int64_t>(u.at("output_tokens")));
        } catch (...) {
            // usage 字段格式异常，忽略
        }
    }
    resp.ok = true;

    return resp;
}

// ---------- 压缩 ----------
bool ChatClient::shouldCompress(const std::vector<Message>& history,
                                int last_input_tokens,
                                const CompressConfig& cc) const {
    int turns = static_cast<int>(history.size()) / 2;
    return turns > cc.max_turns || last_input_tokens > cc.max_tokens;
}

ChatResponse ChatClient::compress(std::vector<Message>& history,
                                  const CompressConfig& cc) {
    int turns = static_cast<int>(history.size()) / 2;
    if (turns <= cc.max_turns) {
        ChatResponse resp;
        resp.ok = true;
        return resp;  // 无需压缩
    }

    int rounds_to_compress = turns - cc.max_turns + 1;
    int msg_count = rounds_to_compress * 2;

    std::vector<Message> to_summarize(
        history.begin(),
        history.begin() + msg_count);

    std::ostringstream oss;
    oss << cc.summary_prompt << "\n\n";
    for (auto& m : to_summarize) {
        oss << "[" << m.role << "]: " << m.content << "\n";
    }

    std::vector<Message> summary_request;
    summary_request.push_back({"user", oss.str()});

    ChatResponse resp = chat(summary_request);
    if (!resp.ok) return resp;

    std::vector<Message> new_history;
    new_history.push_back({"system", "[历史摘要] " + resp.content});
    new_history.insert(new_history.end(),
                       history.begin() + msg_count,
                       history.end());
    history.swap(new_history);

    resp.content = "[压缩完成：保留最近 " +
                   std::to_string(cc.max_turns) + " 轮]";
    return resp;
}
