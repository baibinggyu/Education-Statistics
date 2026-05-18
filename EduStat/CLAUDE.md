# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

EduStat is a Qt/C++ desktop application for educational statistics and classroom management. It supports subject management, student information management, roll call, team formation, class information analysis, and semester report export. The application uses SQLite for local data storage and includes optional DeepSeek AI integration for advanced analysis.

## Architecture

### Core Components

- **MainWindow** (`mainwindow.h/cpp`): Central controller managing all application features and UI tabs
- **SubjectCard** (`subjectcard.h/cpp`): Custom widget for displaying and managing course subjects with units and weights
- **TeamCard** (`teamCard.h/cpp`): Widget for displaying team formations
- **FlowLayout** (`flowlayout.h/cpp`): Custom layout for dynamic widget arrangement
- **ScoreDelegate** (`scoredelegate.h/cpp`): Custom delegate for score editing in tables

### Database Schema

SQLite database with four main tables:
- `student`: Student information (student_id, name, class)
- `course`: Course/subject definitions (course_id, name)
- `unit`: Course units with weights and scores (course_id, name, weight, score, unit_order)
- `score`: Student scores per unit (student_id, course_id, unit_name, score)

### External Dependencies

- **Qt 5/6**: Core, Widgets, Charts, Sql, Network modules
- **spdlog**: Logging library (included as subdirectory)
- **pandas**: Python library for data conversion utilities
- **DeepSeek API**: Optional AI-powered analysis (configured in `init.json`)

### Python Utilities

- `csvToXlsx.py`: Convert CSV to Excel format (used for student information export)
- `xlsxToCsv.py`: Convert Excel to CSV format (used for student information import)
- `generate_test_xlsx.py`: Generate test data for development
- Compiled executables are placed in the `dist/` directory

## Build System

### CMake Configuration

The project uses CMake with support for both Qt5 and Qt6:
```bash
# Configure with Qt6 (default)
cmake -B build -DCMAKE_PREFIX_PATH=/path/to/qt6

# Configure with Qt5
cmake -B build -DCMAKE_PREFIX_PATH=/path/to/qt5
```

Key CMake features:
- Automatic UIC, MOC, and RCC processing
- C++17 standard required
- Copies `init.json` and Python utilities to build directory
- Supports macOS bundle creation and Windows executable

### Build Commands

```bash
# Configure and build
cmake -B build
cmake --build build --config Release

# Run the application
./build/EduStat  # or build\EduStat.exe on Windows
```

### Development Setup

1. Install Qt 6.10.2 MinGW 64-bit (or compatible version) - the primary development environment
2. Ensure CMake 3.16+ is installed
3. For Python utilities: `pip install pandas openpyxl xlrd`
4. Build Python utilities: The project includes pre-compiled executables in `dist/`, but you can rebuild them using PyInstaller if needed

## Common Development Tasks

### Running the Application

```bash
# Build and run from source directory
cmake --build build --target EduStat && ./build/EduStat
```

### Adding New Features

1. **UI Components**: Add to appropriate tab in `mainwindow.ui` and connect signals in `MainWindow`
2. **Database Operations**: Use `QSqlQuery` with the existing `db` connection in `MainWindow`
3. **Custom Widgets**: Follow patterns in `SubjectCard` and `TeamCard` for consistent styling

### Testing Data Conversion

```bash
# Test CSV to XLSX conversion
python csvToXlsx.py input.csv output.xlsx

# Test XLSX to CSV conversion
python xlsxToCsv.py input.xlsx output.csv

# Generate test data
python generate_test_xlsx.py
```

### Logging

The application uses spdlog with both file (`warn.log`) and console output. Log level is set to `warn` by default. Modify `main.cpp` to change logging configuration.

## Configuration

### `init.json`

Contains initial configuration:
- `course`: Predefined courses and classes
- `deepseekApi`: API key for DeepSeek AI analysis (optional)

**Important**: This file contains sensitive API keys. Never commit actual keys to version control.

## Database Management

The database is automatically initialized on first run with the schema defined in `MainWindow::initSQLite()`. To reset the database, delete the SQLite file (default location is the application directory).

## Export/Import Features

### Student Information Import

Format requirements:
- CSV or Excel files
- First three columns must be: `学号`, `班级`, `姓名` (student ID, class, name)
- Subsequent columns must match current course unit names
- Student IDs must be numeric

### Semester Report Export

Generates Markdown reports with:
- Class composition analysis
- Score distribution charts
- Unit average trends
- Local or AI-powered analysis (DeepSeek)

## Platform Considerations

- **Primary Platform**: Windows (tested with Qt 6.10.2 MinGW 64-bit)
- **Deployment**: Use `windeployqt` to bundle Qt dependencies
- **macOS**: Bundle configuration included in CMakeLists.txt
- **Android**: Basic configuration exists but not fully implemented

## Code Style

- Qt signal/slot naming conventions
- Bilingual codebase: Chinese comments and variable names mixed with English
- UI elements primarily in Chinese for educational context
- Custom widgets inherit from appropriate Qt base classes
- Database operations use parameterized queries to prevent SQL injection

## Language Considerations

The application is designed for Chinese educational contexts:
- UI text is in Chinese
- Student data fields use Chinese column names (`学号`, `班级`, `姓名`)
- Comments and variable names are predominantly Chinese
- When modifying UI text, maintain Chinese language support
- Export/import formats expect Chinese column headers