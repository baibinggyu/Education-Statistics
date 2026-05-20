#pragma once

#include <string>
#include <vector>

#include "config.hpp"

// ----- 对话消息 -----
struct Message {
    std::string role;    // "user" / "assistant" / "system"
    std::string content;
};

// ----- 单次请求返回 -----
struct ChatResponse {
    bool ok = false;
    std::string content;       // assistant 回复正文
    std::string error;         // ok==false 时的错误描述
    std::string stop_reason;   // "end_turn" / "max_tokens" / ...
    int input_tokens  = 0;
    int output_tokens = 0;

    /// 包含 API 调用开销在内的累计 token 数（可用于压缩判断）
    int total_tokens() const { return input_tokens + output_tokens; }
};

// ----- 对话压缩策略 -----
struct CompressConfig {
    int max_turns = 20;       // 保留最近 N 轮对话（1 轮 = user + assistant）
    int max_tokens = 8000;    // 累计 input_tokens 超过此值时触发压缩
    std::string summary_prompt = "请用中文简洁总结以下对话的要点，不要遗漏重要信息：";
};

// ----- 客户端 -----
class ChatClient {
public:
    explicit ChatClient(const Config& config);

    /// 设置单个 HTTP 请求的超时（毫秒），0 表示不限。
    /// 构造时自动从 Config::timeout_ms 读取初始值。
    void setTimeout(int ms) { timeout_ms_ = ms; }
    int  timeout() const { return timeout_ms_; }
    const std::string& model() const { return config_.model; }
    bool hasApiKey() const { return !config_.api_key.empty(); }
    std::size_t apiKeyLength() const { return config_.api_key.size(); }

    /// 发送消息列表，返回结构化结果。
    ChatResponse chat(const std::vector<Message>& messages);

    // ---- 对话压缩 ----

    /// 压缩对话历史：将较早的对话轮次用模型总结为一段 system 消息，
    /// 只保留最近 max_turns 轮原文，外加一条总结消息。
    /// 调用时机：在每轮 chat() 返回后自行判断是否需要压缩，
    ///           或通过 shouldCompress() 辅助判断。
    ChatResponse compress(std::vector<Message>& history,
                          const CompressConfig& cc = {});

    /// 返回是否需要压缩（根据累计 input_tokens + 轮数）。
    bool shouldCompress(const std::vector<Message>& history,
                        int last_input_tokens,
                        const CompressConfig& cc = {}) const;

private:
    Config config_;
    int timeout_ms_ = 0; // 0 = 不限
};
