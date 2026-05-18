#include "mainwindow.h"
#include <QApplication>
#include <QPushButton>
#include <QGridLayout>

#include <spdlog/spdlog.h>
#include <spdlog/sinks/basic_file_sink.h>
#include "spdlog/sinks/stdout_color_sinks.h"
#include <memory>
#include <QDebug>
#include <QDir>
#include <QIcon>

int main(int argc, char *argv[])
{
    qDebug() << QDir::currentPath();
    try{
        auto file_sink = std::make_shared<spdlog::sinks::basic_file_sink_mt>("warn.log",true);
        auto console_sink = std::make_shared<spdlog::sinks::stdout_color_sink_mt>();
        // 创建 logger，同时输出到文件和控制台
        spdlog::logger logger("multi_sink", {console_sink, file_sink});

        // 设置全局 logger
        spdlog::set_default_logger(std::make_shared<spdlog::logger>(logger));

        // 设置日志级别
        spdlog::set_level(spdlog::level::warn);  // 只记录 warn 及以上级别

        // 设置日志格式
        // [年-月-日 时:分:秒] [级别] 消息
        spdlog::set_pattern("[%Y-%m-%d %H:%M:%S] [%^%l%$] %v");
    }catch(const spdlog::spdlog_ex& ex){
        spdlog::error("Log initialization failed : {}",ex.what());
        return 1;
    }

    QApplication a(argc, argv);
    const QIcon appIcon(":/icon.png");
    a.setWindowIcon(appIcon);
    MainWindow w;
    w.setWindowIcon(appIcon);
    w.show();
    return a.exec();
}
