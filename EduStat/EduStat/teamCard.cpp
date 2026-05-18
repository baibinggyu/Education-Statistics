#include "teamCard.h"
#include <QHBoxLayout>
#include <QSpacerItem>

TeamCard::TeamCard(QWidget *parent)
    : QWidget{parent}
{
    this->mainLayout = new QVBoxLayout(this);
    this->mainLayout->setContentsMargins(12, 12, 12, 12);
    this->mainLayout->setSpacing(8);
    this->setStyleSheet(
        "TeamCard {"
        "    background:qlineargradient(x1:0,y1:0,x2:1,y2:1, stop:0 #242b31, stop:1 #1d2328);"
        "    border:1px solid #39434a;"
        "    border-radius:18px;"
        "}"
    );

    auto* headerLayout = new QHBoxLayout();
    headerLayout->setContentsMargins(0, 0, 0, 0);
    headerLayout->setSpacing(8);

    this->teamLabel = new QLabel("未命名小组", this);
    this->teamLabel->setStyleSheet(
        "font-size:12px;"
        "font-weight:700;"
        "color:#f4f7f8;"
        "letter-spacing:1px;"
    );

    this->memberCountLabel = new QLabel("0 人", this);
    this->memberCountLabel->setAlignment(Qt::AlignCenter);
    this->memberCountLabel->setMinimumWidth(56);
    this->memberCountLabel->setStyleSheet(
        "background:#0f766e;"
        "color:#f8fffe;"
        "padding:4px 10px;"
        "border-radius:10px;"
        "font-size:8px;"
        "font-weight:600;"
    );

    headerLayout->addWidget(this->teamLabel);
    headerLayout->addStretch();
    headerLayout->addWidget(this->memberCountLabel);
    this->mainLayout->addLayout(headerLayout);

    this->summaryLabel = new QLabel("成员列表", this);
    this->summaryLabel->setStyleSheet(
        "color:#8fa1ab;"
        "font-size:8px;"
        "padding-left:2px;"
        "padding-bottom:1px;"
    );
    this->mainLayout->addWidget(this->summaryLabel);

    this->scrollArea = new QScrollArea(this);
    this->scrollArea->setFrameShape(QFrame::NoFrame);
    this->scrollArea->setWidgetResizable(true);
    this->scrollArea->setHorizontalScrollBarPolicy(Qt::ScrollBarAlwaysOff);
    this->scrollArea->setVerticalScrollBarPolicy(Qt::ScrollBarAsNeeded);
    this->scrollArea->setStyleSheet(
        "QScrollArea {"
        "    background:#15191d;"
        "    border:1px solid #2d353b;"
        "    border-radius:12px;"
        "}"
        "QScrollBar:vertical {"
        "    border:none;"
        "    background:transparent;"
        "    width:8px;"
        "    margin:8px 2px 8px 0px;"
        "}"
        "QScrollBar::handle:vertical {"
        "    background:#53636d;"
        "    border-radius:4px;"
        "    min-height:24px;"
        "}"
        "QScrollBar::handle:vertical:hover {"
        "    background:#617783;"
        "}"
        "QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical,"
        "QScrollBar::add-page:vertical, QScrollBar::sub-page:vertical {"
        "    height:0px;"
        "    background:none;"
        "}"
    );

    this->membersWidget = new QWidget(this->scrollArea);
    this->membersWidget->setStyleSheet("background:transparent;");
    this->membersLayout = new QVBoxLayout(this->membersWidget);
    this->membersLayout->setContentsMargins(7, 7, 7, 7);
    this->membersLayout->setSpacing(7);
    this->membersLayout->addStretch();

    this->scrollArea->setWidget(this->membersWidget);
    this->mainLayout->addWidget(this->scrollArea);
    this->setFixedHeight(FixdHeight);
    this->setMinimumWidth(250);
}

void TeamCard::setTeamName(const QString &name)
{
    this->teamName = name;
    this->teamLabel->setText(this->teamName);
    this->summaryLabel->setText(QString("当前共 %1 名成员").arg(this->members.size()));
}

void TeamCard::addMember(const QString &name)
{
    this->members.push_back(name);

    auto* memberFrame = new QFrame(this->membersWidget);
    memberFrame->setStyleSheet(
        "QFrame {"
        "    background:#20272c;"
        "    border:1px solid #344048;"
        "    border-radius:12px;"
        "}"
    );

    auto* memberLayout = new QHBoxLayout(memberFrame);
    memberLayout->setContentsMargins(9, 7, 9, 7);
    memberLayout->setSpacing(7);

    auto* avatarLabel = new QLabel(name.left(1), memberFrame);
    avatarLabel->setAlignment(Qt::AlignCenter);
    avatarLabel->setFixedSize(24, 24);
    avatarLabel->setStyleSheet(
        "background:#0f766e;"
        "color:#effffd;"
        "border-radius:12px;"
        "font-size:9px;"
        "font-weight:700;"
    );

    auto* memberLabel = new QLabel(name, memberFrame);
    memberLabel->setStyleSheet(
        "color:#edf2f4;"
        "font-size:10px;"
        "font-weight:600;"
    );

    auto* roleLabel = new QLabel("成员", memberFrame);
    roleLabel->setStyleSheet(
        "color:#8ea3ad;"
        "font-size:8px;"
        "background:#182026;"
        "border:1px solid #33414b;"
        "border-radius:8px;"
        "padding:2px 6px;"
    );

    memberLayout->addWidget(avatarLabel);
    memberLayout->addWidget(memberLabel);
    memberLayout->addStretch();
    memberLayout->addWidget(roleLabel);

    this->membersLayout->insertWidget(this->membersLayout->count() - 1, memberFrame);
    this->memberCountLabel->setText(QString("%1 人").arg(this->members.size()));
    this->summaryLabel->setText(QString("当前共 %1 名成员").arg(this->members.size()));
}

