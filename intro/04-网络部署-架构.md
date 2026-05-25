# Edu Server — 整体架构设计

## 1. 部署拓扑

```
Internet (HTTPS)
    │
    ▼
┌──────────────────────────────────────────────┐
│  Nginx (:443 / :80)                          │
│  ├── /api/*          → 127.0.0.1:55555       │
│  ├── /stream/video/* → 127.0.0.1:55555       │
│  │    (鉴权后 X-Accel-Redirect → /internal/) │
│  ├── /docs            → 127.0.0.1:55555/docs │
│  ├── /openapi.json    → 127.0.0.1:55555      │
│  └── /static/*       → 直接静态文件           │
└──────────────────────────────────────────────┘
    │
    ▼
┌──────────────────────────────────────────────┐
│  FastAPI (uvicorn 127.0.0.1:55555)           │
│  ├── routers/auth.py         (注册/登录)     │
│  ├── routers/users.py        (用户信息)       │
│  ├── routers/courses.py      (课程 CRUD)     │
│  ├── routers/units.py        (单元管理)       │
│  ├── routers/scores.py       (成绩管理)       │
│  ├── routers/videos.py       (视频管理)       │
│  ├── routers/play_records.py (播放记录)       │
│  ├── routers/files.py        (文件上传)       │
│  ├── routers/students.py     (学生档案)       │
│  ├── database.py             (连接池)         │
│  ├── models.py               (ORM 模型)      │
│  ├── schemas.py              (Pydantic)      │
│  ├── security.py             (JWT + bcrypt)  │
│  └── deps.py                 (依赖注入)       │
└──────────────────────────────────────────────┘
    │
    ▼
┌──────────────────────────────────────────────┐
│  MariaDB (127.0.0.1:3306)                    │
│  Database: edu_server_database               │
│  8 tables + 索引 + 外键约束                   │
└──────────────────────────────────────────────┘

文件系统:
  /srv/edu/uploads/
  ├── videos/       (上传的 MP4 文件)
  └── covers/       (视频封面图片)
```

---

## 2. 目录结构

```
routing/
├── main.py                      (现有简化版 — 保留不动)
├── plan.md                      (老版本设计文档 — 保留不动)
├── source/edu/test.mp4          (测试视频 — 保留不动)
│
├── edu_server/                  (新后端 — 逐步构建)
│   ├── main.py                  (FastAPI 入口)
│   ├── database.py              (SQLAlchemy engine + session)
│   ├── models.py                (8 个 ORM 模型)
│   ├── schemas.py               (Pydantic request/response)
│   ├── security.py              (JWT + bcrypt)
│   ├── deps.py                  (Depends 依赖注入)
│   ├── routers/
│   │   ├── __init__.py
│   │   ├── auth.py              (注册 / 登录 / 刷新 token)
│   │   ├── users.py             (当前用户 / 管理员用户列表)
│   │   ├── students.py          (学生档案绑定)
│   │   ├── courses.py           (课程 CRUD + 成员管理)
│   │   ├── units.py             (单元 CRUD)
│   │   ├── scores.py            (成绩录入 / 查询 / 批量)
│   │   ├── videos.py            (视频 CRUD + 流媒体)
│   │   ├── play_records.py      (播放进度)
│   │   └── files.py             (文件上传 / 静态资源)
│   ├── services/                (业务逻辑层 — 第二阶段)
│   │   ├── __init__.py
│   │   ├── analysis.py          (AI 学情分析)
│   │   ├── export.py            (成绩导出 XLSX)
│   │   └── statistics.py        (统计聚合)
│   └── tests/                   (pytest 测试套件)
│       ├── conftest.py          (测试 fixtures: DB, client)
│       ├── test_alchemy.py      (ORM 模型测试)
│       └── test_routes.py       (API 端点测试)
│
├── nginx/
│   └── edu-server.conf          (Nginx 配置)
│
└── edu_routing/                 (Python venv — 已存在)
```

---

## 3. 数据流

### 3.1 用户认证流

```
客户端                        Nginx                     FastAPI                 MariaDB
  │                            │                          │                       │
  │ POST /api/auth/register    │                          │                       │
  │ ──────────────────────────►│ ────────────────────────►│                       │
  │                            │                          │ INSERT users          │
  │                            │                          │ ─────────────────────►│
  │                            │                          │ ◄── OK                │
  │ ◄── { username, uuid }     │ ◄────────────────────── │                       │
  │                            │                          │                       │
  │ POST /api/auth/login       │                          │                       │
  │ ──────────────────────────►│ ────────────────────────►│                       │
  │                            │                          │ SELECT FROM users     │
  │                            │                          │ ─────────────────────►│
  │                            │                          │ ◄── password_hash     │
  │                            │                          │ bcrypt.verify()       │
  │                            │                          │ jwt.encode({sub,role})│
  │ ◄── { access_token }       │ ◄────────────────────── │                       │
```

### 3.2 视频播放流 (鉴权模式)

```
客户端                        Nginx                     FastAPI                 文件系统
  │                            │                          │                       │
  │ GET /api/videos/{uuid}/stream?token=xxx               │                       │
  │ ──────────────────────────►│ ────────────────────────►│                       │
  │                            │                          │ 1. 验证 JWT           │
  │                            │                          │ 2. 查 video 元数据    │
  │                            │                          │ 3. 校验 course 权限   │
  │                            │                          │                       │
  │                            │     X-Accel-Redirect:    │                       │
  │                            │     /internal/video/uuid │                       │
  │                            │ ◄─────────────────────── │                       │
  │                            │                          │                       │
  │                            │ location /internal/ {    │                       │
  │                            │   internal;              │                       │
  │                            │   alias /srv/edu/uploads/videos/;                │
  │                            │ }                        │                       │
  │                            │ ────────────────────────────────────────────────►│
  │ ◄── MP4 字节流             │ ◄────────────────────────────────────────────────│
```

### 3.3 成绩查询流 (带聚合)

```
客户端                        Nginx                     FastAPI                 MariaDB
  │                            │                          │                       │
  │ GET /api/scores/course/{course_uuid}/summary           │                       │
  │ ──────────────────────────►│ ────────────────────────►│                       │
  │                            │                          │ 验证 JWT              │
  │                            │                          │ 校验 course 成员      │
  │                            │                          │                       │
  │                            │                          │ SELECT s.student_no,  │
  │                            │                          │   AVG(sc.score * u.weight) AS weighted
  │                            │                          │ FROM scores sc        │
  │                            │                          │ JOIN students st ...  │
  │                            │                          │ JOIN units u ...      │
  │                            │                          │ GROUP BY st.id        │
  │                            │                          │ ─────────────────────►│
  │                            │                          │ ◄── 聚合结果          │
  │ ◄── [{student, avg, rank}] │ ◄────────────────────── │                       │
```

---

## 4. 路由模块划分

| 路由模块 | Prefix | 职责 | 角色限制 |
|---------|--------|------|---------|
| auth | `/api/auth` | 注册、登录、刷新 Token | 公开 |
| users | `/api/users` | 用户信息、管理员管理 | 登录用户 + admin |
| students | `/api/students` | 学生档案绑定 | 登录用户 + admin |
| courses | `/api/courses` | 课程 CRUD、成员管理 | 登录用户 (增删改需 teacher/admin) |
| units | `/api/courses/{course_uuid}/units` | 课程单元管理 | teacher/admin |
| scores | `/api/scores` | 成绩录入、查询、汇总 | teacher/admin 写入；学生读自己的 |
| videos | `/api/videos` | 视频元数据 CRUD、流媒体 | 登录用户 (增删改需 teacher/admin) |
| play_records | `/api/play-records` | 播放进度上报/查询 | 登录用户 |
| files | `/api/files` | 文件上传、静态资源 | teacher/admin 上传 |

---

## 5. 关键设计决策

### 5.1 为什么使用 X-Accel-Redirect 而不是 FastAPI StreamingResponse

- **效率**: Nginx 的 `sendfile()` 系统调用直接在内核态传输文件，不经过 Python 进程
- **Range 请求**: Nginx 原生支持 HTTP Range，支持视频拖动进度条
- **并发**: 单个 Nginx worker 可以处理数千并发视频连接
- **适用**: 需要鉴权的视频 (检查用户是否属于该课程)

### 5.2 为什么保留 BIGINT id 而不全部使用 UUID

- **查询性能**: BIGINT 索引比 CHAR(36) 小 4 倍，JOIN 更快
- **存储成本**: BIGINT 8 字节 vs UUID CHAR(36) 36 字节 (在 scores 表百万级数据时差异巨大)
- **对外安全**: UUID 防止枚举攻击，不暴露数据规模
- **转换位置**: 在 FastAPI 依赖层完成 uuid → id 转换，业务代码只操作 id

### 5.3 课程成员检查模式

所有课程相关端点都复用同一个成员检查逻辑：

```python
# deps.py 中的可复用依赖
def require_course_member(course_uuid: str, db, user) -> Course:
    """验证用户是否属于该课程，返回 course 对象 (含 BIGINT id)"""
    course = db.query(Course).filter(
        Course.uuid == course_uuid,
        Course.status != "deleted"
    ).first()
    if not course:
        raise 404
    if user.role == "admin":
        return course
    member = db.query(CourseMember).filter(
        CourseMember.course_id == course.id,
        CourseMember.user_id == user.id
    ).first()
    if not member:
        raise 403
    return course
```

### 5.4 成绩计算的权重聚合

```
加权总分 = Σ (score / full_score × weight × 100) / Σ weight

示例:
  作业1: weight=0.2, full_score=100, score=85  → 贡献 0.2 × 85 = 17
  作业2: weight=0.2, full_score=50,  score=40  → 贡献 0.2 × 80 = 16
  期中:  weight=0.3, full_score=100, score=70  → 贡献 0.3 × 70 = 21
  期末:  weight=0.3, full_score=120, score=100 → 贡献 0.3 × 83.3 = 25

  加权总分 = 17 + 16 + 21 + 25 = 79
  归一化   = 79 / 1.0 = 79 分
```

---

## 6. 安全设计

| 措施 | 实现位置 |
|------|---------|
| 密码哈希 (bcrypt) | `security.py` — passlib |
| JWT 签名 (HS256) | `security.py` — python-jose |
| Token 过期 (7天) | `security.py` — exp claim |
| UUID 对外暴露 | 所有 response schema 使用 uuid |
| 逻辑删除 | courses/videos 的 DELETE 改为 status=deleted |
| Nginx 限流 (登录/注册) | `nginx/edu-server.conf` — limit_req |
| FastAPI 只监听 127.0.0.1 | uvicorn --host 127.0.0.1 |
| Nginx 隐藏内部 /internal/ | `internal;` 指令，外部不可访问 |
| 上传文件类型白名单 | `routers/files.py` — 检查 MIME 和扩展名 |
| 文件大小限制 | Nginx client_max_body_size + FastAPI 校验 |
