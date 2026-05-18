# EduStat 数据库摘要

本文档基于以下两部分整理：

- 代码中的建库逻辑：[mainwindow.cpp](/home/bai-yu/codeProject/edu/EduStat/mainwindow.cpp:3018)
- 当前项目内实际 SQLite 库：`build/EduStatSystem.db`

程序运行时使用 SQLite，本地数据库文件名固定为 `EduStatSystem.db`。代码中通过：

```cpp
this->db.setDatabaseName("EduStatSystem.db");
```

也就是说，最终数据库文件通常生成在程序当前工作目录。

## 1. 当前表清单

业务上只有 4 张主表：

1. `student`：学生基础信息
2. `course`：学科/课程
3. `unit`：某门课下面的单元配置
4. `score`：学生在某门课某个单元上的成绩

## 2. 建表 SQL

这是代码里真实执行的建表语句：

```sql
CREATE TABLE IF NOT EXISTS student(
    student_id INTEGER PRIMARY KEY,
    name TEXT,
    class TEXT
);

CREATE TABLE IF NOT EXISTS course(
    course_id INTEGER PRIMARY KEY,
    name TEXT
);

CREATE TABLE IF NOT EXISTS unit(
    course_id INTEGER,
    name TEXT,
    weight REAL,
    score INTEGER,
    unit_order INTEGER,
    PRIMARY KEY(course_id, name)
);

CREATE TABLE IF NOT EXISTS score(
    student_id INTEGER,
    course_id INTEGER,
    unit_name TEXT,
    score REAL,
    PRIMARY KEY(student_id, course_id, unit_name)
);
```

代码里虽然执行了：

```sql
PRAGMA foreign_keys = ON;
```

但当前 4 张表的建表语句里并没有定义真正的 `FOREIGN KEY` 约束。

## 3. 每张表的字段说明

### 3.1 `student`

| 字段 | 类型 | 含义 | 备注 |
|---|---|---|---|
| `student_id` | `INTEGER` | 学号 | 主键 |
| `name` | `TEXT` | 学生姓名 | 可空 |
| `class` | `TEXT` | 班级名 | 可空 |

说明：

- 学号在代码里按“纯数字”校验。
- 保存学生信息时，若 `student_id` 已存在，会更新 `name` 和 `class`。

相关代码：

- 保存/更新学生：[mainwindow.cpp](/home/bai-yu/codeProject/edu/EduStat/mainwindow.cpp:2367)

### 3.2 `course`

| 字段 | 类型 | 含义 | 备注 |
|---|---|---|---|
| `course_id` | `INTEGER` | 学科编号 | 主键 |
| `name` | `TEXT` | 学科名称 | 可空 |

说明：

- 新建学科时要求 `course_id` 唯一。
- 下一个默认学科编号通过 `SELECT MAX(course_id) FROM course` 生成，最小从 `1001` 开始。

相关代码：

- 新增学科：[mainwindow.cpp](/home/bai-yu/codeProject/edu/EduStat/mainwindow.cpp:3240)
- 生成下一个学科编号：[mainwindow.cpp](/home/bai-yu/codeProject/edu/EduStat/mainwindow.cpp:1000)

### 3.3 `unit`

| 字段 | 类型 | 含义 | 备注 |
|---|---|---|---|
| `course_id` | `INTEGER` | 所属学科编号 | 逻辑上关联 `course.course_id` |
| `name` | `TEXT` | 单元名称 | 与 `course_id` 组成联合主键 |
| `weight` | `REAL` | 权重 | 例如 `0.3`、`0.4` |
| `score` | `INTEGER` | 该单元满分 | 例如 `100` |
| `unit_order` | `INTEGER` | 排序号 | UI 展示顺序依赖它 |

主键：

```sql
PRIMARY KEY(course_id, name)
```

说明：

- 同一门课下，单元名不能重复。
- 很多页面都按 `unit_order ASC` 读取单元，因此这个字段不是装饰字段，而是业务关键字段。

相关代码：

- 新增单元：[mainwindow.cpp](/home/bai-yu/codeProject/edu/EduStat/mainwindow.cpp:3259)
- 读取单元用于展示：[mainwindow.cpp](/home/bai-yu/codeProject/edu/EduStat/mainwindow.cpp:1751)
- 读取单元用于导入成绩：[mainwindow.cpp](/home/bai-yu/codeProject/edu/EduStat/mainwindow.cpp:2506)

### 3.4 `score`

| 字段 | 类型 | 含义 | 备注 |
|---|---|---|---|
| `student_id` | `INTEGER` | 学号 | 逻辑上关联 `student.student_id` |
| `course_id` | `INTEGER` | 学科编号 | 逻辑上关联 `course.course_id` |
| `unit_name` | `TEXT` | 单元名称 | 逻辑上对应 `unit.name`，但要结合 `course_id` 一起理解 |
| `score` | `REAL` | 成绩 | 可空，允许空成绩 |

主键：

```sql
PRIMARY KEY(student_id, course_id, unit_name)
```

说明：

- 这张表没有独立 `id`。
- 一条记录唯一表示：`某学生 + 某课程 + 某单元` 的成绩。
- 保存成绩时使用 `ON CONFLICT ... DO UPDATE`，因此重复导入/保存会覆盖原值。

相关代码：

- 保存成绩：[mainwindow.cpp](/home/bai-yu/codeProject/edu/EduStat/mainwindow.cpp:2411)

## 4. 真实关系图

虽然数据库里没有正式外键，但代码逻辑上的关系是：

```text
course (1) ---- (n) unit
course (1) ---- (n) score
student (1) --- (n) score

score.unit_name + score.course_id
    对应
unit.name + unit.course_id
```

也就是说，`score` 实际上是连接 `student`、`course`、`unit` 的核心表。

## 5. 当前程序依赖的隐含规则

这部分很重要，后面如果你和别的 AI 讨论改库，最好优先看这里。

### 5.1 没有数据库级联删除，都是代码手动删

删除学科时，代码按这个顺序手动删除：

1. `DELETE FROM score WHERE course_id = ?`
2. `DELETE FROM unit WHERE course_id = ?`
3. `DELETE FROM course WHERE course_id = ?`

相关代码：

- 学科删除：[mainwindow.cpp](/home/bai-yu/codeProject/edu/EduStat/mainwindow.cpp:3093)

这说明：

- 如果你将来直接改库结构，不能假设现在已经有外键级联。
- 如果后续想补 `FOREIGN KEY ... ON DELETE CASCADE`，需要同步检查现有删除逻辑是否还保留。

### 5.2 删除某课程下的学生成绩后，学生可能被顺手删掉

当前逻辑是：

1. 先删 `score` 中该课程下该学生的成绩
2. 再查这个学生在 `score` 表里是否还有任何成绩
3. 如果没有，就删掉 `student`

相关代码：

- 删除学生：[mainwindow.cpp](/home/bai-yu/codeProject/edu/EduStat/mainwindow.cpp:2729)

这意味着：

- `student` 表并不被当成“全量学生主档”来维护。
- 它更像“至少在某门课里存在成绩数据的学生集合”。

如果未来你想把学生主档独立出来，这里会是一个重点改造点。

### 5.3 学生是否出现在很多功能里，取决于 `score` 表里有没有该课程记录

例如点名、分组、课程分析等，都是先从 `score` 里筛出当前课程，再去联表拿学生信息。

典型查询：

```sql
SELECT DISTINCT s.student_id, s.name, s.class
FROM score sc
JOIN student s ON s.student_id = sc.student_id
WHERE sc.course_id = ?
```

相关代码：

- 点名数据读取：[mainwindow.cpp](/home/bai-yu/codeProject/edu/EduStat/mainwindow.cpp:654)
- 课程分析读取：[mainwindow.cpp](/home/bai-yu/codeProject/edu/EduStat/mainwindow.cpp:1218)

这意味着：

- 单独存在于 `student` 表、但没有当前课程成绩的学生，不会进入很多业务页面。

### 5.4 `score.unit_name` 用字符串而不是 `unit` 主键引用

当前没有 `unit_id`，所以成绩记录是靠：

- `course_id`
- `unit_name`

来定位单元。

风险：

- 如果你修改了 `unit.name`，历史 `score.unit_name` 不会自动跟着改。
- 如果想支持“单元改名不影响历史数据”，最好新增稳定主键，比如 `unit_id`。

### 5.5 `unit_order` 影响展示顺序和导入逻辑

单元读取大量使用：

```sql
ORDER BY unit_order ASC
```

如果改掉这个字段或含义，导入、展示、分析顺序都可能变。

## 6. 当前索引情况

当前除了主键产生的自动索引外，没有看到额外业务索引。

自动索引：

- `sqlite_autoindex_unit_1`
- `sqlite_autoindex_score_1`

没有单独索引的字段包括：

- `score.course_id`
- `score.student_id`
- `unit.course_id`

如果后续数据量变大，可能需要补索引。

## 7. 建议给别的 AI 的“改库讨论重点”

如果你打算和别的 AI 商量数据库怎么改，建议优先讨论下面这些问题：

1. `student` 是否要升级成真正的学生主档，而不是依附于 `score` 的存在性。
2. `unit` 是否要新增稳定主键 `unit_id`，避免 `unit_name` 改名带来的级联问题。
3. 是否要为 `score.student_id -> student.student_id`、`score.course_id -> course.course_id`、`unit.course_id -> course.course_id` 增加真正外键。
4. 是否要把“删课/删学生时的手动清理逻辑”改成数据库级联。
5. 是否要增加唯一约束、非空约束，例如课程名、学生姓名、单元名、权重范围、满分范围。
6. 是否要增加业务索引，例如 `score(course_id)`、`score(student_id)`、`unit(course_id, unit_order)`。

## 8. 一句话总结

当前数据库设计很轻量，核心思想是：

- `course` 定义学科
- `unit` 定义学科下的单元
- `student` 存学生基础信息
- `score` 作为事实表，把学生、学科、单元三者连接起来

但它目前主要靠应用代码维持一致性，而不是靠数据库约束维持一致性。
