# Edu — AI-Native Smart Education Platform

An integrated education platform combining **AI agents**, **video streaming**, **real-time interaction**, and **learning analytics** into a single system. Built with Qt6/C++ desktop clients, FastAPI backend, and MariaDB persistence.

## Architecture

```
┌─ Desktop Clients ────────────────────────────────────────┐
│  C++17 / Qt6 (Widgets + QML) / FluentUI / CMake         │
│  • EduStat      — Admin & analytics (Qt Widgets)         │
│  • EduStat_qml  — Fluent Design rewrite (QML)            │
│  • player       — Standalone video player                │
├─ Mobile Prototypes ──────────────────────────────────────┤
│  QML (pure UI) — edu_pe, loggin                          │
├─ Backend ────────────────────────────────────────────────┤
│  Python / FastAPI / Uvicorn / SQLAlchemy / JWT           │
│  edu_server — 13 REST endpoints, role-based auth         │
├─ Database ───────────────────────────────────────────────┤
│  MariaDB (InnoDB, utf8mb4) — 8 tables                    │
│  SQLite — local client storage                           │
├─ Reverse Proxy ──────────────────────────────────────────┤
│  Nginx — video streaming, API routing                    │
└─ Showcase ───────────────────────────────────────────────┘
   index.html — Zero-dependency landing page
```

## Subprojects

| Project | Stack | Description |
|---------|-------|-------------|
| **EduStat** | Qt6 Widgets, SQLite, spdlog | Classroom management, student scoring, charts |
| **EduStat_qml** | Qt6 QML, FluentUI | QML rewrite with Microsoft Fluent Design (13 pages) |
| **player** | Qt6 Multimedia | Video player with seek, speed control, fullscreen |
| **routing** | FastAPI, MariaDB, JWT | REST API backend — auth, courses, videos, play records |
| **edu_pe** | QML (UI only) | Mobile learning platform prototype (超星-style) |
| **database** | MariaDB | DDL schema, init scripts, design documentation |
| **loggin** | QML (UI only) | Login page component prototype |

## Features

- **AI Agent System** — Classroom summaries, knowledge organization, learning analytics, AI-generated courseware
- **Video Platform** — Upload, streaming, progress tracking, Nginx reverse proxy with range requests
- **Real-time Interaction** — Chat, attendance, class announcements
- **Role-based Access** — JWT auth with admin / teacher / student roles
- **Multi-platform** — Qt desktop, QML mobile prototypes, web landing page

## Quick Start

### Backend (edu_server)

```bash
cd routing
source edu_routing/bin/activate
python -m uvicorn edu_server.main:app --host 127.0.0.1 --port 55555
```

### Desktop App (EduStat)

```bash
cd EduStat
cmake -B build && cmake --build build --config Release
./build/EduStat
```

### QML App (EduStat_qml)

```bash
cd EduStat_qml
cmake -B build && cmake --build build
./build/EduStat_qml
```

### Video Player

```bash
cd player
cmake -B build && cmake --build build
./build/VideoPlayer
```

## Tech Stack

| Layer | Technologies |
|-------|-------------|
| Desktop | C++17, Qt6 (Widgets, QML, Charts, Sql, Network, Multimedia), FluentUI, CMake |
| Backend | Python 3.14, FastAPI, Uvicorn, SQLAlchemy, PyMySQL |
| Auth | JWT (HS256), bcrypt, passlib |
| Database | MariaDB 12, SQLite |
| Proxy | Nginx |
| Dev Tools | pytest, uv, PyInstaller |

## API Endpoints (13 total)

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | `/` | — | Health check |
| GET | `/source/edu/{filename}` | — | Video file streaming |
| POST | `/api/auth/register` | — | User registration |
| POST | `/api/auth/login` | — | Login (returns JWT) |
| GET | `/api/users/me` | Bearer | Current user info |
| POST | `/api/courses/` | teacher/admin | Create course |
| GET | `/api/courses/` | Bearer | List user's courses |
| GET | `/api/courses/{uuid}` | Bearer | Course detail |
| POST | `/api/videos/` | teacher/admin | Upload video |
| GET | `/api/videos/course/{uuid}` | Bearer | List course videos |
| GET | `/api/videos/{uuid}` | Bearer | Video detail |
| POST | `/api/play-records/update` | Bearer | Upsert play progress |
| GET | `/api/play-records/{uuid}` | Bearer | Get play record |

## Project Status

First-generation platform prototype. Architecture is taking shape with the right tech stack direction. Core subsystems (video streaming, AI chat, auth, course management) are functional.

## License

[MIT](LICENSE)
