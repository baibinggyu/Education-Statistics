# Edu Server — 分阶段实施计划

---

## 第一阶段: 核心 MVP (当前目标)

**目标**: 跑通认证 + 课程 + 视频 + 播放记录的完整链路。

### 文件清单 (需创建)

| 文件 | 行数估算 | 依赖 |
|------|---------|------|
| `edu_server/main.py` | ~40 | database, routers |
| `edu_server/database.py` | ~30 | sqlalchemy |
| `edu_server/models.py` | ~150 | database.py |
| `edu_server/schemas.py` | ~200 | pydantic |
| `edu_server/security.py` | ~50 | passlib, jose |
| `edu_server/deps.py` | ~80 | models, security |
| `edu_server/routers/__init__.py` | 0 | - |
| `edu_server/routers/auth.py` | ~80 | deps, schemas, models |
| `edu_server/routers/users.py` | ~40 | deps, schemas |
| `edu_server/routers/courses.py` | ~120 | deps, schemas, models |
| `edu_server/routers/videos.py` | ~150 | deps, schemas, models |
| `edu_server/routers/play_records.py` | ~80 | deps, schemas, models |
| `edu_server/tests/__init__.py` | 0 | - |
| `edu_server/tests/conftest.py` | ~60 | pytest, SQLAlchemy |
| `edu_server/tests/test_alchemy.py` | ~200 | models |
| `edu_server/tests/test_routes.py` | ~300 | httpx, main |
| `nginx/edu-server.conf` | 已经设计好 | nginx |

### 第一阶段路由 (7 个模块, 20 个端点)

```
Auth:     POST register, POST login
Users:    GET me, PATCH me
Courses:  POST /, GET /, GET /{uuid}, PATCH /{uuid}, DELETE /{uuid}
Members:  GET /{uuid}/members, POST /{uuid}/members, DELETE /{uuid}/members/{uuid}
Units:    POST /{uuid}/units, GET /{uuid}/units
Videos:   POST /, GET /course/{uuid}, GET /{uuid}, GET /{uuid}/stream
Play:     POST /update, GET /{uuid}
Files:    POST /upload/video, POST /upload/cover
```

### 完成标准

- [ ] `python edu_server/main.py` 可启动，FastAPI docs 可访问
- [ ] 用户可以注册 (3 种角色)
- [ ] 用户可以登录并拿到 JWT
- [ ] JWT 可以访问 /api/users/me
- [ ] 教师可以创建课程 (自动加入 course_members)
- [ ] 教师可以添加/移除课程成员
- [ ] 教师可以创建单元
- [ ] 教师可以创建视频元数据
- [ ] 学生可以查看自己加入的课程列表
- [ ] 学生可以查看课程下的视频列表
- [ ] 学生可以通过 /stream 端点播放视频 (X-Accel-Redirect)
- [ ] 学生可以上报播放进度
- [ ] 学生可以查询自己的播放记录
- [ ] Nginx 反向代理正常工作
- [ ] pytest 全部通过 (至少 40 个测试用例)

---

## 第二阶段: 成绩系统 + 文件管理 + 统计分析 (2-3 周后)

### 新增模块

- **Units Router 扩展**: PATCH/DELETE/Reorder
- **Scores Router**: 全部 6 个端点
- **Students Router**: 全部 3 个端点
- **Users 管理**: 管理员用户列表 + 禁用/启用
- **Files Router 增强**: 文件校验、去重、缩略图
- **Services 层**:
  - `services/statistics.py` — 成绩聚合计算
  - `services/export.py` — XLSX/CSV 导出
  - `services/analysis.py` — DeepSeek AI 学情分析

### 新增端点

```
Students: POST /bind, GET /{user_uuid}, GET /
Scores:   POST /, POST /batch, GET /course/{uuid}/my,
          GET /course/{uuid}/summary, GET /course/{uuid}/distribution,
          GET /course/{uuid}/export
Units:    PATCH /{uuid}/units/{id}, DELETE /{uuid}/units/{id},
          POST /{uuid}/units/reorder
Users:    GET /, PATCH /{uuid}/status
Auth:     POST /refresh
```

### 完成标准

- [ ] 教师可以录入/更新学生成绩
- [ ] 教师可以批量导入成绩
- [ ] 教师可以查看成绩汇总 (含加权总分、排名)
- [ ] 教师可以查看成绩分布统计
- [ ] 教师可以导出成绩为 XLSX
- [ ] 学生可以查看自己的成绩
- [ ] 学生可以绑定学生档案
- [ ] 管理员可以管理用户列表
- [ ] 文件上传支持大文件和类型校验
- [ ] AI 学情分析接口接入 DeepSeek

---

## 第三阶段: 实时互动 + 高可用 + 监控 (远期)

### 新增能力

- **WebSocket 实时通信**: 课堂互动、在线状态
- **Redis 缓存**: Session、热点数据、速率限制
- **消息队列**: RabbitMQ / Redis Stream (异步任务)
- **对象存储**: MinIO / S3 (视频存储扩展)
- **CDN**: 视频分发加速
- **监控**: Prometheus + Grafana
- **日志**: ELK / Loki
- **Docker**: 容器化部署
- **Kubernetes**: 编排 (水平扩展)

### 新增端点

```
Chat:     WebSocket /ws/chat/{course_uuid}
Live:     WebSocket /ws/live/{course_uuid}
Admin:    GET /admin/stats, GET /admin/health
```

---

## 数据库初始化 (在开发前完成)

### MariaDB 初始化步骤

```bash
# 1. 安装 MariaDB (如果未安装)
sudo pacman -S mariadb           # Arch Linux
sudo systemctl enable --now mariadb

# 2. 安全初始化
sudo mysql_secure_installation

# 3. 创建数据库和用户
sudo mysql -u root <<SQL
CREATE DATABASE IF NOT EXISTS edu_server_database
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'edu_user'@'localhost'
  IDENTIFIED BY 'your_secure_password';

GRANT ALL PRIVILEGES ON edu_server_database.* TO 'edu_user'@'localhost';
FLUSH PRIVILEGES;
SQL

# 4. 执行建表脚本
mysql -u edu_user -p edu_server_database < database/init.sql

# 5. 验证
mysql -u edu_user -p edu_server_database -e "SHOW TABLES;"
```

### Python 环境初始化

```bash
# venv 已存在于 routing/edu_routing/
cd routing
source edu_routing/bin/activate

# 验证依赖
python -c "
import fastapi
import uvicorn
import sqlalchemy
import pymysql
import passlib
import jose
print('All dependencies OK')
"
```

---

## 启动与测试流程

### 开发启动

```bash
# Terminal 1: FastAPI
cd routing
source edu_routing/bin/activate
cd edu_server
uvicorn main:app --host 127.0.0.1 --port 55555 --reload

# Terminal 2: Nginx (如果已配置)
sudo nginx -t && sudo systemctl reload nginx

# Terminal 3: 运行测试
cd routing
source edu_routing/bin/activate
cd edu_server
pytest -v
```

### 快速冒烟测试

```bash
# 1. 健康检查
curl http://127.0.0.1:55555/

# 2. 注册教师
curl -X POST http://127.0.0.1:55555/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"teacher1","password":"123456","role":"teacher"}'

# 3. 登录
TOKEN=$(curl -s -X POST http://127.0.0.1:55555/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"teacher1","password":"123456"}' | jq -r '.access_token')

# 4. 获取当前用户
curl http://127.0.0.1:55555/api/users/me \
  -H "Authorization: Bearer $TOKEN"

# 5. 创建课程
curl -X POST http://127.0.0.1:55555/api/courses/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"C++ 程序设计","description":"C++ 基础课程"}'
```

---

## 与现有代码的关系

| 现有文件 | 处理方式 |
|---------|---------|
| `routing/main.py` | 保留不动 (简单视频流服务，端口 11111) |
| `routing/plan.md` | 保留作为历史参考设计 |
| `routing/source/edu/test.mp4` | 测试视频，保留 |
| `routing/edu_routing/` | venv，所有新代码共用此环境 |

新后端代码全部放在 `routing/edu_server/` 下，与现有 `main.py` 互不干扰。
