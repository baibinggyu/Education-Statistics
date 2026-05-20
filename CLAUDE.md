# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

Edu is a monorepo containing independent subprojects that form an AI + audio/video + real-time interaction + data analysis education platform. Each subproject has its own build system and can be developed independently.

## Subprojects

### EduStat (`EduStat/`) — Qt/C++ Desktop Application
Educational statistics and classroom management app (Qt Widgets, SQLite, spdlog, optional DeepSeek AI).

- **Build**: `cmake -B build && cmake --build build --config Release && ./build/EduStat`
- **Dependencies**: Qt 5/6 (Core, Widgets, Charts, Sql, Network), CMake 3.16+, C++17, spdlog (bundled as header-only)
- **Key files**: `mainwindow.h/cpp` (central controller, 3311 lines), `subjectcard.h/cpp`, `teamCard.h/cpp`, `flowlayout.h/cpp`, `scoredelegate.h/cpp`
- **DB**: SQLite (`EduStatSystem.db`) with 4 tables (student, course, unit, score), auto-initialized on first run
- **Python utils**: `xlsxToCsv.py`, `csvToXlsx.py`, `generate_test_xlsx.py` (need `pip install pandas openpyxl xlrd`); `csvToXlsx.exe` pre-built via PyInstaller in `dist/`
- **Config**: `init.json` — nested copy under `EduStat/EduStat/` has full config (courses, classes, DeepSeek API key placeholder); top-level copy has only API key placeholder
- **Note**: Source files exist at both `EduStat/` and `EduStat/EduStat/` (duplicated source tree; the nested one is the git repo root)
- **Primary platform**: Windows (Qt 6.10.2 MinGW 64-bit)
- **Subproject docs**: `EduStat/CLAUDE.md`, `EduStat/README.md`, `EduStat/readme.txt`, `EduStat/sql_show.md`, Chinese deployment/attribution docs

### EduStat_qml (`EduStat_qml/`) — QML + FluentUI Rewrite (v2.0)
QML rewrite of EduStat using Microsoft Fluent Design components. UI-only prototype (no business logic, no data model wiring).

- **Build**: `cmake -B build && cmake --build build && ./build/EduStat_qml`
- **Dependencies**: Qt6 (Core, Quick, Qml, Widgets), CMake 3.20+, C++17, FluentUI (zhuzichu520/FluentUI, built from source as QML plugin)
- **Run on Linux**: needs FluentUI plugin copied to build dir (POST_BUILD automates this)
- **13 pages**: 班级信息, 点名, 组队, 学生信息, 学科管理, 增加学科, 开课申请, 视频播放, 课程资源, 发布公告, 倒计时, 发消息, 登录
- **Entry**: `main.cpp` loads `main.qml` via `QQmlApplicationEngine`; QRC prefix `qrc:/qt/qml/EduStat/` (QTP0001 NEW)
- **Navigation**: Login overlay → sidebar (FluComboBox for course selector + Repeater nav) → Loader-based page switching via `currentPage` property
- **Login flow**: `loggedIn` boolean toggles between login `Loader` overlay and main `RowLayout`
- **Minimum window**: 960×680

#### FluentUI QML Conventions
All UI components use the FluentUI library. Standard Qt Quick Controls only for ScrollView, ListView, Repeater, Canvas, MouseArea, Timer.
- **Imports**: `import QtQuick`, `import QtQuick.Controls`, `import QtQuick.Layouts`, `import FluentUI`

**Core components used:**
| Component | Usage |
|---|---|
| `FluFrame` | Card containers (radius 10-12, padding 12-20, custom color) |
| `FluText` | All text (font.pixelSize, textColor, bold, wrapMode) |
| `FluFilledButton` | Primary actions (filled/accent background) |
| `FluButton` | Secondary actions (outlined) |
| `FluIconButton` | Toolbar icon buttons |
| `FluTextBox` | Single-line text input |
| `FluMultilineTextBox` | Multi-line text input (set Layout.preferredHeight) |
| `FluPasswordBox` | Password input |
| `FluComboBox` | Dropdown selectors |
| `FluSlider` | Progress/volume sliders |
| `FluToggleSwitch` | Boolean toggles |
| `FluDivider` | Horizontal separators |
| `FluScrollBar` | Custom scrollbar (ScrollBar.vertical: FluScrollBar {}) |
| `FluStaggeredLayout` | Masonry/waterfall card layout (set itemWidth, colSpacing, rowSpacing) |
| `FluTextButton` | Link-style buttons |

**Theme configuration (in main.qml Component.onCompleted):**
```qml
FluTheme.darkMode = 2           // Dark mode
FluTheme.primaryColor = "#0f766e"  // Teal accent
```

**Color palette (dark theme):**
| Role | Color |
|---|---|
| Primary accent | `#0f766e` |
| Page background | `Qt.rgba(32/255, 35/255, 40/255, 1)` |
| Sidebar background | `Qt.rgba(28/255, 31/255, 36/255, 1)` |
| Card background | default FluFrame or `Qt.rgba(25/255, 29/255, 35/255, 1)` / `"#fafafa"` (light) |
| Primary text | default (white in dark) |
| Secondary text | `"#8ea1ad"` |
| Muted text | `"#53636d"` |
| Label text | `"#b3c0c8"` |
| Success green | `"#22c55e"` |
| Danger red | `"#ef4444"` |
| Pinned badge | `"#0f766e"` |

**Card with dynamic height (text wrapping):**
```qml
FluFrame {
    Layout.fillWidth: true   // NOT width: parent.width — let layout control it
    radius: 10
    padding: 16
    implicitHeight: contentCol.implicitHeight + 32   // sum of content + padding
    ColumnLayout {
        id: contentCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top   // NOT anchors.bottom — let it compute freely
        spacing: 8
        FluText {
            Layout.fillWidth: true
            text: modelData.title
            font.pixelSize: 14
            font.bold: true
            wrapMode: Text.WordWrap   // always add for potentially-long text
        }
        // ...
    }
}
```

**ScrollView + ColumnLayout width binding:**
```qml
ScrollView {
    id: scrollView
    Layout.fillWidth: true
    clip: true
    ColumnLayout {
        width: scrollView.availableWidth   // binds to actual viewport, not parent.width
    }
}
```

**FluStaggeredLayout for wrapping card grids:**
```qml
ScrollView {
    FluStaggeredLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        itemWidth: 190
        colSpacing: 12   // NOT columnSpacing
        rowSpacing: 8
        Repeater { model: [...]; delegate: FluFrame { ... } }
    }
}
```

**Text sizing convention:**
- Page title: 18px bold
- Section title: 14-16px bold
- Body: 11-12px
- Caption/label: 10-11px
- Small/muted: 9-10px

**Common pitfalls:**
- FluFrame content clips if anchors.fill + padding both set; use `implicitHeight` pattern above
- `elide` and `wrapMode` are mutually exclusive on Text elements
- FluFilledButton has no `color` property (controlled by theme)
- FluStaggeredLayout uses `colSpacing` not `columnSpacing`
- ScrollView needs `import QtQuick.Controls` (not just FluentUI)
- `width: parent.width` inside ScrollView content can be unreliable; use `ScrollView.availableWidth`

### player (`player/`) — Qt6/C++ Video Player
Standalone video player with playback controls.

- **Build**: `cd player && cmake -B build && cmake --build build && ./build/VideoPlayer`
- **Dependencies**: Qt6 (Core, Gui, Widgets, Multimedia, MultimediaWidgets), CMake 3.16+, C++17
- **Key files**: `VideoPlayer.h/cpp` (custom player class with SeekSlider, 483 lines)
- **Features**: Play/pause, stop, seek (click-to-seek slider), speed control (0.25x-2.0x, 7 presets), volume (0-100%), fullscreen (double-click + F key), keyboard shortcuts (Space, Left/Right, Up/Down, F, Escape)
- **Audio workaround**: Uses `pactl` shell command via QTimer to unmute PipeWire/PulseAudio sink inputs
- **Test files**: `mov_bbb.mp4` (771 KB, Big Buck Bunny clip), `test_mute.cpp` (standalone audio debug utility, not in CMake build)
- **Build env**: Linux, Qt 6.11.0 system-wide, CMake 4.3.2

### routing (`routing/`) — edu_server FastAPI Backend + Video Streaming

Full REST API backend with JWT auth, role-based access control, and MariaDB persistence.

- **Start (edu_server)**: `cd routing && source edu_routing/bin/activate && python -m uvicorn edu_server.main:app --host 127.0.0.1 --port 55555`
- **Start (legacy main.py, 2-endpoint only)**: `cd routing && source edu_routing/bin/activate && uvicorn main:app --host localhost --port 11111`
- **Dependencies**: FastAPI, Uvicorn, SQLAlchemy, PyMySQL, passlib[bcrypt], python-jose[cryptography], python-multipart (venv at `routing/edu_routing/`, Python 3.14.4, managed by uv)
- **Database**: MariaDB 12.2.2, `edu_server_database` on localhost:3306, user `edu_user`:`edu123` (or root), charset utf8mb4
- **Spec doc**: `plan.md` (1257 lines)

#### Architecture

```
edu_server/
├── main.py              # FastAPI app entry, router includes, create_all tables
├── database.py          # SQLAlchemy engine + SessionLocal + get_db() generator
├── models.py            # 8 ORM models (User, Student, Course, CourseMember, Unit, Score, Video, PlayRecord)
├── schemas.py           # 10 Pydantic models for request/response validation
├── security.py          # bcrypt password hashing + JWT (HS256, 7-day expiry)
├── deps.py              # 3-layer auth deps: get_current_user → require_teacher_or_admin → require_admin
├── requirements.txt
└── routers/
    ├── auth.py          # POST /api/auth/register, POST /api/auth/login
    ├── users.py         # GET /api/users/me
    ├── courses.py       # POST/GET /api/courses/, GET /api/courses/{uuid}
    ├── videos.py        # POST /api/videos/, GET /api/videos/course/{uuid}, GET /api/videos/{uuid}
    └── play_records.py  # POST /api/play-records/update, GET /api/play-records/{uuid}
```

#### API Endpoints (13 total)

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | `/` | none | Health check `{"name":"Edu Server","status":"running"}` |
| GET | `/source/edu/{filename:path}` | none | Video file streaming (MIME by extension) |
| POST | `/api/auth/register` | none | Create user (username, password, role) → 201 |
| POST | `/api/auth/login` | none | Login → JWT `{access_token, token_type}` |
| GET | `/api/users/me` | Bearer | Get current user info |
| POST | `/api/courses/` | teacher/admin | Create course + auto-join creator as member |
| GET | `/api/courses/` | Bearer | List user's courses (admin sees all normal) |
| GET | `/api/courses/{uuid}` | Bearer | Get course detail (must be member or admin) |
| POST | `/api/videos/` | teacher/admin | Upload video to a course |
| GET | `/api/videos/course/{uuid}` | Bearer | List videos in a course |
| GET | `/api/videos/{uuid}` | Bearer | Get single video detail |
| POST | `/api/play-records/update` | Bearer | Upsert play progress (video_uuid, progress, completed) |
| GET | `/api/play-records/{uuid}` | Bearer | Get user's play record (default `{progress:0, completed:false}`) |

**Auth chain**: `OAuth2PasswordBearer(tokenUrl="/api/auth/login")` — JWT payload carries `sub` (user UUID) + `role`. Three dependency levels: `get_current_user` (any valid token) → `require_teacher_or_admin` (teacher/admin) → `require_admin` (admin only).

#### How to test

**Methodology — 4-phase approach used for all endpoint verification:**

1. **Env prep**: Confirm MariaDB is running (`systemctl status mariadb`), venv has all deps, test data exists (`source/edu/test.mp4`).
2. **Unit validation before server start**: Directly import and exercise security, database, and route modules in a Python one-liner to catch import errors and library incompatibilities before touching HTTP.
   ```bash
   source edu_routing/bin/activate
   python -c "from edu_server.main import app; print([r.path for r in app.routes])"
   python -c "from edu_server.security import hash_password, verify_password; h=hash_password('x'); assert verify_password('x',h)"
   python -c "from edu_server.database import engine; engine.connect()"
   ```
3. **Automated curl matrix**: Write a bash script with a `check()` helper that asserts HTTP status codes against expected values. Covers all 6 test dimensions:
   - **Positive path** — valid requests return correct data
   - **Auth enforcement** — missing/invalid/expired tokens → 401
   - **Role boundaries** — student can't create courses/videos → 403; non-member can't access course → 403
   - **Input validation** — duplicate username → 400; invalid role → 400; wrong password → 401
   - **Edge cases** — empty filename (was 500, now 404); non-existent UUID → 404
   - **Data flow chain** — register → login → get token → create course (capture UUID) → create video (capture UUID) → update play record → read back to verify persistence
4. **Clean summary**: One endpoint per line, status code only, quick visual scan for regressions.

**Quick smoke test (bash one-liner):**
```bash
# Start server in background, run tests, kill
cd routing && source edu_routing/bin/activate
python -m uvicorn edu_server.main:app --host 127.0.0.1 --port 55555 &
# Test all 13 endpoints
curl -s http://127.0.0.1:55555/ | python3 -m json.tool
curl -s http://127.0.0.1:55555/source/edu/test.mp4 -o /dev/null -w "%{http_code} %{content_type}\n"
curl -s -X POST http://127.0.0.1:55555/api/auth/register -H "Content-Type: application/json" -d '{"username":"t","password":"p","role":"teacher"}'
# ...etc. Full script available if needed.
fuser -k 55555/tcp
```

#### Known Pitfalls

- **`Path.exists()` vs `Path.is_file()`**: In `main.py`, checking `.exists()` on an empty-path `source/edu/` returns True (it's a directory), causing `FileResponse` to throw 500. Always use `.is_file()` for file-serving endpoints.
- **bcrypt 5.x incompatible with passlib 1.7.4**: passlib reads `bcrypt.__about__.__version__` which was removed in bcrypt 5.x. Pinning `bcrypt<5` (currently 4.3.0) avoids the crash. The passlib warning `(trapped) error reading bcrypt version` is cosmetic — hashing and verification still work.
- **uv venv has no pip**: The virtualenv at `edu_routing/` was created by uv and doesn't include pip. Use `python -m ensurepip` once, then `python -m pip install <pkg>`.
- **Port conflicts**: Use `fuser -k 55555/tcp` to kill stale processes before restarting the server. `lsof` is not installed on this system.
- **UUID in API paths, not internal BIGINT IDs**: All client-facing routes use `uuid` strings. Internal DB relationships use `BIGINT id`. Never expose numeric IDs in API responses.

### edu_pe (`edu_pe/`) — QML Mobile Learning Prototype
Pure QML phone-style UI prototype (超星学习平台), no C++ backend.

- **Run**: `qmlscene qml_ui/main.qml` (Qt 5.15+) or `qml6 qml_ui/main.qml` (Qt 6)
- **Structure**: 7 QML files (~2105 total lines), 390x844 phone form factor, 4 bottom tabs (Home, Courses, Chat, Profile) + CourseDetailPage overlay
- **UI conventions**: Primary color `#1296DB`, background `#F0F2F5`, Card radius 12, standard spacing 16px, font sizes 10-22px
- **Key files**: `main.qml` (app shell + navigation), `HomePage.qml` (banner, quick actions, recent courses), `CoursesPage.qml` (8-course grid), `CourseDetailPage.qml` (videos/assignments/check-in tabs, 658 lines), `ChatPage.qml` (8 conversations), `ProfilePage.qml` (user info, stats, settings)
- **Status**: All interactions are UI mockups with hardcoded data; no real logic behind any button

### database (`database/`) — MariaDB Schema
Database DDL and documentation for the backend server.

- **Files**:
  - `init.sql` (174 lines): DDL script creating `edu_server_database` with 8 tables
  - `edu_server_database.sql` (307 lines): mariadb-dump export with named constraints and lock statements
  - `README.md` (784 lines): Full design doc with field descriptions, relationships, tech stack recommendations
- **Tables**: users, students, courses, course_members, units, scores, videos, play_records
- **Encoding**: utf8mb4, BIGINT internal IDs + UUID external IDs, InnoDB engine
- **IDE config**: `.idea/` contains DataGrip project settings for managing the MariaDB connection

### loggin (`loggin/`) — QML Login Page Prototype
Standalone phone-style login page, pure QML UI mockup.

- **Run**: Not independently runnable (needs integration into a QML app with `ApplicationWindow` root)
- **Key file**: `LoginPage.qml` (222 lines)
- **Features**: Blue header with "Edu - AI + 教育" branding, username/password fields, login button (no-op), forgot password / register links (no-op), footer version text
- **UI conventions**: Same as edu_pe — primary `#1296DB`, background `#F0F2F5`, 390x844 form factor
- **Note**: Directory name "loggin" is a typo (should be "login"). File is a standalone component, not yet integrated into edu_pe
- **Status**: Pure visual prototype with all interaction handlers empty (marked with `/* 登录逻辑预留 */`)

### index.html — Project Showcase Landing Page
Single-file static landing page presenting the entire edu monorepo.

- **Tech**: Vanilla HTML + CSS + JS, zero external dependencies, fully self-contained
- **Size**: ~831 lines / 35 KB
- **Features**:
  - Fixed navbar with glassmorphism effect and anchor scrolling
  - Hero section with decorative CSS geometry and gradient text
  - 6 feature cards with hover animations (data analysis, video streaming, mobile learning, AI, data architecture, modular design)
  - Animated statistics counters (5 subprojects, 4 tech stacks, 8 DB tables, Qt 6 core)
  - 5 subproject cards (EduStat, Video Player, Routing, Edu PE, Database)
  - Technology stack tags (16 pills: C++17, Qt, CMake, Python, FastAPI, MariaDB, JWT, etc.)
  - Scroll animations via IntersectionObserver, scroll progress bar via requestAnimationFrame
- **Fonts**: System font stack optimized for Chinese rendering (PingFang SC, Hiragino Sans GB, Microsoft YaHei)

### net_state (`net_state/`) — Pytest Cache Artifact
**Not a subproject.** This is an orphaned pytest cache directory containing test node IDs from the `routing/` backend test suite.

- **Contents**: `.pytest_cache/` only — no source code, no config files
- **Origin**: Cached test results from running `routing/` tests (91 tests across `test_alchemy.py` + `test_routes.py`)
- **Action**: Can be safely deleted; it is a build artifact, not source code

## Architecture Notes

- **No CI/CD, test frameworks, or linters** are configured at the repository level. `routing/` has pytest set up locally.
- **Subproject-level CLAUDE.md files** with more granular detail:
  - `EduStat/CLAUDE.md` — EduStat architecture, DB schema, build details, component tree
  - `edu_pe/CLAUDE.md` — QML navigation structure, UI conventions, state management pattern
- **Language**: UI text and comments are primarily Chinese (educational context). Student data uses Chinese column headers (`学号`, `班级`, `姓名`)
- **Current stage**: First-generation platform prototype with multiple independent applications
- **Duplicated source tree**: `EduStat/` and `EduStat/EduStat/` contain identical source files; the nested directory is the actual git repository root
- **Port conventions**: `routing/edu_server` runs on 127.0.0.1:55555; legacy `routing/main.py` on 11111
