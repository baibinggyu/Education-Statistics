#include <iostream>

#include "config.hpp"
#include "edu_client.hpp"

int main() {
    auto cfg = EduServerConfig::from_env();

    std::cout << "=== Edu API Client ===\n"
              << "server: " << cfg.host << ":" << cfg.port << "\n\n";

    try {
        EduClient client(cfg);

        // 1. 健康检查（无需认证）
        auto health = client.health();
        std::cout << "[health] status: "
                  << health.as_object().at("status").as_string() << "\n";

        // 2. 登录（需要先注册用户，这里用测试账号）
        TokenOut token = client.login({"testuser", "testpass"});
        std::cout << "[login] token: " << token.access_token.substr(0, 20)
                  << "...\n";

        // 3. 获取个人信息
        auto me = client.get_me();
        std::cout << "[me] " << me.username << " (" << me.role << ")\n";

        // 4. 列出我的课程
        auto courses = client.list_my_courses();
        std::cout << "[courses] " << courses.size() << " 门\n";
        for (auto& c : courses)
            std::cout << "  - " << c.name << " [" << c.my_role << "]\n";

    } catch (const std::exception& e) {
        std::cerr << "[Error] " << e.what() << "\n";
        // 服务器未部署时预期会失败，不算致命
    }

    std::cout << "\nDone.\n";
    return 0;
}
