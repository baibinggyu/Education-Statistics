# 技术栈总览

## 桌面应用

| 技术 | 子项目 | 用途 |
|------|--------|------|
| C++17 | EduStat, EduStat_qml, player | 核心编程语言 |
| Qt 6 Core | EduStat, EduStat_qml, player | 基础框架 |
| Qt 6 Widgets | EduStat, player | 桌面 UI 组件 |
| Qt 6 Charts | EduStat | 数据可视化图表 |
| Qt 6 Sql | EduStat | 数据库驱动 |
| Qt 6 Network | EduStat | 网络请求 |
| Qt 6 Multimedia | player | 音视频解码播放 |
| Qt 6 Quick / Qml | EduStat_qml, edu_pe, loggin | QML 声明式 UI |
| FluentUI | EduStat_qml | Microsoft Fluent Design 组件库 |
| CMake 3.16+ | 全部 C++ 项目 | 构建系统 |
| spdlog | EduStat | 日志库 |

## 后端服务

| 技术 | 子项目 | 用途 |
|------|--------|------|
| Python 3.14 | routing | 编程语言 |
| FastAPI | routing | Web API 框架 |
| Uvicorn | routing | ASGI 服务器 |
| SQLAlchemy | routing | ORM |
| PyMySQL | routing | MySQL 驱动 |
| passlib + bcrypt | routing | 密码哈希 |
| python-jose | routing | JWT 认证 |
| Alembic | routing | 数据库迁移 |
| httpx | routing | HTTP 客户端 |
| pytest | routing | 测试框架 |
| uv | routing | Python 包管理 |

## 数据库

| 技术 | 子项目 | 用途 |
|------|--------|------|
| SQLite | EduStat | 本地数据库 |
| MariaDB (InnoDB, utf8mb4) | database, routing | 生产数据库 |

## 前端展示

| 技术 | 子项目 | 用途 |
|------|--------|------|
| HTML + CSS + JS | index.html | 项目展示落地页（零依赖） |

## 辅助工具

| 技术 | 子项目 | 用途 |
|------|--------|------|
| pandas, openpyxl, xlrd | EduStat | Excel 数据处理 |
| PyInstaller | EduStat | Python 脚本打包成 exe |

## 按层级分类

```
┌─ 桌面应用 ──────────────────────────────────────────┐
│  C++17 + Qt6 (Widgets / QML) + CMake + FluentUI    │
├─ 后端服务 ──────────────────────────────────────────┤
│  Python + FastAPI + MariaDB + JWT + pytest          │
├─ 数据库 ────────────────────────────────────────────┤
│  SQLite (本地) / MariaDB (服务端)                    │
├─ 移动端原型 ────────────────────────────────────────┤
│  QML（纯 UI，无后端）                                │
└─ 前端展示 ──────────────────────────────────────────┘
   HTML + CSS + JS（零依赖）
```
