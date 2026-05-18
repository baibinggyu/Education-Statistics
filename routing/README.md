
````md
# Edu Server

Edu Server 是一个面向教育场景的后端服务系统。

项目基于 FastAPI、SQLAlchemy 与 MariaDB 构建，用于提供用户登录、权限管理、课程管理、视频资源管理、播放记录管理与成绩管理等基础能力。

当前版本重点完成教育平台服务端的基础业务链路与部署结构。

---

# Features

当前版本包含以下模块：

- 用户登录与权限管理
- 学生档案管理
- 课程管理
- 课程成员管理
- 课程考核单元管理
- 成绩管理
- 视频资源管理
- 视频播放记录管理
- RESTful API 服务
- Nginx 反向代理部署

---

# Tech Stack

## Backend

- FastAPI
- SQLAlchemy
- MariaDB
- PyMySQL
- JWT
- bcrypt
- Uvicorn

## Deployment

- Linux
- Nginx
- MariaDB

## Client

- Qt Widgets
- QML
- QtNetwork

---

# Deployment Structure

```txt
Client
  ↓
Nginx
  ↓
FastAPI Server: 127.0.0.1:55555
  ↓
MariaDB
````

FastAPI 服务只监听本机地址：

```txt
127.0.0.1:55555
```

外部请求统一由 Nginx 接收，再反向代理到 FastAPI 服务。

---

# Database Design

系统采用两套 ID 设计：

## Internal ID

数据库内部使用：

```txt
BIGINT id
```

用于：

* 表关联
* 外键约束
* ORM 映射
* 数据查询

## Public UUID

客户端和 API 使用：

```txt
UUID
```

例如：

```txt
/api/videos/{video_uuid}
```

后端收到 UUID 后，先查询数据库内部 id，再继续进行业务处理。

---

# Core Tables

| Table          | Description |
| -------------- | ----------- |
| users          | 用户登录与权限信息   |
| students       | 学生档案信息      |
| courses        | 课程信息        |
| course_members | 课程成员关系      |
| units          | 课程考核单元      |
| scores         | 学生成绩        |
| videos         | 视频资源信息      |
| play_records   | 视频播放记录      |

---

# User Roles

系统当前支持三类用户：

```txt
student
teacher
admin
```

---

# Video Resource Design

数据库不直接保存视频文件内容。

数据库只保存视频相关信息：

* 视频标题
* 视频描述
* 视频文件路径
* 封面路径
* 视频时长
* 文件大小
* 所属课程
* 上传者
* 视频状态

第一阶段视频文件路径示例：

```txt
/uploads/videos/xxx.mp4
```

---

# Play Record Design

播放记录用于保存用户对视频的观看状态。

一个用户对一个视频只保留一条播放记录。

核心字段：

| Field          | Description |
| -------------- | ----------- |
| user_id        | 用户 ID       |
| video_id       | 视频 ID       |
| progress       | 当前播放进度，单位为秒 |
| completed      | 是否完成        |
| last_played_at | 最后播放时间      |

---

# API Design

接口统一使用：

```txt
/api
```

作为前缀。

示例：

```txt
/api/users/login
/api/courses
/api/videos/{uuid}
```

需要身份认证的接口使用：

```txt
Authorization: Bearer <token>
```

JWT 中保存用户 UUID 和用户角色。

---

# Recommended Project Structure

```txt
edu_server/
├── main.py
├── database.py
├── models.py
├── schemas.py
├── auth.py
├── deps.py
├── routers/
│   ├── users.py
│   ├── auth.py
│   ├── courses.py
│   ├── videos.py
│   └── play_records.py
├── requirements.txt
└── README.md
```

---

# Installation

```bash
pip install -r requirements.txt
```

---

# Run Server

开发运行：

```bash
uvicorn main:app --host 127.0.0.1 --port 55555
```

---

# Nginx Example

```nginx
server {
    listen 80;
    server_name your_domain_or_ip;

    location /api/ {
        proxy_pass http://127.0.0.1:55555/api/;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

---

# Current Stage

当前阶段主要完成：

* FastAPI 服务结构
* SQLAlchemy ORM 映射
* MariaDB 数据库连接
* 用户注册与登录
* JWT 鉴权
* 课程基础接口
* 视频基础接口
* 播放记录接口
* Nginx 反向代理部署

```
```
