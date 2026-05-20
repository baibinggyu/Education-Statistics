# Repository Guidelines

## Project Structure & Module Organization

This repository combines education-platform clients, services, and docs. `EduStat/` is the Qt6 Widgets desktop analytics app. `EduStat_qml/` is the Qt6 QML/FluentUI rewrite and shares chat code from `chat/`. `player/` contains the standalone Qt video player. `clientApi/` contains the C++ API client and endpoint test executable. `routing/edu_server/` is the FastAPI backend; `database/` stores MariaDB schema and initialization SQL. `android/` is a Flutter prototype. `intro/` and `net_state/` hold design and deployment docs; `index.html` is the static showcase page.

## Build, Test, and Development Commands

- `cd routing && source edu_routing/bin/activate && python -m uvicorn edu_server.main:app --host 127.0.0.1 --port 55555`: run the FastAPI service locally.
- `cd EduStat && cmake -B build && cmake --build build --config Release`: build the Qt Widgets app.
- `cd EduStat_qml && cmake -B build && cmake --build build`: build the QML app.
- `cd player && cmake -B build && cmake --build build`: build the video player.
- `cd clientApi && cmake -B build && cmake --build build && ./build/test_endpoints`: build and run C++ endpoint checks.
- `cd android && flutter analyze && flutter test`: lint and test the Flutter prototype.

## Coding Style & Naming Conventions

Use C++17 for Qt/CMake projects. Follow the existing brace style, `snake_case` filenames, and Qt class naming (`MainWindow`, `ChatBackend`). Keep CMake targets scoped to each subproject. Python modules use FastAPI/SQLAlchemy patterns, `snake_case` functions, and Pydantic schema classes in `schemas.py`. Flutter follows `flutter_lints`; use `lower_snake_case.dart` filenames and `PascalCase` widgets.

## Testing Guidelines

Place C++ tests beside the module they validate, as in `clientApi/test_endpoints.cpp` and `player/test_mute.cpp`. Backend tests should run from `routing/` with the project virtualenv active and should avoid hard-coded production credentials. Flutter tests belong in `android/test/` and should use `_test.dart` naming. Run the relevant build plus tests before opening a PR.

## Commit & Pull Request Guidelines

Recent history uses concise conventional prefixes such as `fix:`, `feat(clientApi):`, `docs:`, and `routing:`. Keep commits focused and mention the affected component. Pull requests should include a short summary, commands run, linked issue or task, and screenshots or recordings for UI changes. Note database, environment, or deployment changes explicitly.

## Security & Configuration Tips

Do not commit real API keys, JWT secrets, database passwords, or new local absolute paths. Use `.env.example` files as templates and keep generated build directories, virtualenv caches, and media test artifacts out of review unless intentionally updated.
