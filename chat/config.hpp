#pragma once

#include <cstdlib>
#include <string>

struct Config {
    std::string api_key;
    std::string base_url  = "https://api.deepseek.com/anthropic";
    std::string model     = "deepseek-v4-pro";
    int timeout_ms        = 60000;

    /// 从环境变量读取，缺少 api_key 时返回空字符串（调用方自行判断）。
    static Config from_env() {
        Config c;
        if (const char* v = std::getenv("ANTHROPIC_AUTH_TOKEN"))
            c.api_key = v;
        if (const char* v = std::getenv("ANTHROPIC_BASE_URL"))
            c.base_url = v;
        if (const char* v = std::getenv("ANTHROPIC_MODEL"))
            c.model = v;
        if (const char* v = std::getenv("API_TIMEOUT_MS"))
            c.timeout_ms = std::stoi(v);
        return c;
    }
};
