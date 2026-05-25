# Edu Server

FastAPI + SQLAlchemy + MariaDB + JWT 后端服务。

## 目录结构

```
edu_server/
├── main.py              FastAPI 入口 + 路由注册
├── database.py          SQLAlchemy engine / session / Base
├── models.py            8 个 ORM 模型（与 init.sql 对齐）
├── schemas.py           Pydantic 请求/响应 Schema
├── security.py          bcrypt 密码哈希 + JWT
├── deps.py              FastAPI Depends 依赖注入
├── routers/             路由模块
│   ├── auth.py          注册 / 登录
│   ├── users.py         用户信息
│   ├── courses.py       课程 CRUD + 成员管理
│   ├── units.py         单元管理
│   ├── scores.py        成绩管理
│   ├── videos.py        视频管理 + 流媒体
│   ├── play_records.py  播放进度
│   └── files.py         文件上传
├── services/            业务逻辑层
├── tests/               测试
└── README.md
```

## 技术栈

| 组件 | 选型 |
|------|------|
| 框架 | FastAPI 0.136 |
| ORM | SQLAlchemy 2.0 |
| 数据库 | MariaDB (PyMySQL) |
| 认证 | JWT (python-jose) + bcrypt 5.x |
| 密码 | bcrypt (不使用 passlib，避免兼容性问题) |
| 服务器 | Uvicorn |
| 反向代理 | Nginx |

## 启动

```bash
# 1. 激活 venv
cd routing
source edu_routing/bin/activate

# 2. 进入项目
cd edu_server

# 3. 启动（开发模式）
uvicorn main:app --host 127.0.0.1 --port 55555 --reload
```

启动后访问:
- API 文档: http://127.0.0.1:55555/docs
- OpenAPI: http://127.0.0.1:55555/openapi.json

## 数据库

首次启动时 `Base.metadata.create_all()` 自动建表。

如需手动初始化:
```bash
mysql -u edu_user -p edu_server_database < ../../database/init.sql
```

## 设计原则

1. **双层 ID**: API 对外用 UUID，数据库内部用 BIGINT id（性能 + 安全）
2. **逻辑删除**: courses/videos 使用 status 字段，不物理删除
3. **依赖注入**: 所有公共逻辑（认证、权限、课程成员检查）通过 FastAPI Depends 复用
4. **密码安全**: bcrypt 哈希，JWT 7 天过期，不暴露内部 id

## 当前阶段

第一阶段核心模块实现中（database / models / schemas / security / deps 已完成）。
