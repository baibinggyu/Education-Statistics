#pragma once

#include <cstdlib>
#include <string>

struct EduServerConfig {
    std::string host = "127.0.0.1";
    int port         = 55555;

    static EduServerConfig from_env() {
        EduServerConfig c;
        if (const char* v = std::getenv("education_statistics_server_ip"))
            c.host = v;
        if (const char* v = std::getenv("education_statistics_server_port"))
            c.port = std::stoi(v);
        return c;
    }
};
