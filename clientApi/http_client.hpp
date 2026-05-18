#pragma once

#include <boost/json.hpp>
#include <string>

class HttpClient {
public:
    HttpClient(const std::string& host, int port);

    /// 连接/读写超时（秒），0 表示不限
    void set_timeout(int sec) { timeout_sec_ = sec; }

    /// 设置 Bearer token（登录后调用）
    void set_token(const std::string& token) { token_ = token; }
    bool has_token() const { return !token_.empty(); }

    /// HTTP 方法。返回 JSON，出错时抛 std::runtime_error。
    boost::json::value get (const std::string& path);
    boost::json::value post(const std::string& path,
                            const boost::json::value& body);
    boost::json::value put (const std::string& path,
                            const boost::json::value& body);
    boost::json::value del (const std::string& path,
                            const boost::json::value& body = {});

    // 文件上传（multipart）
    boost::json::value upload(const std::string& path,
                              const std::string& file_field,
                              const std::string& file_path);

private:
    std::string host_;
    int port_;
    std::string token_;
    int timeout_sec_ = 5;  // 默认 5 秒超时

    boost::json::value request(const std::string& method,
                               const std::string& path,
                               const boost::json::value& body);
    boost::json::value request_multipart(const std::string& path,
                                         const std::string& file_field,
                                         const std::string& file_path);
};
