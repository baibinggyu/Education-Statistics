#include "http_client.hpp"

#include <boost/asio/connect.hpp>
#include <boost/asio/ip/tcp.hpp>
#include <boost/beast/core.hpp>
#include <boost/beast/http.hpp>
#include <boost/beast/version.hpp>
#include <fstream>
#include <sstream>
#include <sys/socket.h>
#include <sys/time.h>

namespace beast = boost::beast;
namespace http  = beast::http;
namespace net   = boost::asio;
namespace json  = boost::json;
using tcp = net::ip::tcp;

HttpClient::HttpClient(const std::string& host, int port)
    : host_(host), port_(port) {}

static void apply_timeout(tcp::socket& socket, int sec) {
    if (sec <= 0) return;
    timeval tv{sec, 0};
    ::setsockopt(socket.native_handle(), SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
    ::setsockopt(socket.native_handle(), SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv));
}

HttpClient::Response HttpClient::request(const std::string& method,
                                          const std::string& path,
                                          const json::value& body) {
    Response rsp;

    // 1. 连接
    net::io_context ioc;
    tcp::socket socket(ioc);
    apply_timeout(socket, timeout_sec_);
    tcp::resolver resolver(ioc);
    auto results = resolver.resolve(host_, std::to_string(port_));
    net::connect(socket, results);

    // 2. 构建请求
    http::verb v = http::verb::get;
    if (method == "POST")   v = http::verb::post;
    if (method == "PUT")    v = http::verb::put;
    if (method == "PATCH")  v = http::verb::patch;
    if (method == "DELETE") v = http::verb::delete_;

    http::request<http::string_body> req{v, path, 11};
    req.set(http::field::host, host_);
    req.set(http::field::user_agent, "EduClient/1.0");
    req.set(http::field::content_type, "application/json");
    if (!token_.empty())
        req.set(http::field::authorization, "Bearer " + token_);

    if (v != http::verb::get && v != http::verb::delete_) {
        req.body() = json::serialize(body);
        req.prepare_payload();
    }

    // 3. 发送 & 接收
    http::write(socket, req);
    beast::flat_buffer buffer;
    http::response<http::dynamic_body> resp;
    http::read(socket, buffer, resp);

    // 4. 关闭
    beast::error_code ec;
    socket.shutdown(tcp::socket::shutdown_both, ec);

    // 5. 解析
    rsp.status_code = resp.result_int();

    if (rsp.status_code == 204)
        return rsp;  // 空 body

    std::string resp_body = beast::buffers_to_string(resp.body().data());
    boost::system::error_code jec;
    json::value jv = json::parse(resp_body, jec);
    if (jec)
        throw std::runtime_error("JSON 解析失败: " + jec.message());

    if (rsp.status_code >= 400) {
        auto& obj = jv.as_object();
        std::string detail = "HTTP " + std::to_string(rsp.status_code);
        if (obj.find("detail") != obj.end())
            detail += ": " + json::value_to<std::string>(obj["detail"]);
        throw std::runtime_error(detail);
    }

    rsp.body = jv;
    return rsp;
}

HttpClient::Response HttpClient::get(const std::string& path) {
    return request("GET", path, {});
}

HttpClient::Response HttpClient::post(const std::string& path, const json::value& body) {
    return request("POST", path, body);
}

HttpClient::Response HttpClient::patch(const std::string& path, const json::value& body) {
    return request("PATCH", path, body);
}

HttpClient::Response HttpClient::put(const std::string& path, const json::value& body) {
    return request("PUT", path, body);
}

HttpClient::Response HttpClient::del(const std::string& path, const json::value& body) {
    return request("DELETE", path, body);
}

HttpClient::Response HttpClient::upload(const std::string& path,
                                         const std::string& file_field,
                                         const std::string& file_path) {
    Response rsp;
    net::io_context ioc;
    tcp::socket socket(ioc);
    apply_timeout(socket, timeout_sec_);
    tcp::resolver resolver(ioc);
    auto results = resolver.resolve(host_, std::to_string(port_));
    net::connect(socket, results);

    // 读文件
    std::ifstream fin(file_path, std::ios::binary);
    if (!fin)
        throw std::runtime_error("无法打开文件: " + file_path);
    std::ostringstream file_ss;
    file_ss << fin.rdbuf();
    std::string file_content = file_ss.str();

    std::string boundary = "----EduClientBoundary" + std::to_string(
        std::chrono::steady_clock::now().time_since_epoch().count());

    // 提取文件名和 MIME
    auto slash = file_path.find_last_of('/');
    std::string filename = (slash != std::string::npos)
                               ? file_path.substr(slash + 1)
                               : file_path;
    std::string mime = "application/octet-stream";
    auto dot = filename.find_last_of('.');
    if (dot != std::string::npos) {
        std::string ext = filename.substr(dot);
        if (ext == ".mp4") mime = "video/mp4";
        else if (ext == ".jpg" || ext == ".jpeg") mime = "image/jpeg";
        else if (ext == ".png") mime = "image/png";
        else if (ext == ".webp") mime = "image/webp";
    }

    std::ostringstream body_ss;
    body_ss << "--" << boundary << "\r\n"
            << "Content-Disposition: form-data; name=\"" << file_field
            << "\"; filename=\"" << filename << "\"\r\n"
            << "Content-Type: " << mime << "\r\n\r\n"
            << file_content << "\r\n"
            << "--" << boundary << "--\r\n";

    http::request<http::string_body> req{http::verb::post, path, 11};
    req.set(http::field::host, host_);
    req.set(http::field::content_type,
            "multipart/form-data; boundary=" + boundary);
    if (!token_.empty())
        req.set(http::field::authorization, "Bearer " + token_);
    req.body() = body_ss.str();
    req.prepare_payload();

    http::write(socket, req);
    beast::flat_buffer buffer;
    http::response<http::dynamic_body> resp;
    http::read(socket, buffer, resp);

    beast::error_code ec;
    socket.shutdown(tcp::socket::shutdown_both, ec);

    rsp.status_code = resp.result_int();
    if (rsp.status_code == 204) return rsp;

    std::string resp_body = beast::buffers_to_string(resp.body().data());
    boost::system::error_code jec;
    json::value jv = json::parse(resp_body, jec);
    if (jec)
        throw std::runtime_error("JSON 解析失败: " + jec.message());
    rsp.body = jv;
    return rsp;
}
