#include <iostream>
#include <string>
#include <vector>

#include "chat_client.hpp"
#include "config.hpp"

int main() {
    Config config = Config::from_env();
    if (config.api_key.empty()) {
        std::cerr << "[Fatal] 环境变量 ANTHROPIC_AUTH_TOKEN 未设置\n";
        return 1;
    }

    std::cout << "=== DeepSeek Chat ===\n"
              << "model : " << config.model << "\n"
              << "url   : " << config.base_url << "\n"
              << "命令  : /exit 退出  /clear 清上下文  /compress 压缩历史\n"
              << "========================\n\n";

    try {
        ChatClient client(config);
        std::vector<Message> history;
        std::string line;
        int last_input_tokens = 0;

        while (true) {
            std::cout << "> " << std::flush;
            if (!std::getline(std::cin, line)) break;

            while (!line.empty() && line.front() == ' ') line.erase(0, 1);
            while (!line.empty() && line.back() == ' ') line.pop_back();

            if (line.empty()) continue;
            if (line == "/exit" || line == "/quit") break;

            if (line == "/clear") {
                history.clear();
                last_input_tokens = 0;
                std::cout << "[已清除对话历史]\n\n";
                continue;
            }

            if (line == "/compress") {
                CompressConfig cc;
                cc.max_turns = 10;
                auto resp = client.compress(history, cc);
                std::cout << "[压缩] " << resp.content << "\n\n";
                continue;
            }

            // 自动压缩提示
            if (client.shouldCompress(history, last_input_tokens)) {
                std::cout << "[提示] 对话较长，建议输入 /compress 压缩历史\n";
            }

            history.push_back({"user", line});

            auto resp = client.chat(history);
            if (!resp.ok) {
                std::cerr << "[Error] " << resp.error << "\n\n";
                history.pop_back();
                continue;
            }

            std::cout << resp.content << "\n\n";
            history.push_back({"assistant", resp.content});
            last_input_tokens = resp.input_tokens;
        }

        std::cout << "再见。\n";
    } catch (const std::exception& e) {
        std::cerr << "[Fatal] " << e.what() << "\n";
        return 1;
    }

    return 0;
}
