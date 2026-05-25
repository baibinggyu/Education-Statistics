# Edu Server — API 路由设计

全部 API 端点详细规格。

---

## 1. Auth Router — `/api/auth`

### POST /api/auth/register

注册新用户。

```
Request:
{
  "username": "teacher1",        // VARCHAR(64), 必填
  "password": "123456",          // 明文, 必填, 后端 hash 后存储
  "role": "teacher"              // "student" | "teacher" | "admin"
}

Response 201:
{
  "uuid": "a1b2c3d4-...",
  "username": "teacher1",
  "role": "teacher"
}

Errors:
  400 — 用户名已存在 / 角色非法
  422 — 参数校验失败
```

### POST /api/auth/login

用户登录，返回 JWT。

```
Request:
{
  "username": "teacher1",
  "password": "123456"
}

Response 200:
{
  "access_token": "eyJhbGciOi...",
  "token_type": "bearer"
}

Errors:
  401 — 用户名或密码错误
  403 — 用户已被禁用 (status != 1)
```

### POST /api/auth/refresh

刷新过期的 access token (第二阶段实现)。

```
Request: (无需 body, 从 Authorization header 取旧 token)

Response 200:
{
  "access_token": "eyJhbGciOi...",
  "token_type": "bearer"
}
```

---

## 2. Users Router — `/api/users`

### GET /api/users/me

获取当前登录用户信息。

```
Headers: Authorization: Bearer <token>

Response 200:
{
  "uuid": "a1b2c3d4-...",
  "username": "teacher1",
  "role": "teacher",
  "created_at": "2026-01-01T00:00:00",

  // 如果是 student 角色，附加学生档案
  "student": {
    "student_no": "2024010101",
    "real_name": "小明"
  }
}
```

### PATCH /api/users/me

更新当前用户信息。

```
Request:
{
  "username": "new_name"     // 可选
}

Response 200: UserOut
```

### GET /api/users/

管理员列出所有用户 (第二阶段)。

```
Query: ?page=1&size=20&role=student&status=1

Response 200:
{
  "items": [ UserOut, ... ],
  "total": 150,
  "page": 1,
  "size": 20
}

权限: admin only
```

### PATCH /api/users/{user_uuid}/status

管理员禁用/启用用户 (第二阶段)。

```
Request:
{
  "status": 0       // 0=禁用, 1=正常
}

权限: admin only
```

---

## 3. Students Router — `/api/students`

### POST /api/students/bind

将当前登录用户绑定到学生档案 (注册时如果 role=student 会自动创建)。

```
Request:
{
  "student_no": "2024010101",
  "real_name": "小明"
}

Response 201:
{
  "user_uuid": "a1b2c3d4-...",
  "student_no": "2024010101",
  "real_name": "小明"
}

权限: 仅 student 角色
```

### GET /api/students/{user_uuid}

获取学生档案。

```
Response 200:
{
  "user_uuid": "...",
  "student_no": "2024010101",
  "real_name": "小明",
  "course_count": 8,           // 加入的课程数
  "video_completed_count": 12  // 完成的视频数
}

权限: 本人 或 teacher/admin
```

### GET /api/students/

分页列出所有学生 (第二阶段)。

```
Query: ?page=1&size=20&course_uuid=xxx&search=小明

权限: teacher/admin
```

---

## 4. Courses Router — `/api/courses`

### POST /api/courses/

创建课程。

```
Request:
{
  "name": "C++ 程序设计",
  "description": "面向对象程序设计基础"
}

Response 201:
{
  "uuid": "c1c2c3d4-...",
  "name": "C++ 程序设计",
  "description": "面向对象程序设计基础",
  "teacher": {
    "uuid": "...",
    "username": "teacher1"
  },
  "status": "normal",
  "created_at": "2026-01-01T00:00:00"
}

权限: teacher / admin
副作用: 创建者自动加入 course_members (role=teacher)
```

### GET /api/courses/

列出当前用户参与的课程。

```
Query: ?status=normal

Response 200:
[
  {
    "uuid": "c1c2c3d4-...",
    "name": "C++ 程序设计",
    "description": "...",
    "teacher": { "uuid": "...", "username": "teacher1" },
    "member_count": 45,
    "video_count": 12,
    "my_role": "teacher"           // 当前用户在该课程中的角色
  },
  ...
]

权限: 任何已登录用户
```

### GET /api/courses/{course_uuid}

获取单个课程详情。

```
Response 200:
{
  "uuid": "...",
  "name": "...",
  "description": "...",
  "teacher": { ... },
  "status": "normal",
  "units": [                        // 单元列表 (按 unit_order 排序)
    { "id": 1, "name": "第一次作业", "weight": 0.2, "full_score": 100 },
    ...
  ],
  "member_count": 45,
  "created_at": "2026-01-01T00:00:00"
}

权限: 课程成员 或 admin
```

### PATCH /api/courses/{course_uuid}

更新课程信息。

```
Request:
{
  "name": "新名称",       // 可选
  "description": "新描述"  // 可选
}

权限: 课程的 teacher 或 admin
```

### DELETE /api/courses/{course_uuid}

逻辑删除课程 (status → deleted)。

```
权限: 课程的 teacher 或 admin
副作用: course_members 保留，units 保留，scores 保留
```

---

## 5. Course Members — `/api/courses/{course_uuid}/members`

### GET /api/courses/{course_uuid}/members

列出课程成员。

```
Query: ?role=student

Response 200:
[
  {
    "user_uuid": "...",
    "username": "student1",
    "member_role": "student",
    "joined_at": "2026-01-01T00:00:00",
    "student": {                        // 仅在 role=student 时返回
      "student_no": "2024010101",
      "real_name": "张三"
    }
  }
]

权限: 课程成员
```

### POST /api/courses/{course_uuid}/members

添加成员 (按用户名或学号)。

```
Request:
{
  "username": "student1"       // 或者 "student_no": "2024010101"
}

Response 201:
{
  "user_uuid": "...",
  "member_role": "student",
  "joined_at": "2026-01-01T00:00:00"
}

权限: 课程的 teacher 或 admin
```

### DELETE /api/courses/{course_uuid}/members/{user_uuid}

移除课程成员。

```
权限: 课程的 teacher 或 admin
```

---

## 6. Units Router — `/api/courses/{course_uuid}/units`

### POST /api/courses/{course_uuid}/units

在课程下创建新单元。

```
Request:
{
  "name": "第一次作业",        // 必填, VARCHAR(128)
  "weight": 0.2,               // 权重, 默认 0
  "full_score": 100,           // 满分, 默认 100
  "unit_order": 1              // 排序, 默认 0
}

Response 201:
{
  "id": 1,
  "name": "第一次作业",
  "weight": 0.2,
  "full_score": 100,
  "unit_order": 1,
  "created_at": "2026-01-01T00:00:00"
}

权限: 课程的 teacher 或 admin
```

### GET /api/courses/{course_uuid}/units

列出课程下的所有单元 (按 unit_order 排序)。

```
Response 200: [ UnitOut, ... ]

权限: 课程成员
```

### PATCH /api/courses/{course_uuid}/units/{unit_id}

更新单元信息。

```
Request:
{
  "name": "期中考试",      // 可选
  "weight": 0.3,            // 可选
  "full_score": 120,        // 可选
  "unit_order": 2           // 可选
}

权限: 课程的 teacher 或 admin
```

### DELETE /api/courses/{course_uuid}/units/{unit_id}

删除单元 (物理删除，需先删除关联 scores)。

```
权限: 课程的 teacher 或 admin
副作用: 对应 scores 行级联删除
```

### POST /api/courses/{course_uuid}/units/reorder

批量调整单元排序 (第二阶段)。

```
Request:
[
  { "unit_id": 1, "unit_order": 1 },
  { "unit_id": 2, "unit_order": 2 },
  { "unit_id": 3, "unit_order": 3 }
]

权限: 课程的 teacher 或 admin
```

---

## 7. Scores Router — `/api/scores`

### POST /api/scores/

录入单条成绩。

```
Request:
{
  "course_uuid": "c1c2c3d4-...",
  "student_uuid": "a1b2c3d4-...",
  "unit_id": 1,
  "score": 85.5
}

Response 201:
{
  "student_uuid": "...",
  "student_no": "2024010101",
  "real_name": "张三",
  "course_uuid": "...",
  "unit_id": 1,
  "unit_name": "第一次作业",
  "score": 85.5,
  "updated_at": "2026-01-01T00:00:00"
}

权限: 课程的 teacher 或 admin
规则: INSERT ... ON DUPLICATE KEY UPDATE (一个学生在一个单元只有一条成绩)
```

### POST /api/scores/batch

批量录入成绩 (第二阶段)。

```
Request:
{
  "course_uuid": "c1c2c3d4-...",
  "unit_id": 1,
  "scores": [
    { "student_uuid": "...", "score": 85 },
    { "student_uuid": "...", "score": 92 },
    ...
  ]
}

权限: 课程的 teacher 或 admin
```

### GET /api/scores/course/{course_uuid}/my

获取当前用户在某课程中的所有成绩。

```
Response 200:
{
  "course_name": "C++ 程序设计",
  "units": [
    { "unit_id": 1, "name": "第一次作业", "weight": 0.2, "full_score": 100 },
    { "unit_id": 2, "name": "期中考试", "weight": 0.3, "full_score": 100 },
    ...
  ],
  "my_scores": [
    { "unit_id": 1, "score": 85.5 },
    { "unit_id": 2, "score": null },     // 未录入
    ...
  ],
  "weighted_total": null,                 // 全部录入后才计算
  "rank": null
}

权限: student (只看自己的) 或 teacher/admin
```

### GET /api/scores/course/{course_uuid}/summary

获取课程成绩汇总 (所有学生)。

```
Response 200:
{
  "course_name": "C++ 程序设计",
  "unit_names": ["第一次作业", "期中考试", "期末考试"],
  "unit_weights": [0.2, 0.3, 0.5],
  "students": [
    {
      "student_uuid": "...",
      "student_no": "2024010101",
      "real_name": "张三",
      "scores": [85, 70, 90],
      "weighted_total": 82.5,
      "rank": 3
    },
    ...
  ]
}

权限: 课程的 teacher 或 admin
```

### GET /api/scores/course/{course_uuid}/distribution

成绩分布统计 (第二阶段)。

```
Response 200:
{
  "bands": [
    { "range": "90-100", "count": 12 },
    { "range": "80-89", "count": 20 },
    { "range": "70-79", "count": 8 },
    { "range": "60-69", "count": 4 },
    { "range": "0-59", "count": 1 }
  ],
  "total": 45,
  "average": 82.3,
  "median": 84.0,
  "passed": 44,
  "failed": 1
}
```

### GET /api/scores/course/{course_uuid}/export

导出成绩为 XLSX 文件 (第二阶段)。

```
Response: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
列: 学号, 姓名, 单元1成绩, 单元2成绩, ..., 加权总分, 排名
```

---

## 8. Videos Router — `/api/videos`

### POST /api/videos/

创建视频元数据。

```
Request:
{
  "course_uuid": "c1c2c3d4-...",
  "title": "第一节：环境配置",
  "description": "开发环境安装与配置",
  "file_path": "/srv/edu/uploads/videos/uuid_xxx.mp4",
  "cover_path": "/srv/edu/uploads/covers/uuid_xxx.jpg",
  "duration": 1200,           // 秒
  "file_size": 104857600      // 字节 (100MB)
}

Response 201:
{
  "uuid": "v1v2v3d4-...",
  "title": "第一节：环境配置",
  "description": "...",
  "course_uuid": "...",
  "duration": 1200,
  "file_size": 104857600,
  "status": "normal",
  "created_at": "..."
}

权限: 课程的 teacher 或 admin
```

### GET /api/videos/course/{course_uuid}

列出课程下的所有视频。

```
Response 200:
[
  {
    "uuid": "...",
    "title": "第一节：环境配置",
    "description": "...",
    "duration": 1200,
    "file_size": 104857600,
    "has_cover": true,
    "my_progress": {                        // 当前用户的播放状态
      "progress": 300,                       // 已播放到 300 秒
      "completed": false
    }
  },
  ...
]

权限: 课程成员
```

### GET /api/videos/{video_uuid}

获取单个视频元数据。

```
Response 200:
{
  "uuid": "...",
  "title": "...",
  "description": "...",
  "course_uuid": "...",
  "course_name": "C++ 程序设计",
  "uploader": { "uuid": "...", "username": "teacher1" },
  "duration": 1200,
  "file_size": 104857600,
  "cover_url": "/api/files/cover/{video_uuid}",
  "status": "normal",
  "my_progress": { "progress": 300, "completed": false },
  "created_at": "..."
}

权限: 课程成员
```

### GET /api/videos/{video_uuid}/stream

视频流播放 (鉴权后 X-Accel-Redirect 到 Nginx)。

```
Headers: Authorization: Bearer <token>

流程:
  1. FastAPI 验证 JWT
  2. FastAPI 检查用户是否属于该视频所属的课程
  3. FastAPI 返回 X-Accel-Redirect: /internal/video/<文件路径>
  4. Nginx 拦截 X-Accel-Redirect，直接返回文件内容
  5. Nginx 自动支持 Range 请求 (视频拖动)

权限: 课程成员
```

### PATCH /api/videos/{video_uuid}

更新视频元数据。

```
Request:
{
  "title": "新标题",          // 可选
  "description": "新描述",     // 可选
  "status": "hidden"          // 可选
}

权限: 视频所属课程的 teacher 或 admin
```

### DELETE /api/videos/{video_uuid}

逻辑删除视频 (status → deleted)。

```
权限: 视频所属课程的 teacher 或 admin
```

---

## 9. Play Records Router — `/api/play-records`

### POST /api/play-records/update

更新播放进度 (INSERT ON DUPLICATE KEY UPDATE 模式)。

```
Request:
{
  "video_uuid": "v1v2v3d4-...",
  "progress": 300,              // 当前播放到的秒数
  "completed": false            // 是否已播完
}

Response 200:
{
  "video_uuid": "...",
  "progress": 300,
  "completed": false,
  "last_played_at": "2026-01-01T12:00:00"
}

权限: 登录用户 (且必须是视频所属课程的成员)
```

### GET /api/play-records/{video_uuid}

获取某视频的播放记录。

```
Response 200:
{
  "video_uuid": "...",
  "progress": 300,
  "completed": false,
  "last_played_at": "2026-01-01T12:00:00"
}

如果没有记录:
{
  "video_uuid": "...",
  "progress": 0,
  "completed": false,
  "last_played_at": null
}
```

### GET /api/play-records/course/{course_uuid}/my

获取某课程下我的所有播放记录 (第二阶段)。

```
Response 200:
[
  {
    "video_uuid": "...",
    "video_title": "第一节",
    "progress": 300,
    "duration": 1200,
    "completed": false,
    "last_played_at": "2026-01-01T12:00:00"
  },
  ...
]
```

---

## 10. Files Router — `/api/files`

### POST /api/files/upload/video

上传视频文件。

```
Content-Type: multipart/form-data
Fields:
  - file: <视频文件>           // 限制: mp4/avi/mov/mkv/webm/flv, ≤ 500MB
  - course_uuid: "xxx"        // 目标课程

Response 201:
{
  "file_path": "/srv/edu/uploads/videos/uuid_xxx.mp4",
  "file_size": 104857600,
  "original_name": "lecture1.mp4"
}

权限: teacher / admin (且必须是课程教师)
落盘: /srv/edu/uploads/videos/{new_uuid}.{ext}
```

### POST /api/files/upload/cover

上传视频封面。

```
Content-Type: multipart/form-data
Fields:
  - file: <图片文件>           // 限制: jpg/png/webp, ≤ 10MB

Response 201:
{
  "file_path": "/srv/edu/uploads/covers/uuid_xxx.jpg",
  "file_size": 204800
}

权限: teacher / admin
```

### GET /api/files/cover/{video_uuid}

获取视频封面图片。

```
返回: 图片二进制流 (image/jpeg 或 image/png)

权限: 公开 (封面不需要鉴权)
```

---

## 11. API 路由汇总表

| 方法 | 路径 | 权限 | 说明 |
|------|------|------|------|
| POST | `/api/auth/register` | 公开 | 注册 |
| POST | `/api/auth/login` | 公开 | 登录 |
| POST | `/api/auth/refresh` | 登录 | 刷新 token |
| GET | `/api/users/me` | 登录 | 当前用户 |
| PATCH | `/api/users/me` | 登录 | 更新用户信息 |
| GET | `/api/users/` | admin | 用户列表 |
| PATCH | `/api/users/{uuid}/status` | admin | 禁用/启用用户 |
| POST | `/api/students/bind` | student | 绑定学生档案 |
| GET | `/api/students/{user_uuid}` | 登录 | 学生详情 |
| GET | `/api/students/` | teacher/admin | 学生列表 |
| POST | `/api/courses/` | teacher/admin | 创建课程 |
| GET | `/api/courses/` | 登录 | 我的课程列表 |
| GET | `/api/courses/{uuid}` | 课程成员 | 课程详情 |
| PATCH | `/api/courses/{uuid}` | 课程教师 | 更新课程 |
| DELETE | `/api/courses/{uuid}` | 课程教师 | 逻辑删除课程 |
| GET | `/api/courses/{uuid}/members` | 课程成员 | 成员列表 |
| POST | `/api/courses/{uuid}/members` | 课程教师 | 添加成员 |
| DELETE | `/api/courses/{uuid}/members/{uuid}` | 课程教师 | 移除成员 |
| POST | `/api/courses/{uuid}/units` | 课程教师 | 创建单元 |
| GET | `/api/courses/{uuid}/units` | 课程成员 | 单元列表 |
| PATCH | `/api/courses/{uuid}/units/{id}` | 课程教师 | 更新单元 |
| DELETE | `/api/courses/{uuid}/units/{id}` | 课程教师 | 删除单元 |
| POST | `/api/courses/{uuid}/units/reorder` | 课程教师 | 单元排序 |
| POST | `/api/scores/` | 课程教师 | 录入成绩 |
| POST | `/api/scores/batch` | 课程教师 | 批量录入 |
| GET | `/api/scores/course/{uuid}/my` | 课程成员 | 我的成绩 |
| GET | `/api/scores/course/{uuid}/summary` | 课程教师 | 成绩汇总 |
| GET | `/api/scores/course/{uuid}/distribution` | 课程教师 | 成绩分布 |
| GET | `/api/scores/course/{uuid}/export` | 课程教师 | 导出 XLSX |
| POST | `/api/videos/` | 课程教师 | 创建视频 |
| GET | `/api/videos/course/{uuid}` | 课程成员 | 课程视频列表 |
| GET | `/api/videos/{uuid}` | 课程成员 | 视频详情 |
| GET | `/api/videos/{uuid}/stream` | 课程成员 | 视频流 |
| PATCH | `/api/videos/{uuid}` | 课程教师 | 更新视频 |
| DELETE | `/api/videos/{uuid}` | 课程教师 | 删除视频 |
| POST | `/api/play-records/update` | 登录 | 更新播放进度 |
| GET | `/api/play-records/{uuid}` | 登录 | 播放记录 |
| GET | `/api/play-records/course/{uuid}/my` | 登录 | 课程播放统计 |
| POST | `/api/files/upload/video` | teacher/admin | 上传视频文件 |
| POST | `/api/files/upload/cover` | teacher/admin | 上传封面 |
| GET | `/api/files/cover/{uuid}` | 公开 | 获取封面 |

**总计: 43 个端点 (第一阶段核心 20 个，第二阶段扩展 23 个)**
