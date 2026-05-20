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

    /// HTTP 方法。返回 JSON + status_code，出错时抛 std::runtime_error。
    /// 对于 204 No Content 返回空 object。
    struct Response {
        boost::json::value body;
        int status_code = 0;
    };
    Response get (const std::string& path);
    Response post(const std::string& path, const boost::json::value& body);
    Response patch(const std::string& path, const boost::json::value& body);
    Response put (const std::string& path, const boost::json::value& body);
    Response del (const std::string& path, const boost::json::value& body = {});

    // 文件上传（multipart），extra_fields 作为 query params 附加到 URL
    Response upload(const std::string& path,
                    const std::string& file_field,
                    const std::string& file_path);

private:
    std::string host_;
    int port_;
    std::string token_;
    int timeout_sec_ = 10;  // 默认 10 秒超时

    Response request(const std::string& method,
                     const std::string& path,
                     const boost::json::value& body);
};
