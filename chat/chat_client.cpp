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
    auto obj = jv.as_object();

    // API 错误
    if (obj.find("error") != obj.end()) {
        auto err = obj["error"].as_object();
        resp.error = json::value_to<std::string>(err["message"]);
        resp.ok = false;
        return resp;
    }

    // 提取 content[0].text
    auto content_arr = obj["content"].as_array();
    if (!content_arr.empty()) {
        resp.content = json::value_to<std::string>(
            content_arr[0].as_object()["text"]);
    }
    resp.stop_reason   = json::value_to<std::string>(obj.at("stop_reason"));
    resp.input_tokens  = static_cast<int>(obj["usage"].as_object()["input_tokens"].as_int64());
    resp.output_tokens = static_cast<int>(obj["usage"].as_object()["output_tokens"].as_int64());
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
