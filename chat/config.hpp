#pragma once

#include <algorithm>
#include <cctype>
#include <cstdlib>
#include <fstream>
#include <sstream>
#include <string>
#include <utility>

#if defined(__unix__) || defined(__APPLE__)
#include <pwd.h>
#include <sys/types.h>
#include <unistd.h>
#endif

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
        if (c.api_key.empty()) {
            if (const char* v = std::getenv("DEEPSEEK_API_KEY"))
                c.api_key = v;
        }
        if (const char* v = std::getenv("ANTHROPIC_BASE_URL"))
            c.base_url = v;
        if (const char* v = std::getenv("ANTHROPIC_MODEL"))
            c.model = v;
        if (const char* v = std::getenv("API_TIMEOUT_MS"))
            c.timeout_ms = std::stoi(v);
        return c;
    }

    static Config from_default_locations() {
        Config c = from_env();
        if (!c.api_key.empty()) return c;

        const std::string home = home_directory();
        if (!home.empty()) {
            apply_file(c, home + "/.bashrc");
            apply_file(c, home + "/.profile");
            apply_file(c, home + "/.zshrc");
        }
        return c;
    }

private:
    static std::string home_directory() {
        if (const char* home = std::getenv("HOME"))
            return home;
#if defined(__unix__) || defined(__APPLE__)
        if (const passwd* pw = getpwuid(getuid()))
            return pw->pw_dir;
#endif
        return {};
    }

    static std::string trim(std::string s) {
        auto is_space = [](unsigned char ch) { return std::isspace(ch); };
        s.erase(s.begin(), std::find_if(s.begin(), s.end(), [&](unsigned char ch) {
            return !is_space(ch);
        }));
        s.erase(std::find_if(s.rbegin(), s.rend(), [&](unsigned char ch) {
            return !is_space(ch);
        }).base(), s.end());
        return s;
    }

    static std::string unquote(std::string s) {
        s = trim(std::move(s));
        if (s.size() >= 2 &&
            ((s.front() == '"' && s.back() == '"') ||
             (s.front() == '\'' && s.back() == '\''))) {
            return s.substr(1, s.size() - 2);
        }
        return s;
    }

    static void apply_value(Config& c, const std::string& key, const std::string& value) {
        if (value.empty()) return;
        if (key == "ANTHROPIC_AUTH_TOKEN" || key == "DEEPSEEK_API_KEY")
            c.api_key = value;
        else if (key == "ANTHROPIC_BASE_URL")
            c.base_url = value;
        else if (key == "ANTHROPIC_MODEL")
            c.model = value;
        else if (key == "API_TIMEOUT_MS")
            c.timeout_ms = std::stoi(value);
    }

    static void apply_line(Config& c, std::string line) {
        line = trim(std::move(line));
        if (line.empty() || line.front() == '#') return;
        constexpr const char* export_prefix = "export ";
        if (line.rfind(export_prefix, 0) == 0)
            line = trim(line.substr(std::char_traits<char>::length(export_prefix)));

        const auto eq = line.find('=');
        if (eq == std::string::npos) return;
        const std::string key = trim(line.substr(0, eq));
        std::string value = trim(line.substr(eq + 1));

        const auto comment = value.find(" #");
        if (comment != std::string::npos)
            value = trim(value.substr(0, comment));

        apply_value(c, key, unquote(value));
    }

    static void apply_file(Config& c, const std::string& path) {
        std::ifstream input(path);
        if (!input) return;
        std::string line;
        while (std::getline(input, line))
            apply_line(c, line);
    }
};
