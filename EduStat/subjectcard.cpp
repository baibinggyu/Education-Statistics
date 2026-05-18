#include "subjectcard.h"
#include <QGridLayout>
#include <QFrame>

SubjectCard::SubjectCard(int courseId, const QString &subjectName, QWidget *parent)
    : QWidget(parent)
    , m_courseId(courseId)
    , m_nextRow(2)  // 从第2行开始（0是表头，1是分隔线）
{
    // 设置卡片固定大小
    setFixedSize(260, 200);
    setCursor(Qt::PointingHandCursor);

    // 主布局
    QVBoxLayout *mainLayout = new QVBoxLayout(this);
    mainLayout->setSpacing(5);
    mainLayout->setContentsMargins(8, 8, 8, 8);

    // 标题行
    QHBoxLayout *titleLayout = new QHBoxLayout();
    m_titleLabel = new QLabel(subjectName);

    QPushButton *deleteBtn = new QPushButton("X");
    deleteBtn->setFixedSize(20, 20);
    connect(deleteBtn, &QPushButton::clicked, this, &SubjectCard::deleteClicked);

    titleLayout->addWidget(m_titleLabel);
    titleLayout->addStretch();
    titleLayout->addWidget(deleteBtn);

    // 统计开关
    QHBoxLayout *statsLayout = new QHBoxLayout();
    m_statsCheck = new QCheckBox("统计分数");
    m_statsCheck->setChecked(true);
    connect(m_statsCheck, &QCheckBox::toggled, this, &SubjectCard::statsToggled);
    statsLayout->addWidget(m_statsCheck);
    statsLayout->addStretch();

    // 单元权重表格
    m_weightLayout = new QGridLayout();
    m_weightLayout->setSpacing(5);

    // 表头
    m_weightLayout->addWidget(new QLabel("单元"), 0, 0);
    m_weightLayout->addWidget(new QLabel("权重"), 0, 1);

    // 分隔线
    QFrame *line = new QFrame();
    line->setFrameShape(QFrame::HLine);
    line->setFixedHeight(1);
    line->setStyleSheet("background-color: #dddddd;");
    m_weightLayout->addWidget(line, 1, 0, 1, 2);

    // 组装
    mainLayout->addLayout(titleLayout);
    mainLayout->addLayout(statsLayout);
    mainLayout->addLayout(m_weightLayout);
    mainLayout->addStretch();
    this->updateCardStyle();
}

void SubjectCard::addUnit(const QString &unitName, int weight)
{
    // 创建单元名称标签
    QLabel *unitLabel;
    if (unitName.isEmpty()) {
        unitLabel = new QLabel(QString("单元%1").arg(m_units.size() + 1));
    } else {
        unitLabel = new QLabel(unitName);
    }

    // 创建权重标签
    QLabel *weightLabel = new QLabel(QString("%1%").arg(weight));
    weightLabel->setAlignment(Qt::AlignRight);
    weightLabel->setFixedWidth(40);

    // 添加到布局
    m_weightLayout->addWidget(unitLabel, m_nextRow, 0);
    m_weightLayout->addWidget(weightLabel, m_nextRow, 1);

    // 保存到列表
    UnitWidgets unit;
    unit.nameLabel = unitLabel;
    unit.weightLabel = weightLabel;
    m_units.append(unit);

    // 更新下一行号
    m_nextRow++;

    // 动态调整卡片高度（可选）
    int newHeight = 200 + (m_units.size() * 25);
    setFixedHeight(qMin(400, newHeight));  // 最大400
}

void SubjectCard::setUnitWeight(int unitIndex, int weight)
{
    if (unitIndex >= 0 && unitIndex < m_units.size()) {
        weight = qBound(0, weight, 100);
        m_units[unitIndex].weightLabel->setText(QString("%1%").arg(weight));
    }
}

void SubjectCard::setUnitName(int unitIndex, const QString &name)
{
    if (unitIndex >= 0 && unitIndex < m_units.size()) {
        if (name.isEmpty()) {
            m_units[unitIndex].nameLabel->setText(QString("单元%1").arg(unitIndex + 1));
        } else {
            m_units[unitIndex].nameLabel->setText(name);
        }
    }
}

void SubjectCard::setStatsEnabled(bool enabled)
{
    m_statsCheck->blockSignals(true);
    m_statsCheck->setChecked(enabled);
    m_statsCheck->blockSignals(false);
}

int SubjectCard::getCourseId() const
{
    return this->m_courseId;
}

bool SubjectCard::isSelected() const
{
    return this->m_selected;
}

void SubjectCard::setSelected(bool selected)
{
    if(this->m_selected == selected){
        return;
    }
    this->m_selected = selected;
    this->updateCardStyle();
}

size_t SubjectCard::getUnitSize() const
{
    return m_units.size();
}

QString SubjectCard::getSubjectName() const
{
    return m_titleLabel->text();
}

void SubjectCard::setSubjectName(const QString &name)
{
    if (!name.isEmpty()) {
        m_titleLabel->setText(name);
    }
}

void SubjectCard::mousePressEvent(QMouseEvent *event)
{
    if(event->button() == Qt::LeftButton){
        emit clicked();
    }
    QWidget::mousePressEvent(event);
}

void SubjectCard::updateCardStyle()
{
    if(this->m_selected){
        setStyleSheet(
            "SubjectCard {"
            "    background-color: #202b31;"
            "    border: 2px solid #0f766e;"
            "    border-radius: 10px;"
            "}"
            "QLabel { color: #f6fbfd; }"
            "QCheckBox { color: #f6fbfd; }"
            "QPushButton { background:#334046; color:white; border:1px solid #4d5d66; border-radius:6px; }"
        );
    }else{
        setStyleSheet(
            "SubjectCard {"
            "    background-color: #1d2227;"
            "    border: 1px solid #3a434c;"
            "    border-radius: 10px;"
            "}"
            "QLabel { color: #edf3f6; }"
            "QCheckBox { color: #edf3f6; }"
            "QPushButton { background:#2b3136; color:white; border:1px solid #414b54; border-radius:6px; }"
        );
    }
}
