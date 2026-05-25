# EduStat_qml — QML + FluentUI 教学管理客户端

## 构建 (Windows)

```powershell
cmake -B build
cmake --build build --config Release
# 输出: build/Release/EduStat_qml.exe
```

前置条件：Qt 6 (Core, Quick, Qml, Widgets, Concurrent, Network, Multimedia, MultimediaWidgets), CMake 3.20+, C++20, FluentUI (zhuzichu520/FluentUI), ai-sdk-cpp。

## 运行环境要求

- `build/FluentUI/` — FluentUI QML 插件（POST_BUILD 自动复制）
- `build/FunASR/` — 字幕功能脚本（POST_BUILD 自动复制）
- 智能字幕需要 FunASR 环境（见下方"智能字幕"章节）

## 项目结构

```
EduStat_qml/
├── main.cpp                  # QQmlApplicationEngine, 注册 C++ 类型
├── api_client.h/cpp          # 后端 API 客户端（HTTP + ffmpeg 压缩 + FunASR 字幕）
├── agent_backend.h/cpp       # AI Agent ReAct 循环 (ai-sdk-cpp)
├── video_player_proxy.h/cpp  # 视频播放代理
├── VideoPlayer.h/cpp         # 独立视频播放器
├── CMakeLists.txt            # 构建配置
├── FluentUI/                 # FluentUI QML 插件（源码引用）
├── sounds/alarm.wav          # 倒计时提示音
└── qml_ui/
    ├── main.qml              # 主窗口：登录 + 侧边栏 + Loader 页面切换
    ├── LoginPage.qml         # 登录注册页
    ├── ClassInfoPage.qml     # 班级信息
    ├── RollCallPage.qml      # 点名（三种抽取模式）
    ├── TeamUpPage.qml        # 组队（随机/蛇形平衡 + 历史持久化）
    ├── StudentInfoPage.qml   # 学生信息 + 成绩编辑
    ├── SubjectManagePage.qml # 学科管理
    ├── CourseApplicationPage.qml # 开课申请
    ├── VideoPlayerPage.qml   # 视频播放（内嵌 MediaPlayer + VideoOutput）
    ├── ResourcePage.qml      # 课程资源上传（ffmpeg 压缩 + 智能字幕选项）
    ├── AnnouncementPage.qml  # 发布公告
    ├── CountdownPage.qml     # 倒计时（自定义时间 + 提示音）
    ├── MessagePage.qml       # 发消息
    └── ChatPage.qml          # AI 助手（普通模式 + Agent 模式）
```

## 后端 API

默认连接 `https://124.222.82.196`（可通过环境变量 `EDU_SERVER_URL` 覆盖）。

ApiClient 提供完整后端 API 包装：auth, courses, members, units, scores, videos, play-records, users, AI chat, file upload。

### 视频流认证

QMediaPlayer 不支持自定义 HTTP Header，所以 stream 端点用 `?token=<jwt>` 查询参数认证。

服务端需要部署 `routers/videos.py`（含 `?token=` 手动认证逻辑），或配置 nginx `map $arg_token $video_auth` 注入 Authorization 头。

## 智能字幕 (FunASR)

上传视频时可勾选"智能字幕"开关，自动调用 FunASR 进行语音识别并烧录硬字幕。

### 查找 Python 环境的优先级

代码中用 `#ifdef __linux__` / `#elif _WIN32` 区分平台：

1. `<appDir>/FunASR/venv/Scripts/python.exe` + `asr.py`（Windows 部署目录）
2. `<FUNASR_SOURCE_DIR>/venv/Scripts/python.exe` + `asr.py`（源码树，开发）
3. 最后回退到系统 `python` + 最近的 `asr.py`

调试技巧——在 Microsoft Edge 或 Chrome 中按 F12 打开开发者工具可以查看 QML 的 `console.log` 输出。

### Windows 上搭建 FunASR 环境

```powershell
cd ..\FunASR
python -m venv venv
.\venv\Scripts\activate
pip install funasr ffmpeg-python torch

# 首次运行会自动下载模型（约 200MB），之后缓存
python asr.py test.mp4 out.mp4
```

FunASR 的 `autoModel` 用 `sentence_timestamp=True` 获取时间戳生成 SRT 字幕。

## 代码约定

- 页面间用 `Loader` + `currentPage` 属性切换
- 页面需要 `required property ApiClient requiredApiClient` 来调 API
- FluentUI 组件：FluFrame, FluText, FluFilledButton, FluButton, FluTextBox, FluToggleSwitch, FluSlider, FluScrollBar 等
- 暗色主题：`FluTheme.darkMode = 2`, 主色 `#0f766e`
- 服务端所有 API 路径用 UUID（非内部 BIGINT ID）
- 软删除：`status = "deleted"`（不物理删除文件/记录）

## 常用命令

```powershell
# 构建
cmake -B build && cmake --build build --config Release

# 运行
.\build\Release\EduStat_qml.exe

# 指定服务器地址
$env:EDU_SERVER_URL = "https://your-server.com"
.\build\Release\EduStat_qml.exe
```
