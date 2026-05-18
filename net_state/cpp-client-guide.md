# Edu Server — HTTP / HTTPS 接口说明

纯 HTTP 协议层文档。每个接口标注完整的请求格式和响应格式。

---

## 0. 基础约定

### 0.1 服务器地址

```
HTTP  开发环境:  http://127.0.0.1:55555        (FastAPI 直连)
HTTP  开发环境:  http://127.0.0.1:80            (走 Nginx 反向代理)
HTTPS 生产环境:  https://edu.your-domain.com    (Nginx TLS 终端)
HTTPS 生产环境:  https://edu.your-domain.com:443
```

全文用 `{host}` 代替。

### 0.2 认证机制：Bearer Token

**不使用 Cookie / Session。** 认证流程：

```
客户端                                  服务端
  │                                       │
  │  POST /api/auth/login                 │
  │  {"username","password"}              │
  │ ────────────────────────────────────► │
  │                                       │ bcrypt 校验密码
  │                                       │ 生成 JWT (含 user_uuid + role + exp)
  │  {"access_token":"eyJ...",            │
  │   "token_type":"bearer"}              │
  │ ◄──────────────────────────────────── │
  │                                       │
  │  客户端自行保存 token（内存/文件/钥匙串）  │
  │                                       │
  │  GET /api/users/me                    │
  │  Authorization: Bearer eyJ...         │
  │ ────────────────────────────────────► │
  │                                       │ JWT 解码 → 查用户 → 校验 status
  │  {"uuid":"...","username":"..."}      │
  │ ◄──────────────────────────────────── │
```

**为什么不用 Cookie：**
- 桌面客户端 / 手机 App 不是浏览器，没有自动管理 Cookie 的机制
- Bearer Token 跨端一致（Qt C++ / QML / FastAPI Swagger / Web 都用同一套）
- 服务端无状态，不存 session，水平扩展时无需共享 session 存储

### 0.3 通用请求头

所有 JSON 请求必须带：

```
Content-Type: application/json
```

需要登录的接口带：

```
Authorization: Bearer <access_token>
```

**注意**：`Bearer` 后面有一个空格，然后是 token 字符串。

### 0.4 通用响应格式

成功：响应体为 JSON（或 204 No Content）
失败：响应体一律为 JSON

```json
{"detail": "具体错误信息"}
```

### 0.5 UUID 约定

路径中的资源标识全部用 UUID（如 `a1b2c3d4-e5f6-7890-abcd-ef1234567890`）。不暴露数据库自增 ID。

### 0.6 HTTP vs HTTPS — 客户端差异

本节先说明协议层的核心差异，后续第 13 章有完整的专项展开。

| 层面 | HTTP | HTTPS |
|------|------|-------|
| Base URL | `http://127.0.0.1:55555` | `https://edu.your-domain.com` |
| 端口 | 55555 (FastAPI) / 80 (Nginx) | 443 (Nginx) |
| 传输层 | TCP 明文 | TCP + TLS 1.2/1.3 加密 |
| 证书 | 不需要 | 需要 CA 签发的证书（生产）或自签名证书（开发） |
| 客户端要求 | 无 | 需验证服务端证书链 |
| 请求头 | 全明文传输 | 加密传输（TLS 层） |
| API 格式 | 完全一致 | 完全一致 |
| Token 安全 | Bearer token 明文在网络中传输 | Bearer token 被 TLS 加密 |

**核心结论**：对于客户端代码，HTTP 和 HTTPS 的唯一区别是 **Base URL 从 `http://` 改成 `https://`**。API 路径、请求头、请求体、响应格式完全不变。复杂度在 TLS 握手和证书校验，不在业务代码。

---

## 1. 认证模块 `/api/auth`

### 1.1 注册

```
POST /api/auth/register
Content-Type: application/json

请求体:
{
    "username": "teacher1",       // 1-64 字符
    "password": "123456",         // 明文传输（HTTPS 下被 TLS 加密）
    "role": "teacher"             // "student" | "teacher" | "admin"
}

成功 201:
{
    "uuid": "a1b2c3d4-...",
    "username": "teacher1",
    "role": "teacher",
    "created_at": "2026-01-01T00:00:00"
}

失败:
  409  {"detail": "Username already exists"}
  422  {"detail": "[...]"}                         // Pydantic 参数校验错误
```

### 1.2 登录

```
POST /api/auth/login
Content-Type: application/json

请求体:
{
    "username": "teacher1",
    "password": "123456"
}

成功 200:
{
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "token_type": "bearer"
}

失败:
  401  {"detail": "Invalid username or password"}
  403  {"detail": "User is disabled"}
```

---

## 2. 用户模块 `/api/users`

### 2.1 获取当前用户

```
GET /api/users/me
Authorization: Bearer <token>

成功 200 (teacher 角色):
{
    "uuid": "a1b2c3d4-...",
    "username": "teacher1",
    "role": "teacher",
    "created_at": "2026-01-01T00:00:00",
    "student": null
}

成功 200 (student 角色):
{
    "uuid": "b1b2b3d4-...",
    "username": "student1",
    "role": "student",
    "created_at": "2026-01-01T00:00:00",
    "student": {
        "student_no": "2024010101",
        "real_name": "小明"
    }
}

失败:
  401  token 无效或过期
  403  用户被禁用（status != 1）
```

### 2.2 修改用户名

```
PATCH /api/users/me
Authorization: Bearer <token>
Content-Type: application/json

请求体:
{
    "username": "new_name"        // 可选，1-64 字符
}

成功 200: UserMeOut（同上）
失败:
  409  {"detail": "Username already taken"}
```

---

## 3. 课程模块 `/api/courses`

### 3.1 创建课程

```
POST /api/courses/
Authorization: Bearer <token>
Content-Type: application/json

请求体:
{
    "name": "C++ 程序设计",            // 1-128 字符
    "description": "面向对象基础"       // 可选
}

成功 201:
{
    "uuid": "c1c2c3d4-...",
    "name": "C++ 程序设计",
    "description": "面向对象基础",
    "teacher": {
        "uuid": "...",
        "username": "teacher1"
    },
    "status": "normal",
    "member_count": 1,
    "video_count": 0,
    "my_role": "teacher",
    "created_at": "2026-01-01T00:00:00"
}

失败:
  403  {"detail": "Permission denied: teacher or admin only"}
  422  参数校验失败
```

### 3.2 获取我的课程列表

```
GET /api/courses/
Authorization: Bearer <token>

成功 200 (JSON 数组):
[
    {
        "uuid": "c1c2c3d4-...",
        "name": "C++ 程序设计",
        "description": "...",
        "teacher": { "uuid": "...", "username": "teacher1" },
        "status": "normal",
        "member_count": 45,
        "video_count": 12,
        "my_role": "teacher",
        "created_at": "2026-01-01T00:00:00"
    },
    ...
]

// admin 看到全部课程；teacher/student 只看到自己加入的
```

### 3.3 获取课程详情（含单元）

```
GET /api/courses/{course_uuid}
Authorization: Bearer <token>

成功 200:
{
    "uuid": "c1c2c3d4-...",
    "name": "C++ 程序设计",
    "description": "...",
    "teacher": { "uuid": "...", "username": "teacher1" },
    "status": "normal",
    "units": [
        {
            "id": 1,
            "name": "第一次作业",
            "weight": 0.2,
            "full_score": 100.0,
            "unit_order": 1,
            "created_at": "2026-01-01T00:00:00"
        },
        ...
    ],
    "member_count": 45,
    "created_at": "2026-01-01T00:00:00"
}

失败:
  404  {"detail": "Course not found"}
  403  {"detail": "You are not a member of this course"}
```

### 3.4 更新课程

```
PATCH /api/courses/{course_uuid}
Authorization: Bearer <token>
Content-Type: application/json

请求体:
{
    "name": "新课程名",         // 可选
    "description": "新描述"      // 可选
}

成功 200: CourseMyOut
失败:
  403  只有本课程教师或 admin 可修改
```

### 3.5 删除课程

```
DELETE /api/courses/{course_uuid}
Authorization: Bearer <token>

成功 204 (No Content, 响应体为空)

// 逻辑删除，status → "deleted"，数据库记录仍在
失败:
  403  只有本课程教师或 admin 可删
```

### 3.6 查看成员

```
GET /api/courses/{course_uuid}/members
Authorization: Bearer <token>

成功 200:
[
    {
        "user_uuid": "u1-...",
        "username": "student1",
        "member_role": "student",
        "joined_at": "2026-01-01T00:00:00",
        "student": {
            "student_no": "2024010101",
            "real_name": "张三"
        }
    },
    {
        "user_uuid": "u2-...",
        "username": "teacher1",
        "member_role": "teacher",
        "joined_at": "2026-01-01T00:00:00",
        "student": null
    }
]

失败:
  403  你不是该课程成员
```

### 3.7 添加成员

```
POST /api/courses/{course_uuid}/members
Authorization: Bearer <token>
Content-Type: application/json

// 方式一: 按用户名
{"username": "student1"}

// 方式二: 按学号
{"student_no": "2024010101"}

// username 和 student_no 二选一

成功 201:
{
    "user_uuid": "u1-...",
    "username": "student1",
    "member_role": "student",
    "joined_at": "2026-01-01T00:00:00",
    "student": { "student_no": "2024010101", "real_name": "张三" }
}

失败:
  404  {"detail": "User not found"}
  409  {"detail": "User is already a member"}
  403  只有本课程教师或 admin 可添加
```

### 3.8 移除成员

```
DELETE /api/courses/{course_uuid}/members/{user_uuid}
Authorization: Bearer <token>

成功 204
失败:
  404  用户或成员关系不存在
  400  {"detail": "Cannot remove course teacher"}
  403  只有本课程教师或 admin 可移除
```

---

## 4. 单元模块 `/{course_uuid}/units`

嵌套在 `/api/courses/` 路径下。

### 4.1 创建单元

```
POST /api/courses/{course_uuid}/units
Authorization: Bearer <token>
Content-Type: application/json

{
    "name": "第一次作业",
    "weight": 0.2,
    "full_score": 100.0,
    "unit_order": 1
}

成功 201:
{
    "id": 1,
    "name": "第一次作业",
    "weight": 0.2,
    "full_score": 100.0,
    "unit_order": 1,
    "created_at": "2026-01-01T00:00:00"
}

失败:
  409  {"detail": "Unit name already exists in this course"}
  403  只有本课程教师或 admin
```

### 4.2 列出单元

```
GET /api/courses/{course_uuid}/units
Authorization: Bearer <token>

成功 200: [ UnitOut, ... ]     // 按 unit_order 升序
```

### 4.3 更新单元

```
PATCH /api/courses/{course_uuid}/units/{unit_id}
Authorization: Bearer <token>
Content-Type: application/json

// unit_id 是整数，不是 UUID
{
    "name": "期中考试",    // 可选
    "weight": 0.3,         // 可选
    "full_score": 120.0,   // 可选
    "unit_order": 2        // 可选
}

成功 200: UnitOut
失败:
  404  {"detail": "Unit not found"}
  409  {"detail": "Unit name already exists in this course"}
```

### 4.4 删除单元

```
DELETE /api/courses/{course_uuid}/units/{unit_id}
Authorization: Bearer <token>

成功 204
注意: 级联删除该单元下所有成绩记录
```

### 4.5 批量调整排序

```
POST /api/courses/{course_uuid}/units/reorder
Authorization: Bearer <token>
Content-Type: application/json

[
    { "unit_id": 1, "unit_order": 3 },
    { "unit_id": 2, "unit_order": 1 },
    { "unit_id": 3, "unit_order": 2 }
]

成功 204
```

---

## 5. 成绩模块 `/api/scores`

### 5.1 录入单条成绩

```
POST /api/scores/
Authorization: Bearer <token>
Content-Type: application/json

{
    "course_uuid": "c1c2c3d4-...",
    "student_uuid": "u1u2u3d4-...",   // user 的 uuid，不是 student 表的 id
    "unit_id": 1,                     // 整数
    "score": 85.5
}

成功 201:
{
    "student_uuid": "u1-...",
    "student_no": "2024010101",
    "real_name": "张三",
    "course_uuid": "c1-...",
    "unit_id": 1,
    "unit_name": "第一次作业",
    "score": 85.5,
    "updated_at": "2026-01-01T00:00:00"
}

说明:
  INSERT ... ON DUPLICATE KEY UPDATE
  同一学生 + 同一课程 + 同一单元 只保留一条成绩
  再调一次同接口即为更新
```

### 5.2 批量录入

```
POST /api/scores/batch
Authorization: Bearer <token>
Content-Type: application/json

{
    "course_uuid": "c1-...",
    "unit_id": 1,
    "scores": [
        { "student_uuid": "u1-...", "score": 85 },
        { "student_uuid": "u2-...", "score": 92 },
        { "student_uuid": "u3-...", "score": 78 }
    ]
}

成功 204
注意: 逐条执行，某条失败不影响其他
```

### 5.3 查看我的成绩

```
GET /api/scores/course/{course_uuid}/my
Authorization: Bearer <token>

成功 200:
{
    "course_name": "C++ 程序设计",
    "units": [
        { "id": 1, "name": "第一次作业", "weight": 0.2, "full_score": 100.0, ... },
        ...
    ],
    "my_scores": [
        { "unit_id": 1, "score": 85.5 },
        { "unit_id": 2, "score": 70.0 },
        { "unit_id": 3, "score": null }        // null = 未录入
    ],
    "weighted_total": null,                     // 有 null 时无法计算
    "rank": null
}
```

### 5.4 成绩汇总（教师）

```
GET /api/scores/course/{course_uuid}/summary
Authorization: Bearer <token>

成功 200:
{
    "course_name": "C++ 程序设计",
    "unit_names": ["第一次作业", "期中考试", "期末考试"],
    "unit_weights": [0.2, 0.3, 0.5],
    "students": [
        {
            "student_uuid": "u1-...",
            "student_no": "2024010101",
            "real_name": "张三",
            "scores": [85.5, 70.0, 108.0],
            "weighted_total": 82.5,
            "rank": 3
        },
        ...
    ]
}

加权总分 = Σ (score / full_score × 100 × weight) / Σ weight
排名从 1 开始，未录完的学生排在最后（weighted_total 和 rank 为 null）
```

### 5.5 成绩分布

```
GET /api/scores/course/{course_uuid}/distribution
Authorization: Bearer <token>

成功 200:
{
    "bands": [
        { "range": "90-100", "count": 12 },
        { "range": "80-89",  "count": 20 },
        { "range": "70-79",  "count": 8 },
        { "range": "60-69",  "count": 4 },
        { "range": "0-59",   "count": 1 }
    ],
    "total": 45,
    "average": 82.3,
    "median": 84.0,
    "passed": 44,          // >= 60 分
    "failed": 1
}
```

---

## 6. 视频模块 `/api/videos`

### 6.1 创建视频元数据

```
POST /api/videos/
Authorization: Bearer <token>
Content-Type: application/json

{
    "course_uuid": "c1c2c3d4-...",
    "title": "第一节：环境配置",
    "description": "开发环境安装",
    "file_path": "/srv/edu/uploads/videos/xxx.mp4",
    "cover_path": "/srv/edu/uploads/covers/xxx.jpg",   // 可选
    "duration": 1200,                                    // 秒
    "file_size": 104857600                               // 字节
}

成功 201:
{
    "uuid": "v1v2v3d4-...",
    "title": "第一节：环境配置",
    "description": "...",
    "course_uuid": "c1-...",
    "course_name": "C++ 程序设计",
    "duration": 1200,
    "file_size": 104857600,
    "has_cover": true,
    "status": "normal",
    "created_at": "2026-01-01T00:00:00"
}

说明: 先调 7.1 上传文件 → 拿到 file_path → 再调此接口入库
```

### 6.2 获取课程视频列表

```
GET /api/videos/course/{course_uuid}
Authorization: Bearer <token>

成功 200: [ VideoOut, ... ]
```

### 6.3 获取视频详情

```
GET /api/videos/{video_uuid}
Authorization: Bearer <token>

成功 200:
{
    "uuid": "v1v2v3d4-...",
    "title": "第一节：环境配置",
    "description": "...",
    "course_uuid": "c1-...",
    "course_name": "C++ 程序设计",
    "uploader": { "uuid": "...", "username": "teacher1" },
    "duration": 1200,
    "file_size": 104857600,
    "cover_url": "/api/files/cover/v1v2v3d4-...",
    "status": "normal",
    "my_progress": {
        "progress": 300,
        "completed": false
    },
    "created_at": "2026-01-01T00:00:00"
}
```

### 6.4 视频流播放

```
GET /api/videos/{video_uuid}/stream
Authorization: Bearer <token>

这不是 JSON 接口，返回的是视频文件的二进制字节流。

成功 200:
  Content-Type: video/mp4
  响应体: 视频文件的二进制内容

HTTP Range 请求（拖动进度条）:
  GET /api/videos/{video_uuid}/stream
  Authorization: Bearer <token>
  Range: bytes=1048576-              // 从第 1MB 位置开始

  成功 206 (Partial Content):
    Content-Range: bytes 1048576-104857599/104857600
    Content-Length: 103809024
    响应体: 从 1MB 位置开始的字节

生产环境原理:
  1. 客户端请求 /api/videos/{uuid}/stream
  2. FastAPI 校验 JWT + 课程权限
  3. FastAPI 在响应头中设置 X-Accel-Redirect → 指向文件在磁盘上的位置
  4. Nginx 拦截该头，接管连接，直接 sendfile() 发送文件
  5. Nginx 原生支持 Range 请求，拖动进度条无需后端参与

开发环境（无 Nginx）:
  FastAPI 直接返回文件二进制流（小文件可行，大文件性能差）
```

### 6.5 更新视频信息

```
PATCH /api/videos/{video_uuid}
Authorization: Bearer <token>
Content-Type: application/json

{
    "title": "新标题",
    "description": "新描述",
    "status": "hidden"           // "normal" | "hidden" | "deleted"
}

成功 200: VideoOut
```

### 6.6 删除视频

```
DELETE /api/videos/{video_uuid}
Authorization: Bearer <token>

成功 204
说明: 逻辑删除 status → "deleted"，不删文件
```

---

## 7. 文件上传 `/api/files`

### 7.1 上传视频文件（multipart/form-data）

```
POST /api/files/upload/video
Authorization: Bearer <token>
Content-Type: multipart/form-data; boundary=----FormBoundary

----FormBoundary
Content-Disposition: form-data; name="file"; filename="lecture1.mp4"
Content-Type: video/mp4

<视频文件二进制内容>
----FormBoundary
Content-Disposition: form-data; name="course_uuid"

c1c2c3d4-e5f6-7890-abcd-ef1234567890
----FormBoundary--

限制:
  文件类型: mp4 / avi / mov / mkv / webm / flv
  文件大小: 最大 500 MB

成功 201:
{
    "file_path": "/srv/edu/uploads/videos/uuid-xxx.mp4",
    "file_size": 104857600,
    "original_name": "lecture1.mp4"
}

// 拿到 file_path 后用 6.1 创建视频元数据记录

失败:
  400  MIME 类型不支持
  413  文件超过 500 MB
  403  不是该课程教师
```

### 7.2 上传封面

```
POST /api/files/upload/cover
Authorization: Bearer <token>
Content-Type: multipart/form-data

表单字段:
  file: <图片二进制内容>

限制:
  文件类型: jpg / jpeg / png / webp
  文件大小: 最大 10 MB

成功 201:
{
    "file_path": "/srv/edu/uploads/covers/uuid-xxx.jpg",
    "file_size": 204800,
    "original_name": "cover.jpg"
}
```

### 7.3 获取封面（无需鉴权）

```
GET /api/files/cover/{video_uuid}

公开接口，不需要 Authorization header。

成功:
  HTTP 200
  Content-Type: image/jpeg
  响应体: 图片二进制内容
```

---

## 8. 播放记录 `/api/play-records`

### 8.1 上报播放进度

```
POST /api/play-records/update
Authorization: Bearer <token>
Content-Type: application/json

{
    "video_uuid": "v1v2v3d4-...",
    "progress": 300,              // 秒
    "completed": false
}

成功 200:
{
    "video_uuid": "v1v2v3d4-...",
    "progress": 300,
    "completed": false,
    "last_played_at": "2026-01-01T12:30:00"
}

建议上报策略:
  - 每 15-30 秒自动上报一次（不是每秒）
  - 手动暂停时立即上报
  - 关闭播放器 / 切换视频时上报最后一次
  - 播放到末尾时 completed = true
```

### 8.2 查询播放记录

```
GET /api/play-records/{video_uuid}
Authorization: Bearer <token>

成功 200 (有记录):
{
    "video_uuid": "v1-...",
    "progress": 300,
    "completed": false,
    "last_played_at": "2026-01-01T12:30:00"
}

成功 200 (从未播放):
{
    "video_uuid": "v1-...",
    "progress": 0,
    "completed": false,
    "last_played_at": null
}
```

### 8.3 课程播放统计

```
GET /api/play-records/course/{course_uuid}/my
Authorization: Bearer <token>

成功 200:
[
    {
        "video_uuid": "v1-...",
        "video_title": "第一节：环境配置",
        "progress": 300,
        "duration": 1200,
        "completed": false,
        "last_played_at": "2026-01-01T12:30:00"
    },
    ...
]
```

---

## 9. 错误处理

### 9.1 通用错误响应格式

```
HTTP 状态码 + JSON body:
{"detail": "具体错误消息"}
```

### 9.2 错误码速查

| 状态码 | 含义 | 触发场景 |
|--------|------|---------|
| 200 | OK | GET/PATCH 成功 |
| 201 | Created | POST 创建成功 |
| 204 | No Content | DELETE 成功 |
| 400 | Bad Request | 参数格式错误 |
| 401 | Unauthorized | token 无效/过期/缺失 |
| 403 | Forbidden | 角色/课程权限不够 |
| 404 | Not Found | UUID 找不到对应资源 |
| 409 | Conflict | 用户名/单元名/成员重复 |
| 413 | Payload Too Large | 上传文件超过大小限制（视频 500MB / 封面 10MB） |
| 422 | Unprocessable | Pydantic 参数校验失败（开发阶段常见） |
| 500 | Internal Server | 数据库异常、Python 异常 |

### 9.3 Token 过期处理流程

```
任何请求收到 401:
  1. 清空当前 token
  2. 跳转到登录界面
  3. 用户重新登录拿到新 token
  4. 用新 token 重试刚才失败的请求
```

### 9.4 应用启动 Token 检查

```
启动时:
  1. 从本地存储读取 token
  2. 用 GET /api/users/me 验证
     - 200 → token 有效，进入主界面，用返回的 role 决定功能权限
     - 401 → token 过期，跳到登录页
  3. 没有本地 token → 直接显示登录页
```

---

## 10. 完整端到端流程（curl）

```bash
HOST="http://127.0.0.1:55555"
# 生产环境: HOST="https://edu.your-domain.com"

# 1. 注册
curl -s -X POST $HOST/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"teacher1","password":"123456","role":"teacher"}' | jq

# 2. 登录
TOKEN=$(curl -s -X POST $HOST/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"teacher1","password":"123456"}' | jq -r '.access_token')

# 3. 获取当前用户
curl -s $HOST/api/users/me -H "Authorization: Bearer $TOKEN" | jq

# 4. 创建课程
COURSE=$(curl -s -X POST $HOST/api/courses/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"C++ 程序设计","description":"基础"}' | jq)
COURSE_UUID=$(echo $COURSE | jq -r '.uuid')

# 5. 创建单元
curl -s -X POST $HOST/api/courses/$COURSE_UUID/units \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"第一次作业","weight":0.2,"full_score":100,"unit_order":1}' | jq

# 6. 上传视频
UPLOAD=$(curl -s -X POST $HOST/api/files/upload/video \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@/path/to/video.mp4" \
  -F "course_uuid=$COURSE_UUID" | jq)
FILE_PATH=$(echo $UPLOAD | jq -r '.file_path')

# 7. 创建视频元数据
VIDEO=$(curl -s -X POST $HOST/api/videos/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"course_uuid\":\"$COURSE_UUID\",\"title\":\"第一节\",\"file_path\":\"$FILE_PATH\",\"duration\":1200,\"file_size\":104857600}" | jq)

# 8. 上报播放进度
VIDEO_UUID=$(echo $VIDEO | jq -r '.uuid')
curl -s -X POST $HOST/api/play-records/update \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"video_uuid\":\"$VIDEO_UUID\",\"progress\":300,\"completed\":false}" | jq
```

---

## 11. 接口速查表

| 操作 | 方法 | URL | Token | Body 类型 |
|------|------|-----|-------|----------|
| 注册 | POST | `/api/auth/register` | 不需要 | JSON |
| 登录 | POST | `/api/auth/login` | 不需要 | JSON |
| 当前用户 | GET | `/api/users/me` | 需要 | 无 |
| 改用户名 | PATCH | `/api/users/me` | 需要 | JSON |
| 创建课程 | POST | `/api/courses/` | 需要 | JSON |
| 课程列表 | GET | `/api/courses/` | 需要 | 无 |
| 课程详情 | GET | `/api/courses/{uuid}` | 需要 | 无 |
| 更新课程 | PATCH | `/api/courses/{uuid}` | 需要 | JSON |
| 删除课程 | DELETE | `/api/courses/{uuid}` | 需要 | 无 |
| 成员列表 | GET | `/api/courses/{uuid}/members` | 需要 | 无 |
| 添加成员 | POST | `/api/courses/{uuid}/members` | 需要 | JSON |
| 移除成员 | DELETE | `/api/courses/{uuid}/members/{uuid}` | 需要 | 无 |
| 创建单元 | POST | `/api/courses/{uuid}/units` | 需要 | JSON |
| 单元列表 | GET | `/api/courses/{uuid}/units` | 需要 | 无 |
| 更新单元 | PATCH | `/api/courses/{uuid}/units/{id}` | 需要 | JSON |
| 删除单元 | DELETE | `/api/courses/{uuid}/units/{id}` | 需要 | 无 |
| 录入成绩 | POST | `/api/scores/` | 需要 | JSON |
| 批量成绩 | POST | `/api/scores/batch` | 需要 | JSON |
| 我的成绩 | GET | `/api/scores/course/{uuid}/my` | 需要 | 无 |
| 成绩汇总 | GET | `/api/scores/course/{uuid}/summary` | 需要 | 无 |
| 成绩分布 | GET | `/api/scores/course/{uuid}/distribution` | 需要 | 无 |
| 创建视频 | POST | `/api/videos/` | 需要 | JSON |
| 视频列表 | GET | `/api/videos/course/{uuid}` | 需要 | 无 |
| 视频详情 | GET | `/api/videos/{uuid}` | 需要 | 无 |
| 视频流 | GET | `/api/videos/{uuid}/stream` | 需要 | 无 |
| 更新视频 | PATCH | `/api/videos/{uuid}` | 需要 | JSON |
| 删除视频 | DELETE | `/api/videos/{uuid}` | 需要 | 无 |
| 上传视频 | POST | `/api/files/upload/video` | 需要 | multipart |
| 上传封面 | POST | `/api/files/upload/cover` | 需要 | multipart |
| 获取封面 | GET | `/api/files/cover/{uuid}` | 不需要 | 无 |
| 播放进度 | POST | `/api/play-records/update` | 需要 | JSON |
| 查询进度 | GET | `/api/play-records/{uuid}` | 需要 | 无 |

---

## 12. HTTP 层面的技术要点

### 12.1 请求方法

本 API 使用了 4 种 HTTP 方法：

| 方法 | 语义 | 示例 |
|------|------|------|
| GET | 读取资源 | 列表、详情、搜索 |
| POST | 创建资源或触发动作 | 注册、登录、录入成绩、上传文件 |
| PATCH | 局部更新资源 | 改用户名、改课程名、改单元信息 |
| DELETE | 删除资源（逻辑删除） | 删课程、删视频、移除成员 |

注意：**没有用 PUT**。所有更新都走 PATCH（局部更新）。

### 12.2 响应状态码约定

```
2xx = 成功
  200 OK          — GET / PATCH 返回数据
  201 Created     — POST 创建资源
  204 No Content  — DELETE 成功，不返回 body

4xx = 客户端错误
  400 Bad Request — 参数格式错误
  401 Unauthorized — token 问题
  403 Forbidden   — 权限不足
  404 Not Found   — 资源不存在
  409 Conflict    — 重复
  413 Too Large   — 文件过大
  422 Unprocessable — 参数校验失败（FastAPI 自动）

5xx = 服务端错误
  500 Internal Server Error
```

### 12.3 数组响应

部分接口（课程列表、视频列表、成员列表）的顶层是 JSON 数组而非对象：

```
HTTP/1.1 200 OK
Content-Type: application/json

[
    {...},
    {...}
]
```

解析时注意根节点是 `[` 不是 `{`。

### 12.4 HTTP Range 与视频拖动

前端视频播放器在用户拖动进度条时，通常会自动发 Range 请求。你只需在初始请求时带 `Authorization` header，后续 Range 请求也需要同样的 header。

**Nginx 场景（生产）**：Range 请求由 Nginx 直接处理，因为 X-Accel-Redirect 之后是 Nginx 在发文件。Nginx 不检查 Authorization，但 `/internal/video/` 路径有 `internal;` 指令，外部无法直接访问。

### 12.5 multipart/form-data 上传

文件上传不是 JSON，是 HTTP multipart 格式。原始报文结构：

```
POST /api/files/upload/video HTTP/1.1
Host: 127.0.0.1:55555
Authorization: Bearer eyJ...
Content-Type: multipart/form-data; boundary=----FormBoundary7MA4YWxk
Content-Length: 104857800

------FormBoundary7MA4YWxk
Content-Disposition: form-data; name="file"; filename="lecture.mp4"
Content-Type: video/mp4

<文件字节流>
------FormBoundary7MA4YWxk
Content-Disposition: form-data; name="course_uuid"

c1c2c3d4-e5f6-...
------FormBoundary7MA4YWxk--
```

---

## 13. HTTPS 专项说明

### 13.1 为什么需要 HTTPS

HTTP 明文传输的致命问题：

```
客户端 ──── 互联网 ──── 服务端
         ↑
    中间人可以:
    - 偷看你的 token（Bearer token 在 HTTP 头里明文传输）
    - 偷看用户名密码（登录请求体明文）
    - 篡改请求/响应（比如把成绩改掉）
    - 冒充服务器（DNS 劫持）
```

HTTPS = HTTP + TLS，在 TCP 之上加密所有 HTTP 流量。

### 13.2 部署架构差异

```
HTTP 开发环境:
  客户端 ── TCP :55555 ──► FastAPI (uvicorn)
  客户端 ── TCP :80    ──► Nginx ── TCP :55555 ──► FastAPI

HTTPS 生产环境:
  客户端 ── TLS :443 ──► Nginx ── TCP :55555 ──► FastAPI
         │                      │
         └── 加密段 ──────────┘ └── 内网明文段
```

TLS 终点在 Nginx，Nginx 和 FastAPI 之间走内网 HTTP（明文，安全）。

### 13.3 客户端切换清单

从 HTTP 切到 HTTPS，客户端需要做的具体事：

```
1. 改 Base URL
   http://127.0.0.1:55555  →  https://edu.your-domain.com

2. 端口变化
   55555 或 80  →  443（HTTPS 默认端口，URL 里一般省略）

3. TLS 握手
   客户端操作系统/TCP 栈自动处理，业务代码基本无感
   但需要确保:
   - 系统时间正确（证书有效期校验依赖本地时间）
   - 操作系统内置了 CA 根证书（Let's Encrypt 的 ISRG Root X1 一般已内置）
   - 不要手动禁用证书校验（除非是自签名证书开发阶段）

4. 证书校验
   生产环境 CA 证书 → 系统自动验证，无需额外代码
   开发环境自签名  → 见 13.4

5. HTTP/2
   Nginx 支持 HTTP/2，TLS 握手时自动协商
   多路复用减少连接数，视频列表加载更快
```

**API 路径、请求头、请求体、响应格式完全不变。** Base URL 是唯一需要改的地方。

### 13.4 自签名证书（开发阶段）

如果开发环境想测试 HTTPS 但没有域名和 CA 证书：

```bash
# 生成自签名证书
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/edu-dev-key.pem \
  -out /etc/nginx/ssl/edu-dev-cert.pem \
  -subj "/CN=localhost"

# Nginx 配置
server {
    listen 443 ssl;
    server_name localhost;
    ssl_certificate     /etc/nginx/ssl/edu-dev-cert.pem;
    ssl_certificate_key /etc/nginx/ssl/edu-dev-key.pem;
    # ... 其他配置
}
```

此时客户端连接会收到 **证书不受信任** 的错误，因为自签名证书不在系统信任链中。

客户端应对方式（仅限开发）：

```
方式一: 全局忽略证书校验（最简单，也是最危险的）
  开发阶段快速跑通时可用，绝不能出现在生产代码中

方式二: 手动导入自签名证书到系统信任链
  - Linux: sudo cp cert.pem /etc/ca-certificates/trust-source/anchors/ && sudo trust extract-compat
  - Windows: certmgr.msc → 受信任的根证书颁发机构 → 导入
  - macOS: sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain cert.pem

方式三: 在代码中仅信任这一张证书（比方式一安全）
  验证时只接受这个特定的证书指纹，其他一律拒绝
```

生产环境用 Let's Encrypt 免费证书即可，客户端无感知。

### 13.5 Let's Encrypt 生产部署

```bash
# 安装 certbot
sudo pacman -S certbot certbot-nginx    # Arch Linux
sudo apt install certbot python3-certbot-nginx  # Ubuntu/Debian

# 自动配置 Nginx + 获取证书
sudo certbot --nginx -d edu.your-domain.com

# 证书位置
# /etc/letsencrypt/live/edu.your-domain.com/fullchain.pem
# /etc/letsencrypt/live/edu.your-domain.com/privkey.pem

# 自动续期（已内置 systemd timer）
sudo systemctl enable certbot-renew.timer
```

### 13.6 Nginx HTTPS 完整配置

```nginx
# HTTP → HTTPS 重定向
server {
    listen 80;
    server_name edu.your-domain.com;
    return 301 https://$host$request_uri;
}

# HTTPS 主服务
server {
    listen 443 ssl http2;
    server_name edu.your-domain.com;

    ssl_certificate     /etc/letsencrypt/live/edu.your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/edu.your-domain.com/privkey.pem;

    # TLS 安全配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;

    # 安全响应头
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options SAMEORIGIN;

    # ... API 反向代理配置（同 HTTP 版，无变化） ...
}
```

`Strict-Transport-Security` (HSTS) 告诉浏览器：未来所有请求强制走 HTTPS，不允许降级到 HTTP。

### 13.7 Token 在 HTTP vs HTTPS 下的安全性对比

```
HTTP 场景:
  客户端 ── GET /api/users/me ──────────────────────► 服务端
          Authorization: Bearer eyJ...
          ^^^^^^^^^^^^^^^^^^^^^^^^^ 明文！任何中间路由/代理都能看到

HTTPS 场景:
  客户端 ── GET /api/users/me ──────────────────────► 服务端
          ┌── TLS 加密层 ──────────────────────────┐
          │ Authorization: Bearer eyJ...            │
          │ 请求体: {"password":"123456"}            │
          └─────────────────────────────────────────┘
          整个 HTTP 报文被加密，中间人什么都看不到
```

**生产环境必须用 HTTPS**，否则 Bearer Token 和登录密码都是明文在网络中裸奔。

### 13.8 客户端库层面的差异

无论你用 Qt Network、libcurl、WinHTTP、NSURLSession 还是 OkHttp：

```
HTTP:
  Base URL = "http://..."
  直接建立 TCP 连接，发送 HTTP 报文

HTTPS:
  Base URL = "https://..."
  先 TLS 握手（自动），然后发送 HTTP 报文
  需要处理证书校验失败的情况（自签名证书）
  其余 API 调用逻辑完全一样
```

所有 HTTP 客户端库都把 TLS 透明化了——你发的是 HTTP 请求，库在底层自动加上 TLS 加密。你的业务代码不需要任何 `if (https) { ... } else { ... }` 分支。
