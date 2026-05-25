
# Edu Server Database

EduServer 数据库结构设计文档。

数据库用于：

```txt id="o2h0ax"
用户系统
课程系统
成绩系统
在线视频系统
播放记录系统
```

数据库：

```txt id="d2v1bh"
MariaDB / MySQL
```

字符集：

```txt id="epd7di"
utf8mb4
```

---

# Database

```txt id="5mlcxr"
edu_server_database
```

---

# Tables

```txt id="n76cz1"
users
students
courses
course_members
units
scores
videos
play_records
```

---

# Overall Structure

```txt id="7xvkt6"
users
 ├── students
 ├── courses.teacher_id
 ├── course_members
 ├── videos.uploader_id
 └── play_records

courses
 ├── units
 ├── scores
 ├── videos
 └── course_members

students
 └── scores

videos
 └── play_records
```

---

# ID Design

系统统一采用：

```txt id="f4d2mp"
数据库内部：
BIGINT id

客户端公开：
UUID
```

数据库关联：

```txt id="rlcyxt"
全部使用 BIGINT id
```

客户端接口：

```txt id="kcr6h0"
全部使用 UUID
```

例如：

```txt id="gzxjlwm"
/api/videos/{uuid}
```

后端：

```sql id="r8b95o"
SELECT id
FROM videos
WHERE uuid = ?
```

之后内部继续使用：

```txt id="vll5kr"
BIGINT id
```

进行数据库关联。

---

# users

用户登录表。

## Purpose

保存：

```txt id="b6g67l"
登录身份
权限
密码
```

所有系统用户：

```txt id="hcsxmt"
student
teacher
admin
```

都属于：

```txt id="vdar5s"
users
```

---

## Fields

| Field         | Type         | Description |
| ------------- | ------------ | ----------- |
| id            | BIGINT       | 数据库内部主键     |
| uuid          | CHAR(36)     | 对外公开 UUID   |
| username      | VARCHAR(64)  | 登录用户名       |
| password_hash | VARCHAR(255) | 密码哈希        |
| role          | ENUM         | 用户角色        |
| status        | TINYINT      | 用户状态        |
| created_at    | DATETIME     | 创建时间        |

---

## Notes

密码不保存明文。

推荐：

```txt id="c95vug"
bcrypt
argon2
```

---

## Roles

```txt id="j6e7i9"
student
teacher
admin
```

---

# students

学生档案表。

---

## Purpose

保存：

```txt id="j2fg02"
学生真实信息
```

与：

```txt id="vjlwm3"
登录系统
```

解耦。

---

## Fields

| Field      | Type        | Description |
| ---------- | ----------- | ----------- |
| id         | BIGINT      | 学生档案主键      |
| user_id    | BIGINT      | 对应 users.id |
| student_no | VARCHAR(64) | 学号          |
| real_name  | VARCHAR(64) | 真实姓名        |
| created_at | DATETIME    | 创建时间        |

---

## Design

```txt id="xg2t9v"
users
    = 登录身份

students
    = 学生档案
```

允许：

```txt id="9ykpcr"
教师
管理员
```

不属于：

```txt id="x9nfr0"
students
```

---

# courses

课程表。

---

## Purpose

保存课程基础信息。

---

## Fields

| Field       | Type         | Description |
| ----------- | ------------ | ----------- |
| id          | BIGINT       | 内部主键        |
| uuid        | CHAR(36)     | 对外 UUID     |
| name        | VARCHAR(128) | 课程名称        |
| description | TEXT         | 课程描述        |
| teacher_id  | BIGINT       | 教师 ID       |
| status      | ENUM         | 状态          |
| created_at  | DATETIME     | 创建时间        |

---

## Status

```txt id="8aj0z8"
normal
hidden
deleted
```

---

## Design

采用：

```txt id="b5m2ck"
逻辑删除
```

而不是：

```sql id="byj9h0"
DELETE
```

避免：

```txt id="4smr4w"
成绩
视频
播放记录
```

丢失关联。

---

# course_members

课程成员表。

---

## Purpose

维护：

```txt id="fwd5ut"
课程 ↔ 用户
```

关系。

---

## Fields

| Field       | Type     | Description |
| ----------- | -------- | ----------- |
| course_id   | BIGINT   | 课程 ID       |
| user_id     | BIGINT   | 用户 ID       |
| member_role | ENUM     | 成员角色        |
| created_at  | DATETIME | 加入时间        |

---

## Unique Key

```txt id="8jwsyh"
(course_id, user_id)
```

保证：

```txt id="ahjlwm"
同一用户不会重复加入课程
```

---

## Typical Usage

用于判断：

```txt id="1u2d5l"
用户是否属于某课程
```

例如：

* 是否允许观看视频
* 是否允许查看成绩
* 是否允许提交作业

---

# units

课程单元表。

---

## Purpose

保存课程中的：

```txt id="7goqt6"
作业
考试
实验
课堂表现
```

等考核单元。

---

## Fields

| Field      | Type         | Description |
| ---------- | ------------ | ----------- |
| course_id  | BIGINT       | 所属课程        |
| name       | VARCHAR(128) | 单元名称        |
| weight     | DOUBLE       | 权重          |
| full_score | DOUBLE       | 满分          |
| unit_order | INT          | 排序          |
| created_at | DATETIME     | 创建时间        |

---

## Example

```txt id="l7zxrc"
第一次作业
第二次作业
期中考试
期末考试
实验一
```

---

## Unique Key

```txt id="m6v1kt"
(course_id, name)
```

避免：

```txt id="9k12fd"
同一课程出现重复单元名
```

---

# scores

成绩表。

---

## Purpose

保存：

```txt id="bmr81p"
学生
+
课程
+
单元
=
成绩
```

关系。

---

## Fields

| Field      | Type     | Description |
| ---------- | -------- | ----------- |
| student_id | BIGINT   | 学生          |
| course_id  | BIGINT   | 课程          |
| unit_id    | BIGINT   | 单元          |
| score      | DOUBLE   | 分数          |
| created_at | DATETIME | 创建时间        |
| updated_at | DATETIME | 更新时间        |

---

## Unique Key

```txt id="gjlwm1"
(student_id, course_id, unit_id)
```

表示：

```txt id="mq8d95"
一个学生
在一个课程的某个单元
只能有一条成绩
```

---

## Why Keep id

虽然：

```txt id="tz6bqs"
(student_id, course_id, unit_id)
```

已经唯一。

但：

```txt id="g27fup"
id
```

有利于：

* ORM
* 日志
* API
* 缓存
* 后续扩展

---

# videos

视频资源表。

---

## Purpose

保存：

```txt id="7z1gho"
视频元数据
```

数据库：

```txt id="8ukcmx"
不直接存 MP4
```

只保存：

```txt id="h2v8qg"
路径
封面
时长
文件大小
```

---

## Fields

| Field       | Type         | Description |
| ----------- | ------------ | ----------- |
| uuid        | CHAR(36)     | 对外 UUID     |
| course_id   | BIGINT       | 所属课程        |
| uploader_id | BIGINT       | 上传者         |
| title       | VARCHAR(255) | 标题          |
| description | TEXT         | 描述          |
| file_path   | VARCHAR(255) | 视频路径        |
| cover_path  | VARCHAR(255) | 封面路径        |
| duration    | INT          | 视频时长（秒）     |
| file_size   | BIGINT       | 文件大小        |
| status      | ENUM         | 状态          |
| created_at  | DATETIME     | 创建时间        |
| updated_at  | DATETIME     | 更新时间        |

---

## file_path

第一版：

```txt id="ndivbf"
/uploads/videos/xxx.mp4
```

后续可扩展：

```txt id="xjlwm5"
OSS
MinIO
S3
CDN
```

---

## cover_path

视频封面路径。

用于：

```txt id="im6dl2"
列表预览
课程封面
播放器缩略图
```

---

## duration

单位：

```txt id="jlwm6v"
秒
```

用于：

* 继续播放
* 完成率统计
* 播放器进度条

---

## Status

```txt id="jlwm7z"
normal
hidden
deleted
```

---

# play_records

播放记录表。

---

## Purpose

保存：

```txt id="jlwm8a"
用户观看状态
```

不是：

```txt id="jlwm8b"
播放历史日志
```

---

## Design

一个用户：

```txt id="jlwm8c"
对一个视频
只保留一条状态记录
```

因此：

```txt id="jlwm8d"
(user_id, video_id)
```

唯一。

---

## Fields

| Field          | Type     | Description |
| -------------- | -------- | ----------- |
| user_id        | BIGINT   | 用户          |
| video_id       | BIGINT   | 视频          |
| progress       | INT      | 当前播放进度      |
| completed      | TINYINT  | 是否完成        |
| last_played_at | DATETIME | 最后播放时间      |

---

## progress

单位：

```txt id="jlwm8e"
秒
```

例如：

```txt id="jlwm8f"
1250
```

表示：

```txt id="jlwm8g"
播放到第 1250 秒
```

---

## completed

```txt id="jlwm8h"
0 = 未完成
1 = 已完成
```

---

## Typical Workflow

第一次播放：

```txt id="jlwm8i"
INSERT
```

后续播放：

```txt id="jlwm8j"
UPDATE
```

推荐：

```sql id="jlwm8k"
INSERT ... ON DUPLICATE KEY UPDATE
```

实现：

```txt id="jlwm8l"
自动插入 / 自动更新
```

---

# Recommended Backend Stack

## Backend

```txt id="jlwm8m"
FastAPI
SQLAlchemy
MariaDB
Redis
Nginx
```

---

## Client

```txt id="jlwm8n"
Qt Widgets
QML
QtNetwork
```

---

# Recommended Deployment Structure

```txt id="jlwm8o"
Client
    ↓
Nginx
    ↓
FastAPI
    ↓
MariaDB
```

视频推荐：

```txt id="jlwm8p"
Nginx 静态文件
```

或者：

```txt id="jlwm8q"
FastAPI 权限校验
→ X-Accel-Redirect
→ Nginx 发文件
```
