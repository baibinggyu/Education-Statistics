# 作品安装说明

EduStat 是一个运行在 Windows 环境下的桌面端教学统计与课堂辅助系统。

## 运行方式

如果你拿到的是已经打包好的运行版本，解压后直接双击 `EduStat.exe` 即可启动。  
首次运行后，程序会在当前目录下生成或使用本地数据库文件 `EduStatSystem.db`。

## 运行环境

- Windows 10 / Windows 11
- 已部署好的 Qt 运行依赖

如果是从源码运行，还需要：

- Qt 6.10.2 MinGW 64-bit
- MinGW 64-bit 编译工具链
- CMake

## 从源码构建

1. 使用 Qt Creator 打开项目根目录下的 `CMakeLists.txt`
2. 选择 Qt 6.10.2 MinGW 64-bit Kit
3. 构建 Debug 或 Release 版本
4. 运行生成的 `EduStat.exe`

## 发布说明

如果需要生成可独立运行的 Release 版本，建议在编译完成后使用 `windeployqt` 补齐依赖。  
发布目录中通常应包含：

- Qt6Core.dll
- Qt6Gui.dll
- Qt6Widgets.dll
- Qt6Sql.dll
- Qt6Network.dll
- Qt6Charts.dll
- `platforms`
- `sqldrivers`

## 使用说明

程序启动后，建议按以下顺序体验：

1. 在“学科管理”中新增课程并配置单元
2. 在“学生信息”中导入学生名单和成绩
3. 在“点名”中进行课堂随机点名
4. 在“组队”中进行随机分组或强配弱分组
5. 在“班级信息”中查看图表和教学分析
6. 在“学期报告和成绩导出”中导出成绩表和学期报告

## 补充说明

- 程序使用 SQLite 保存本地数据
- 若 `init.json` 中配置了有效的 DeepSeek API Key，可启用外部教学分析功能
- 若外部接口不可用，系统会自动回退到本地分析逻辑
- 导入学生信息时，导入表头应与当前课程单元一致
- 导出总分时，未录入成绩按 0 分处理
