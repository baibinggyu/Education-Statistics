# Edu Server — 服务端路由架构总设计

本文档集是 Edu Server 服务端的完整路由架构设计，基于：

- **数据库**: MariaDB 8 表 (users, students, courses, course_members, units, scores, videos, play_records)
- **后端框架**: FastAPI + SQLAlchemy ORM + PyMySQL
- **反向代理**: Nginx (反向代理 + 静态视频服务 + X-Accel-Redirect 鉴权)
- **认证**: JWT (access token + refresh token) + bcrypt 密码哈希
- **目标**: 为 Qt 桌面端、QML 移动端、Web 端提供统一的 RESTful API

---

## 文档索引

| 文件 | 内容 |
|------|------|
| `ARCHITECTURE.md` | 整体架构设计、部署拓扑、数据流、设计决策 |
| `nginx/edu-server.conf` | Nginx 完整配置 (反向代理 + 视频静态服务 + WebSocket + 限流) |
| `api-route-design.md` | 全部 API 路由设计 (6 个路由模块, 40+ 端点) |
| `implementation-plan.md` | 分阶段实施计划 (三阶段，从 MVP 到完整平台) |

---

## 核心设计理念

### 1. 双层 ID 策略
- **对外**: 全部使用 UUID (API 路径中不暴露数据库自增 ID)
- **对内**: 全部使用 BIGINT id (数据库外键关联，查询性能)

### 2. 逻辑删除
- courses、videos 等核心数据使用 `status = deleted` 而非物理 DELETE
- 保留成绩、播放记录等历史数据关联完整性

### 3. 视频流分离
- **元数据 API**: FastAPI 负责 (CRUD、权限校验)
- **视频文件流**: Nginx 直接服务 (X-Accel-Redirect 模式，FastAPI 鉴权后交给 Nginx)
- **视频上传**: FastAPI 接收 multipart，落盘后 Nginx 可服务

### 4. 权限分层
- **公开**: 注册、登录
- **学生**: 查看自己加入的课程、视频、成绩
- **教师**: 管理自己的课程 (内容、成员、成绩)
- **管理员**: 全局管理 (用户、所有课程、系统配置)

### 5. Nginx 作为唯一公网入口
- FastAPI 只监听 127.0.0.1:55555，不暴露公网
- Nginx 处理 TLS、静态文件、限流、请求缓冲
