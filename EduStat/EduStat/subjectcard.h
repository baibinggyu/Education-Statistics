#ifndef SUBJECTCARD_H
#define SUBJECTCARD_H

#include <QWidget>
#include <QLabel>
#include <QPushButton>
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QCheckBox>
#include <QList>
#include <QMouseEvent>

class SubjectCard : public QWidget
{
    Q_OBJECT
public:
    explicit SubjectCard(int courseId, const QString &subjectName, QWidget *parent = nullptr);

    void setUnitWeight(int unitIndex, int weight);  // 设置单元权重
    void setUnitName(int unitIndex, const QString &name);  // 设置单元名称
    void setStatsEnabled(bool enabled);              // 设置是否统计分数
    size_t getUnitSize() const;                      // 获取单元数量
    QString getSubjectName() const;                  // 获取科目名称
    void setSubjectName(const QString &name);        // 设置科目名称
    int getCourseId() const;                         // 获取课程id
    bool isSelected() const;                         // 是否选中
    void setSelected(bool selected);                 // 设置选中态

    // 新增：添加单元
    void addUnit(const QString &unitName = QString(), int weight = 0);

signals:
    void deleteClicked();
    void statsToggled(bool enabled);
    void clicked();

protected:
    void mousePressEvent(QMouseEvent *event) override;

private:
    void updateCardStyle();

    // 单元控件结构体：包含单元名称标签和权重标签
    struct UnitWidgets {
        QLabel *nameLabel;   // 单元名称标签
        QLabel *weightLabel; // 权重百分比标签
    };

    int m_courseId;
    bool m_selected = false;
    QLabel *m_titleLabel;           // 科目标题
    QCheckBox *m_statsCheck;         // 统计开关复选框
    QList<UnitWidgets> m_units;      // 单元控件列表

    QGridLayout *m_weightLayout;     // 权重表格布局
    int m_nextRow;                    // 下一行可用的行号
};

#endif // SUBJECTCARD_H
