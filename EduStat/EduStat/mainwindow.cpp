#include "mainwindow.h"
#include "./ui_mainwindow.h"
#include <QWidget>
#include <QGridLayout>
#include <QPushButton>
#include <spdlog/spdlog.h>
#include <QFile>
#include <QList>
#include <QString>
#include <QDebug>
#include <QScrollArea>
#include <QFileDialog>
#include <QFileInfo>
#include <QFile>
#include <QMessageBox>
#include <QProcess>
#include "subjectcard.h"
#include <QHBoxLayout>
#include <QSet>
#include <QMessageBox>
#include <algorithm>
#include <QtSql/QSqlDatabase>
#include <QSqlQuery>
#include <QSqlError>
#include "scoredelegate.h"
#include <QTextStream>
#include <QDir>
#include <QFileInfo>
#include <QBrush>
#include <QStatusBar>
#include <QApplication>
#include <QStandardPaths>
#include <QDateTime>
#include <QRandomGenerator>
#include <QAbstractAnimation>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QEventLoop>
#include <QTimer>
#include <QUrl>
#include <QUrlQuery>
#include <QSslSocket>
#include <limits>
#include <cmath>
#include "teamCard.h"

namespace {
QString normalizeImportText(QString text)
{
    text = text.trimmed();
    text.remove(QChar(0xFEFF));
    text.remove('\r');
    text.remove('\n');
    text.remove(QChar(0x200B));
    return text.trimmed();
}

QString normalizeSingleLineText(QString text)
{
    text.replace("\r\n", " ");
    text.replace('\n', ' ');
    text.replace('\r', ' ');
    text.remove(QChar(0x200B));
    return text.simplified();
}
}

MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent)
    , ui(new Ui::MainWindow)
{
    ui->setupUi(this);
    this->setWindowTitle("EduStat教学统计系统");
    this->resize(800,600);
    this->ui->classAnalyzetextEdit->setReadOnly(true);
    this->ui->promptPreviewTextEdit->setReadOnly(true);
    this->ui->centralwidget->setStyleSheet(
        "QWidget#centralwidget {"
        "    background:#1f1d1c;"
        "}"
        "QFrame#sideBarFrame {"
        "    background:qlineargradient(x1:0,y1:0,x2:0,y2:1, stop:0 #232528, stop:1 #1b1d20);"
        "    border:1px solid #35383c;"
        "    border-radius:20px;"
        "}"
        "QFrame#subjectSelectorFrame {"
        "    background:#171a1d;"
        "    border:1px solid #2f343a;"
        "    border-radius:16px;"
        "}"
        "QLabel#appTitleLabel {"
        "    color:#f7fafc;"
        "    font-size:16px;"
        "    font-weight:800;"
        "    letter-spacing:0px;"
        "}"
        "QLabel#appSubtitleLabel {"
        "    color:#9eabb5;"
        "    font-size:9px;"
        "    padding-bottom:2px;"
        "}"
        "QLabel#navSectionLabel, QLabel#subjectLabel {"
        "    color:#d7e1e8;"
        "    font-size:10px;"
        "    font-weight:700;"
        "}"
        "QComboBox#subjectComboBox {"
        "    background:#23292e;"
        "    border:1px solid #384049;"
        "    border-radius:11px;"
        "    color:#f4f7f8;"
        "    min-height:24px;"
        "    padding:3px 10px;"
        "}"
        "QComboBox#subjectComboBox::drop-down {"
        "    border:none;"
        "    width:22px;"
        "    subcontrol-origin: padding;"
        "    subcontrol-position: top right;"
        "}"
        "QComboBox#subjectComboBox::down-arrow {"
        "    width:10px;"
        "    height:10px;"
        "}"
        "QComboBox#subjectComboBox QAbstractItemView {"
        "    background:#23292e;"
        "    color:#f4f7f8;"
        "    border:1px solid #384049;"
        "    selection-background-color:#0f766e;"
        "    selection-color:white;"
        "}"
        "QPushButton#classInformationPushButton, QPushButton#exportInformationPushButton, QPushButton#subjectManagePushButton,"
        "QPushButton#studentInfomationpushButton, QPushButton#rollCallPushButton, QPushButton#teamUpPushButton {"
        "    text-align:left;"
        "    padding:7px 10px;"
        "    min-height:28px;"
        "    background:#24282d;"
        "    color:#eef3f5;"
        "    border:1px solid #353d45;"
        "    border-radius:10px;"
        "    font-size:10px;"
        "    font-weight:600;"
        "}"
        "QPushButton#classInformationPushButton:hover, QPushButton#exportInformationPushButton:hover, QPushButton#subjectManagePushButton:hover,"
        "QPushButton#studentInfomationpushButton:hover, QPushButton#rollCallPushButton:hover, QPushButton#teamUpPushButton:hover {"
        "    background:#2b3238;"
        "    border-color:#485560;"
        "}"
        "QPushButton#classInformationPushButton:pressed, QPushButton#exportInformationPushButton:pressed, QPushButton#subjectManagePushButton:pressed,"
        "QPushButton#studentInfomationpushButton:pressed, QPushButton#rollCallPushButton:pressed, QPushButton#teamUpPushButton:pressed {"
        "    background:#0f766e;"
        "    border-color:#0f766e;"
        "}"
    );

    // MOC 班级信息页
    QObject::connect(ui->classInformationPushButton,&QPushButton::clicked,[this]{
        this->ui->stackedWidget->setCurrentWidget(this->ui->classInformationPage);
        this->updateClassInformationPage();
    });
    QObject::connect(this->ui->classRefreshPushButton, &QPushButton::clicked, this, &MainWindow::updateClassInformationPage);
    this->ui->classInformationPage->setStyleSheet(
        "QWidget#classInformationPage {"
        "    background:qlineargradient(x1:0,y1:0,x2:1,y2:1, stop:0 #1d1f23, stop:1 #23262c);"
        "}"
        "QFrame#classInfoOverviewFrame, QFrame#classAnalyzeSidePanel, QFrame#barChartFrame, QFrame#pieChartFrame, QFrame#lineChartFrame {"
        "    background:#20242a;"
        "    border:1px solid #313840;"
        "    border-radius:18px;"
        "}"
        "QFrame#studentCountCardFrame, QFrame#overallAverageCardFrame, QFrame#bestUnitCardFrame, QFrame#weakestUnitCardFrame {"
        "    background:qlineargradient(x1:0,y1:0,x2:1,y2:1, stop:0 #171b1f, stop:1 #1d2328);"
        "    border:1px solid #2d3640;"
        "    border-radius:14px;"
        "}"
        "QLabel#classInfoHeaderLabel, QLabel#classAnalyzeLabel, QLabel#promptPreviewLabel, QLabel#barChartTitleLabel, QLabel#pieChartTitleLabel, QLabel#lineChartTitleLabel {"
        "    color:#f7fafc;"
        "    font-size:14px;"
        "    font-weight:700;"
        "}"
        "QLabel#classInfoHintLabel, QLabel#analysisStatusValueLabel, QLabel#networkStatusValueLabel {"
        "    background:#161a1e;"
        "    border:1px solid #2a3137;"
        "    border-radius:12px;"
        "    color:#b3c0c8;"
        "    padding:10px 12px;"
        "    font-size:10px;"
        "}"
        "QLabel#studentCountTitleLabel, QLabel#overallAverageTitleLabel, QLabel#bestUnitTitleLabel, QLabel#weakestUnitTitleLabel {"
        "    color:#8ea1ad;"
        "    font-size:10px;"
        "    font-weight:600;"
        "}"
        "QLabel#studentCountValueLabel, QLabel#overallAverageValueLabel, QLabel#bestUnitValueLabel, QLabel#weakestUnitValueLabel {"
        "    color:#f8fbfc;"
        "    font-size:18px;"
        "    font-weight:800;"
        "}"
        "QPushButton#classRefreshPushButton {"
        "    background:#0f766e;"
        "    color:white;"
        "    border:none;"
        "    border-radius:11px;"
        "    padding:8px 14px;"
        "    font-size:10px;"
        "    font-weight:700;"
        "}"
        "QPushButton#classRefreshPushButton:hover {"
        "    background:#129089;"
        "}"
        "QPushButton#classRefreshPushButton:pressed {"
        "    background:#0b5a55;"
        "    padding-top:10px;"
        "    padding-bottom:6px;"
        "}"
        "QPushButton#classRefreshPushButton:disabled {"
        "    background:#355b59;"
        "    color:#d6ece9;"
        "}"
        "QTextEdit#classAnalyzetextEdit, QTextEdit#promptPreviewTextEdit {"
        "    background:#14181c;"
        "    border:1px solid #293137;"
        "    border-radius:14px;"
        "    color:#edf3f6;"
        "    padding:10px;"
        "    font-size:11px;"
        "}"
    );
    // 点名页
    QObject::connect(ui->rollCallPushButton,&QPushButton::clicked,[this]{this->ui->stackedWidget->setCurrentWidget(this->ui->rollCallPage);});
    this->ui->rollCallPage->setStyleSheet(
        "QWidget#rollCallPage {"
        "    background:qlineargradient(x1:0,y1:0,x2:1,y2:1, stop:0 #1c1d20, stop:1 #24272b);"
        "}"
        "QFrame#rollCallSidePanel, QFrame#rollCallResultFrame {"
        "    background:#202428;"
        "    border:1px solid #333a40;"
        "    border-radius:16px;"
        "}"
        "QLabel#rollCallTitleLabel, QLabel#rollCallRuleLabel, QLabel#rollCallHistoryLabel, QLabel#label {"
        "    color:#f4f7f8;"
        "    font-size:13px;"
        "    font-weight:700;"
        "}"
        "QLabel#rollCallSummaryLabel, QLabel#rollCallHintLabel, QLabel#rollCallResultSummaryLabel {"
        "    color:#aab8c1;"
        "    background:#171b1e;"
        "    border:1px solid #2a3136;"
        "    border-radius:10px;"
        "    padding:10px;"
        "    font-size:10px;"
        "}"
        "QFrame#rollCallHighlightFrame {"
        "    background:qlineargradient(x1:0,y1:0,x2:1,y2:1, stop:0 #0f766e, stop:1 #125f73);"
        "    border:1px solid #2aa49b;"
        "    border-radius:16px;"
        "}"
        "QLabel#rollCallHighlightTitleLabel {"
        "    color:#dff8f5;"
        "    font-size:10px;"
        "    font-weight:600;"
        "    letter-spacing:1px;"
        "}"
        "QLabel#rollCallHighlightNameLabel {"
        "    color:white;"
        "    font-size:28px;"
        "    font-weight:800;"
        "    padding-top:4px;"
        "}"
        "QLabel#rollCallHighlightMetaLabel {"
        "    color:#d7f0ec;"
        "    font-size:11px;"
        "    padding-bottom:2px;"
        "}"
        "QLabel#label_2, QLabel#rollCallModeLabel {"
        "    color:#dde6ea;"
        "    font-size:10px;"
        "    font-weight:600;"
        "}"
        "QComboBox#rollCallModeComboBox, QSpinBox#spinBox {"
        "    background:#161a1d;"
        "    border:1px solid #30363b;"
        "    border-radius:9px;"
        "    color:#eff4f6;"
        "    min-height:28px;"
        "    padding:2px 8px;"
        "    font-size:10px;"
        "}"
        "QCheckBox#rollCallShowClassCheckBox {"
        "    color:#dbe4e9;"
        "    spacing:6px;"
        "    font-size:10px;"
        "}"
        "QCheckBox#rollCallShowClassCheckBox::indicator {"
        "    width:14px;"
        "    height:14px;"
        "    border-radius:4px;"
        "    border:1px solid #44606b;"
        "    background:#161a1d;"
        "}"
        "QCheckBox#rollCallShowClassCheckBox::indicator:checked {"
        "    background:#0f766e;"
        "    border:1px solid #0f766e;"
        "    image:url(:/checkmark.svg);"
        "}"
        "QPushButton#pushButton_2 {"
        "    background:#0f766e;"
        "    color:white;"
        "    border:none;"
        "    border-radius:10px;"
        "    padding:8px 12px;"
        "    font-size:10px;"
        "    font-weight:700;"
        "}"
        "QPushButton#resetRollCallPushButton {"
        "    background:#262d32;"
        "    color:#dce7eb;"
        "    border:1px solid #3a444b;"
        "    border-radius:10px;"
        "    padding:8px 12px;"
        "    font-size:10px;"
        "    font-weight:600;"
        "}"
        "QPlainTextEdit#plainTextEdit, QListWidget#rollCallHistoryListWidget {"
        "    background:#15191d;"
        "    border:1px solid #2b3338;"
        "    border-radius:12px;"
        "    color:#eff4f6;"
        "    font-size:11px;"
        "    padding:8px;"
        "}"
        "QListWidget#rollCallHistoryListWidget::item {"
        "    padding:7px 9px;"
        "    border-radius:8px;"
        "    margin:2px 0px;"
        "}"
        "QListWidget#rollCallHistoryListWidget::item:selected {"
        "    background:#0f766e;"
        "    color:white;"
        "}"
    );
    this->rollCallHighlightEffect_ = new QGraphicsOpacityEffect(this->ui->rollCallHighlightFrame);
    this->rollCallHighlightEffect_->setOpacity(1.0);
    this->ui->rollCallHighlightFrame->setGraphicsEffect(this->rollCallHighlightEffect_);
    this->rollCallHighlightAnimation_ = new QPropertyAnimation(this->rollCallHighlightEffect_, "opacity", this);
    this->rollCallHighlightAnimation_->setDuration(320);
    this->rollCallHighlightAnimation_->setStartValue(0.35);
    this->rollCallHighlightAnimation_->setEndValue(1.0);
    QObject::connect(this->ui->pushButton_2,&QPushButton::clicked,this,&MainWindow::startRollCall);
    QObject::connect(this->ui->resetRollCallPushButton,&QPushButton::clicked,this,&MainWindow::resetRollCallHistory);

    // 组队页
    QObject::connect(ui->teamUpPushButton,&QPushButton::clicked,[this]{this->ui->stackedWidget->setCurrentWidget(this->ui->teamUpPage);});
    // teamUpPage中的flowLayout配置
    this->ui->teamUpScrollArea->setWidgetResizable(true);
    this->teamUpFlowLayout = new FlowLayout(this->ui->teamUpScrollArea);
    this->ui->teampUpScrollAreaWidgetContents->setLayout(this->teamUpFlowLayout);
    this->ui->teamUpPage->setStyleSheet(
        "QWidget#teamUpPage {"
        "    background:qlineargradient(x1:0,y1:0,x2:1,y2:1, stop:0 #1e1f22, stop:1 #232529);"
        "}"
        "QLabel#currentTeamGroupLabel, QLabel#teamRuleLabel, QLabel#teamHistoryLabel, QLabel#teamCanvasLabel {"
        "    color:#f4f7f8;"
        "    font-size:12px;"
        "    font-weight:700;"
        "    padding-bottom:1px;"
        "}"
        "QLabel#currentTeamSummaryLabel {"
        "    background:#181c1f;"
        "    border:1px solid #2b3136;"
        "    border-radius:10px;"
        "    padding:10px;"
        "    color:#b4c0c8;"
        "    font-size:10px;"
        "    line-height:1.3;"
        "}"
        "QLabel#teamRuleHintLabel {"
        "    background:#151a1d;"
        "    border-left:3px solid #0f766e;"
        "    border-radius:8px;"
        "    padding:8px 10px;"
        "    color:#95aab3;"
        "    font-size:10px;"
        "}"
        "QLabel#teamSizeLabel, QLabel#teamModeLabel {"
        "    color:#d8e1e6;"
        "    font-size:10px;"
        "    font-weight:600;"
        "}"
        "QComboBox#teamModeComboBox, QSpinBox#teamSizeSpinBox {"
        "    background:#171b1e;"
        "    border:1px solid #30363b;"
        "    border-radius:9px;"
        "    color:#eef3f5;"
        "    min-height:28px;"
        "    padding:2px 8px;"
        "    font-size:10px;"
        "}"
        "QComboBox#teamModeComboBox::drop-down {"
        "    border:none;"
        "    width:20px;"
        "}"
        "QCheckBox#useScoreCheckBox {"
        "    color:#dde7eb;"
        "    spacing:6px;"
        "    font-size:10px;"
        "}"
        "QCheckBox#useScoreCheckBox::indicator {"
        "    width:14px;"
        "    height:14px;"
        "    border-radius:4px;"
        "    border:1px solid #44606b;"
        "    background:#161a1d;"
        "}"
        "QCheckBox#useScoreCheckBox::indicator:checked {"
        "    background:#0f766e;"
        "    border:1px solid #0f766e;"
        "    image:url(:/checkmark.svg);"
        "}"
        "QPushButton#generateTeamsPushButton {"
        "    background:#0f766e;"
        "    color:white;"
        "    border:none;"
        "    border-radius:10px;"
        "    padding:7px 11px;"
        "    font-size:10px;"
        "    font-weight:700;"
        "}"
        "QPushButton#generateTeamsPushButton:hover { background:#129287; }"
        "QPushButton#saveTeamHistoryPushButton {"
        "    background:#262d32;"
        "    color:#dce7eb;"
        "    border:1px solid #3a444b;"
        "    border-radius:10px;"
        "    padding:7px 11px;"
        "    font-size:10px;"
        "    font-weight:600;"
        "}"
        "QPushButton#saveTeamHistoryPushButton:hover { background:#2d353b; }"
        "QScrollArea#teamUpScrollArea {"
        "    background:#1a1d20;"
        "    border:1px solid #33383d;"
        "    border-radius:16px;"
        "}"
        "QScrollArea#teamUpScrollArea > QWidget > QWidget { background:transparent; }"
        "QScrollBar:vertical {"
        "    border:none;"
        "    background:transparent;"
        "    width:10px;"
        "    margin:10px 4px 10px 0px;"
        "}"
        "QScrollBar::handle:vertical {"
        "    background:#46525a;"
        "    border-radius:5px;"
        "    min-height:26px;"
        "}"
        "QScrollBar::handle:vertical:hover { background:#596973; }"
        "QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical,"
        "QScrollBar::add-page:vertical, QScrollBar::sub-page:vertical {"
        "    height:0px;"
        "    background:none;"
        "}"
    );
    this->ui->teamSidePanel->setStyleSheet(
        "QFrame#teamSidePanel {"
        "    background:qlineargradient(x1:0,y1:0,x2:0,y2:1, stop:0 #23282c, stop:1 #1a1e21);"
        "    border:1px solid #353d43;"
        "    border-radius:16px;"
        "}"
        "QListWidget {"
        "    background:#14181b;"
        "    border:1px solid #2c3338;"
        "    border-radius:10px;"
        "    padding:4px;"
        "    color:#e7ecef;"
        "    font-size:10px;"
        "}"
        "QListWidget::item {"
        "    padding:7px 9px;"
        "    border-radius:8px;"
        "    margin:2px 0px;"
        "    border:1px solid transparent;"
        "}"
        "QListWidget::item:hover { background:#1d2327; border:1px solid #2d383f; }"
        "QListWidget::item:selected { background:#0f766e; color:white; }"
    );
    QObject::connect(this->ui->generateTeamsPushButton,&QPushButton::clicked,this,&MainWindow::generateTeams);
    QObject::connect(this->ui->saveTeamHistoryPushButton,&QPushButton::clicked,this,&MainWindow::saveCurrentTeamsToHistory);
    QObject::connect(this->ui->teamHistoryListWidget,&QListWidget::itemDoubleClicked,this,&MainWindow::restoreTeamHistory);

    // 导入学生信息
    QObject::connect(this->ui->loadStudentInformationPushButton,&QPushButton::clicked,this,&MainWindow::loadStudentInformation);
    // 学生信息管理页面
    QObject::connect(this->ui->studentInfomationpushButton,&QPushButton::clicked,[this]{
        this->ui->stackedWidget->setCurrentWidget(this->ui->studentInformationPage);
    });
    this->subjectManageFlowLayout = new FlowLayout(this->ui->subjectManageScrollAreaWidgetContents);
    this->ui->subjectManageScrollAreaWidgetContents->setLayout(this->subjectManageFlowLayout);
    this->ui->studentInformationTableWidget->setSelectionBehavior(QAbstractItemView::SelectRows);
    this->ui->studentInformationTableWidget->setSelectionMode(QAbstractItemView::ExtendedSelection);
    this->ui->studentInformationTableWidget->setWordWrap(false);
    this->ui->studentInformationTableWidget->setHorizontalScrollMode(QAbstractItemView::ScrollPerPixel);
    this->ui->studentInformationTableWidget->setHorizontalScrollBarPolicy(Qt::ScrollBarAsNeeded);
    this->ui->studentInformationTableWidget->verticalHeader()->setDefaultSectionSize(42);
    QObject::connect(this->ui->studentInformationTableWidget,&QTableWidget::itemChanged,this,&MainWindow::studentInformationItemChanged);
    QObject::connect(this->ui->AddStudentSimplePushButton,&QPushButton::clicked,this,&MainWindow::addStudentInformation);
    QObject::connect(this->ui->studentInformationPushButton,&QPushButton::clicked,this,&MainWindow::saveStudentInformation);
    QObject::connect(this->ui->searchPushButton,&QPushButton::clicked,this,&MainWindow::searchStudentInformation);
    QObject::connect(this->ui->searchLineEdit,&QLineEdit::returnPressed,this,&MainWindow::searchStudentInformation);
    QObject::connect(this->ui->searchLineEdit,&QLineEdit::textChanged,this,[this](const QString&){
        this->searchStudentInformation();
    });
    // 删除学生信息
    QObject::connect(this->ui->studentDeleteSelectedPushButton,&QPushButton::clicked,this,&MainWindow::studentDeleteSelected);

    // 导出学生信息
    QObject::connect(this->ui->exportStudentPushButton,&QPushButton::clicked,this,&MainWindow::exportStudentInformation);

    // 学科管理页面
    QObject::connect(this->ui->subjectManagePushButton,&QPushButton::clicked,[this]{
        this->ui->stackedWidget->setCurrentWidget(this->ui->subjectManagePage);
        this->updateSubjectManagePage();
    });
    QObject::connect(this->ui->exportInformationPushButton, &QPushButton::clicked, this, &MainWindow::exportSemesterReport);
    // 增加科学课
    QObject::connect(this->ui->addSubjectPushButton,&QPushButton::clicked,[this]{
        this->ui->addSubjectIdLineEdit->setText(QString::number(this->nextSubjectId()));
        this->ui->stackedWidget->setCurrentWidget(this->ui->addSubjectPage);
    });
    QObject::connect(this->ui->deleteSubjectPushButton, &QPushButton::clicked, [this]{
        if(!this->selectedSubjectCard_){
            QMessageBox::information(this, "提示", "请先选择要删除的学科卡片", QMessageBox::Ok);
            return;
        }
        this->deleteSubjectCard(this->selectedSubjectCard_);
    });
    // 增加课学页面返回学科管理页面
    QObject::connect(this->ui->addSubjectReturnSubjectManagePushButton,&QPushButton::clicked,[this]{this->ui->stackedWidget->setCurrentWidget(this->ui->subjectManagePage);});

    // 添加课程
    // 增加课程中的删除单元行
    QObject::connect(this->ui->addSubjectDeleteSelectedLinePushButton,&QPushButton::clicked,this,&MainWindow::addSubjectDeleteTableWidgetLine);
    // 增加课程中的单元
    QObject::connect(this->ui->addSubjectUintLinePushButton,&QPushButton::clicked,this,&MainWindow::addSubjectAddUnitLine);
    // 添加可以多行选中
    ui->addSubjectTableWidget->setSelectionBehavior(QAbstractItemView::SelectRows);
    ui->addSubjectTableWidget->setSelectionMode(QAbstractItemView::ExtendedSelection);

    // sqllite 数据库处理
    this->initSQLite();

    // 禁用修改权重和
    this->ui->addSubjectIdLineEdit->setReadOnly(true);
    this->ui->addSubjectWeightLineEdit->setReadOnly(true);
    // 设置权重初始化为0
    this->ui->addSubjectIdLineEdit->setText(QString::number(this->nextSubjectId()));
    this->ui->addSubjectWeightLineEdit->setText("0");
    // 设置item，保证不出现比例分数为中文
    this->ui->addSubjectTableWidget->setItemDelegateForColumn(
        1,
        new WeightDelegate(this)
        );
    this->ui->addSubjectTableWidget->setItemDelegateForColumn(
        2,
        new WeightDelegate(this)
        );
    this->ui->addSubjectTableWidget->horizontalHeader()->setSectionResizeMode(QHeaderView::Stretch);
    // 自动调整单元权重
    QObject::connect(this->ui->addSubjectAdjustedWeightPushButton,&QPushButton::clicked,this,&MainWindow::addSubjectAdjustedWeight);
    // 完成添加学科操作
    QObject::connect(this->ui->addSubjectCompletedAndExitPushButton,&QPushButton::clicked,this,&MainWindow::addSubjectCompletedAndExit);

    QObject::connect(
        this->ui->subjectComboBox,
        QOverload<int>::of(&QComboBox::currentIndexChanged),
        this,
        [this](int){
            this->updateStudentInformationTable();
            this->updateClassInformationPage();
            this->currentTeams_.clear();
            this->teamHistory_.clear();
            this->teamHistoryIndex_ = 1;
            this->ui->teamHistoryListWidget->clear();
            this->resetRollCallHistory();
            this->renderTeams(this->currentTeams_);
            this->updateTeamSummaryText();
        }
    );

    this->updateSubjectComboBox();
    this->updateStudentInformationTable();
    this->updateClassInformationPage();
    this->updateSubjectManagePage();
}

MainWindow::~MainWindow()
{
    this->db.close();
    delete ui;
}

QList<MainWindow::TeamStudentInfo> MainWindow::loadStudentsForTeamUp()
{
    QList<TeamStudentInfo> students;
    int courseId = this->ui->subjectComboBox->currentData().toInt();
    if(courseId <= 0){
        return students;
    }

    QSqlQuery query(this->db);
    query.prepare(R"(
        SELECT s.student_id, s.name, s.class, COALESCE(AVG(sc.score), 0)
        FROM student s
        JOIN score sc ON sc.student_id = s.student_id AND sc.course_id = ?
        WHERE EXISTS (
            SELECT 1
            FROM score sc2
            WHERE sc2.student_id = s.student_id
              AND sc2.course_id = ?
        )
        GROUP BY s.student_id, s.name, s.class
        ORDER BY s.student_id ASC
    )");
    query.addBindValue(courseId);
    query.addBindValue(courseId);
    if(!query.exec()){
        spdlog::error("loadStudentsForTeamUp failed: {}", query.lastError().text().toStdString());
        return students;
    }

    while(query.next()){
        TeamStudentInfo info;
        info.studentId = query.value(0).toString();
        info.name = query.value(1).toString();
        info.className = query.value(2).toString();
        info.averageScore = query.value(3).toDouble();
        students.append(info);
    }
    return students;
}

QList<MainWindow::RollCallStudentInfo> MainWindow::loadStudentsForRollCall()
{
    QList<RollCallStudentInfo> students;
    int courseId = this->ui->subjectComboBox->currentData().toInt();
    if(courseId <= 0){
        return students;
    }

    QSqlQuery query(this->db);
    query.prepare(R"(
        SELECT DISTINCT s.student_id, s.name, s.class
        FROM score sc
        JOIN student s ON s.student_id = sc.student_id
        WHERE sc.course_id = ?
        ORDER BY s.student_id ASC
    )");
    query.addBindValue(courseId);
    if(!query.exec()){
        spdlog::error("loadStudentsForRollCall failed: {}", query.lastError().text().toStdString());
        return students;
    }

    while(query.next()){
        RollCallStudentInfo info;
        info.studentId = query.value(0).toString();
        info.name = query.value(1).toString();
        info.className = query.value(2).toString();
        students.append(info);
    }
    return students;
}

void MainWindow::updateRollCallSummaryText(const QString &text)
{
    this->ui->rollCallResultSummaryLabel->setText(text);
}

void MainWindow::animateRollCallHighlight()
{
    if(this->rollCallHighlightAnimation_ == nullptr){
        return;
    }
    if(this->rollCallHighlightAnimation_->state() == QAbstractAnimation::Running){
        this->rollCallHighlightAnimation_->stop();
    }
    this->rollCallHighlightAnimation_->start();
}

// AI辅助参考：Codex（基于 ChatGPT 5.4），2026-03
// 用途：班级信息模块的数据汇总与图表统计逻辑设计
// 说明：基础统计维度与可视化组织思路参考 AI 建议，后续已结合项目实际需求完成人工重构
bool MainWindow::loadCourseAnalysisData(CourseAnalysisData &data)
{
    int courseId = this->ui->subjectComboBox->currentData().toInt();
    if(courseId <= 0){
        return false;
    }

    data = CourseAnalysisData{};
    data.courseName = this->ui->subjectComboBox->currentText().trimmed();

    QSqlQuery unitQuery(this->db);
    unitQuery.prepare(R"(
        SELECT name, weight, score
        FROM unit
        WHERE course_id = ?
        ORDER BY unit_order ASC
    )");
    unitQuery.addBindValue(courseId);
    if(!unitQuery.exec()){
        spdlog::error("loadCourseAnalysisData load units failed: {}", unitQuery.lastError().text().toStdString());
        return false;
    }

    while(unitQuery.next()){
        data.unitNames << unitQuery.value(0).toString();
        data.unitWeights << unitQuery.value(1).toDouble();
        data.unitFullScores << qMax(1, unitQuery.value(2).toInt());
    }
    if(data.unitNames.isEmpty()){
        return false;
    }
    data.unitAverages = QVector<double>(data.unitNames.size(), 0.0);
    QVector<int> unitCount(data.unitNames.size(), 0);

    QSqlQuery studentQuery(this->db);
    studentQuery.prepare(R"(
        SELECT DISTINCT s.student_id, s.name, s.class
        FROM score sc
        JOIN student s ON s.student_id = sc.student_id
        WHERE sc.course_id = ?
        ORDER BY s.student_id ASC
    )");
    studentQuery.addBindValue(courseId);
    if(!studentQuery.exec()){
        spdlog::error("loadCourseAnalysisData load students failed: {}", studentQuery.lastError().text().toStdString());
        return false;
    }

    QList<RollCallStudentInfo> students;
    while(studentQuery.next()){
        RollCallStudentInfo student;
        student.studentId = studentQuery.value(0).toString();
        student.name = studentQuery.value(1).toString();
        student.className = studentQuery.value(2).toString();
        students.append(student);
        data.classCounts[student.className] += 1;
    }
    if(students.isEmpty()){
        return false;
    }

    for(const auto& student : students){
        double studentSum = 0.0;
        int studentScoreCount = 0;
        StudentAnalysisInfo studentDetail;
        studentDetail.studentId = student.studentId;
        studentDetail.name = student.name;
        studentDetail.className = student.className;
        studentDetail.unitScores = QVector<double>(data.unitNames.size(), std::numeric_limits<double>::quiet_NaN());

        double weightedTotal = 0.0;
        double totalWeight = 0.0;
        for(double weight : data.unitWeights){
            if(weight > 0.0){
                totalWeight += weight;
            }
        }
        for(int i = 0; i < data.unitNames.size(); i++){
            QSqlQuery scoreQuery(this->db);
            scoreQuery.prepare(R"(
                SELECT score
                FROM score
                WHERE student_id = ? AND course_id = ? AND unit_name = ?
            )");
            scoreQuery.addBindValue(student.studentId);
            scoreQuery.addBindValue(courseId);
            scoreQuery.addBindValue(data.unitNames[i]);
            if(!scoreQuery.exec()){
                spdlog::error("loadCourseAnalysisData load score failed: {}", scoreQuery.lastError().text().toStdString());
                return false;
            }
            if(scoreQuery.next() && !scoreQuery.value(0).isNull()){
                double value = scoreQuery.value(0).toDouble();
                studentDetail.unitScores[i] = value;
                data.unitAverages[i] += value;
                unitCount[i] += 1;
                studentSum += value;
                studentScoreCount += 1;
                double weight = i < data.unitWeights.size() ? data.unitWeights[i] : 0.0;
                int fullScore = i < data.unitFullScores.size() ? qMax(1, data.unitFullScores[i]) : 100;
                if(weight > 0.0){
                    weightedTotal += (value / fullScore) * weight * 100.0;
                }
            }
        }

        if(studentScoreCount > 0){
            double studentAverage = studentSum / studentScoreCount;
            data.studentAverages.append(studentAverage);
            studentDetail.averageScore = studentAverage;
        }else{
            data.studentAverages.append(0.0);
            studentDetail.averageScore = 0.0;
        }
        if(totalWeight > 0.0){
            studentDetail.totalScore = weightedTotal / totalWeight;
        }
        data.studentDetails.append(studentDetail);
    }

    for(int i = 0; i < data.unitAverages.size(); i++){
        if(unitCount[i] > 0){
            data.unitAverages[i] /= unitCount[i];
        }
    }

    data.studentCount = data.studentAverages.size();
    if(data.studentCount <= 0){
        return false;
    }

    data.maxAverage = *std::max_element(data.studentAverages.begin(), data.studentAverages.end());
    data.minAverage = *std::min_element(data.studentAverages.begin(), data.studentAverages.end());
    double totalAverage = 0.0;
    for(double value : data.studentAverages){
        totalAverage += value;
        if(value >= 90){
            data.scoreBandCounts["90+"] += 1;
        }else if(value >= 80){
            data.scoreBandCounts["80-89"] += 1;
        }else if(value >= 70){
            data.scoreBandCounts["70-79"] += 1;
        }else if(value >= 60){
            data.scoreBandCounts["60-69"] += 1;
        }else{
            data.scoreBandCounts["<60"] += 1;
        }
    }
    data.overallAverage = totalAverage / data.studentCount;
    return true;
}

// AI辅助参考：Codex（基于 ChatGPT 5.4），2026-03
// 用途：Qt Charts 柱状图生成（成绩段分布）
// 说明：图表类型选择与基础展示思路参考 AI 建议，后续已人工细化样式与统计内容
void MainWindow::updateBarChart(const CourseAnalysisData &data)
{
    auto* series = new QBarSeries();
    auto* set = new QBarSet("人数分布");
    QFont titleFont("Microsoft YaHei UI", 11, QFont::DemiBold);
    QFont axisFont("Microsoft YaHei UI", 8);
    QStringList categories = {"90+", "80-89", "70-79", "60-69", "<60"};
    for(const auto& category : categories){
        *set << data.scoreBandCounts.value(category, 0);
    }
    set->setColor(QColor("#0f766e"));
    series->append(set);
    series->setBarWidth(0.55);

    auto* chart = new QChart();
    chart->addSeries(series);
    chart->setTitle("成绩段分布");
    chart->setTitleFont(titleFont);
    chart->setBackgroundVisible(false);
    chart->setPlotAreaBackgroundVisible(false);
    chart->setPlotAreaBackgroundBrush(QColor("#181c20"));
    chart->setTitleBrush(QBrush(QColor("#eef6fb")));
    chart->legend()->hide();
    chart->setMargins(QMargins(18, 14, 18, 14));

    auto* axisX = new QBarCategoryAxis();
    axisX->append(categories);
    axisX->setLabelsFont(axisFont);
    axisX->setLabelsBrush(QBrush(QColor("#dbe8f1")));
    axisX->setLabelsColor(QColor("#dbe8f1"));
    axisX->setGridLineColor(QColor("#43505a"));
    axisX->setLinePen(QPen(QColor("#7f909c")));
    chart->addAxis(axisX, Qt::AlignBottom);
    series->attachAxis(axisX);

    auto* axisY = new QValueAxis();
    axisY->setLabelFormat("%.0f");
    axisY->setRange(0, qMax(1, data.studentCount));
    axisY->setTickCount(qMin(qMax(3, data.studentCount + 1), 7));
    axisY->setLabelsFont(axisFont);
    axisY->setLabelsBrush(QBrush(QColor("#dbe8f1")));
    axisY->setLabelsColor(QColor("#dbe8f1"));
    axisY->setGridLineColor(QColor("#43505a"));
    axisY->setLinePen(QPen(QColor("#7f909c")));
    chart->addAxis(axisY, Qt::AlignLeft);
    series->attachAxis(axisY);
    this->ui->barChart->setChart(chart);
    this->ui->barChart->setRenderHint(QPainter::Antialiasing);
}

// AI辅助参考：Codex（基于 ChatGPT 5.4），2026-03
// 用途：Qt Charts 饼图/环形图生成（班级构成）
// 说明：图表类型选择与基础展示思路参考 AI 建议，后续已人工细化样式与统计内容
void MainWindow::updatePieChart(const CourseAnalysisData &data)
{
    const auto sortedCounts = this->sortedClassCounts(data.classCounts);
    auto* series = new QPieSeries();
    const QList<QColor> colors = {QColor("#0f766e"), QColor("#1d4ed8"), QColor("#9333ea"), QColor("#d97706"), QColor("#dc2626")};
    int colorIndex = 0;
    int otherCount = 0;
    for(int i = 0; i < sortedCounts.size(); ++i){
        if(i >= 8){
            otherCount += sortedCounts[i].second;
            continue;
        }
        auto* slice = series->append(sortedCounts[i].first, sortedCounts[i].second);
        slice->setColor(colors[colorIndex % colors.size()]);
        slice->setBorderColor(QColor("#d8e5ef"));
        slice->setBorderWidth(1.5);
        colorIndex++;
    }
    if(otherCount > 0){
        auto* slice = series->append("其他班级", otherCount);
        slice->setColor(QColor("#64748b"));
        slice->setBorderColor(QColor("#d8e5ef"));
        slice->setBorderWidth(1.5);
    }

    auto* chart = new QChart();
    chart->addSeries(series);
    chart->setBackgroundVisible(false);
    chart->legend()->setVisible(true);
    chart->legend()->setAlignment(Qt::AlignRight);
    chart->legend()->setLabelColor(QColor("#eef6fb"));
    chart->legend()->setFont(QFont("Microsoft YaHei UI", 9));
    chart->setMargins(QMargins(8, 8, 8, 8));
    series->setLabelsVisible(false);
    series->setPieSize(0.78);
    series->setHoleSize(0.42);
    this->ui->pieChart->setChart(chart);
    this->ui->pieChart->setRenderHint(QPainter::Antialiasing);
}

// AI辅助参考：Codex（基于 ChatGPT 5.4），2026-03
// 用途：Qt Charts 折线图生成（单元均分走势）
// 说明：图表类型选择与基础展示思路参考 AI 建议，后续已人工细化样式与统计内容
void MainWindow::updateLineChart(const CourseAnalysisData &data)
{
    auto* series = new QLineSeries();
    series->setName("单元均分");
    series->setColor(QColor("#38bdf8"));
    QPen linePen(QColor("#38bdf8"));
    linePen.setWidth(3);
    series->setPen(linePen);

    for(int i = 0; i < data.unitAverages.size(); i++){
        series->append(i, data.unitAverages[i]);
    }

    auto* chart = new QChart();
    chart->addSeries(series);
    chart->setTitle("单元均分走势");
    chart->setBackgroundVisible(false);
    chart->setPlotAreaBackgroundVisible(false);
    chart->setTitleBrush(QBrush(QColor("#eef6fb")));
    chart->legend()->hide();

    auto* axisX = new QCategoryAxis();
    for(int i = 0; i < data.unitNames.size(); i++){
        axisX->append(data.unitNames[i], i);
    }
    axisX->setRange(0, qMax(0, data.unitNames.size() - 1));
    axisX->setLabelsBrush(QBrush(QColor("#dbe8f1")));
    axisX->setLabelsColor(QColor("#dbe8f1"));
    axisX->setGridLineColor(QColor("#43505a"));
    axisX->setLinePen(QPen(QColor("#7f909c")));
    chart->addAxis(axisX, Qt::AlignBottom);
    series->attachAxis(axisX);

    auto* axisY = new QValueAxis();
    axisY->setRange(0, 100);
    axisY->setLabelFormat("%.0f");
    axisY->setTickCount(6);
    axisY->setLabelsBrush(QBrush(QColor("#dbe8f1")));
    axisY->setLabelsColor(QColor("#dbe8f1"));
    axisY->setGridLineColor(QColor("#43505a"));
    axisY->setLinePen(QPen(QColor("#7f909c")));
    chart->addAxis(axisY, Qt::AlignLeft);
    series->attachAxis(axisY);
    this->ui->lineChart->setChart(chart);
    this->ui->lineChart->setRenderHint(QPainter::Antialiasing);
}

int MainWindow::nextSubjectId() const
{
    if(!this->db.isValid() || !this->db.isOpen()){
        return 1001;
    }
    QSqlQuery query(this->db);
    if(!query.exec("SELECT MAX(course_id) FROM course")){
        spdlog::error("nextSubjectId query failed: {}", query.lastError().text().toStdString());
        return 1001;
    }
    if(!query.next() || query.value(0).isNull()){
        return 1001;
    }
    bool ok = false;
    const int maxId = query.value(0).toInt(&ok);
    if(!ok){
        return 1001;
    }
    return qMax(1001, maxId + 1);
}

QList<QPair<QString, int>> MainWindow::sortedClassCounts(const QMap<QString, int> &classCounts) const
{
    QList<QPair<QString, int>> items;
    for(auto it = classCounts.begin(); it != classCounts.end(); ++it){
        items.append(qMakePair(it.key(), it.value()));
    }
    std::sort(items.begin(), items.end(), [](const auto& left, const auto& right){
        if(left.second == right.second){
            return left.first < right.first;
        }
        return left.second > right.second;
    });
    return items;
}

QString MainWindow::formatClassCompositionSummary(const QMap<QString, int> &classCounts, int maxItems) const
{
    const auto sortedCounts = this->sortedClassCounts(classCounts);
    if(sortedCounts.isEmpty()){
        return "暂无班级数据";
    }

    QStringList parts;
    int otherCount = 0;
    for(int i = 0; i < sortedCounts.size(); ++i){
        if(i >= maxItems){
            otherCount += sortedCounts[i].second;
            continue;
        }
        parts << QString("%1 %2人").arg(sortedCounts[i].first).arg(sortedCounts[i].second);
    }
    if(otherCount > 0){
        parts << QString("其他班级 %1人").arg(otherCount);
    }
    return parts.join("；");
}

QString MainWindow::formatScoreBandSummary(const QMap<QString, int> &scoreBandCounts) const
{
    const QList<QPair<QString, QString>> labels = {
        {"90+", "90分及以上"},
        {"80-89", "80-89分"},
        {"70-79", "70-79分"},
        {"60-69", "60-69分"},
        {"<60", "60分以下"}
    };

    QStringList parts;
    for(const auto& item : labels){
        int count = scoreBandCounts.value(item.first, 0);
        if(count > 0){
            parts << QString("%1 %2人").arg(item.second).arg(count);
        }
    }
    return parts.isEmpty() ? "暂无有效成绩段数据" : parts.join("；");
}

void MainWindow::setSelectedSubjectCard(SubjectCard *card)
{
    for(int i = 0; i < this->subjectManageFlowLayout->count(); ++i){
        QLayoutItem* item = this->subjectManageFlowLayout->itemAt(i);
        if(!item || !item->widget()){
            continue;
        }
        auto* subjectCard = qobject_cast<SubjectCard*>(item->widget());
        if(subjectCard){
            subjectCard->setSelected(subjectCard == card);
        }
    }
    this->selectedSubjectCard_ = card;
}

QString MainWindow::buildSemesterReportContent(const CourseAnalysisData &data, const QString &analysis, const QString &prompt, bool usedRemote) const
{
    QStringList unitLines;
    for(int i = 0; i < data.unitNames.size(); ++i){
        unitLines << QString("- %1：均分 %2").arg(data.unitNames[i]).arg(QString::number(data.unitAverages[i], 'f', 1));
    }

    QList<StudentAnalysisInfo> rankedStudents;
    for(const auto& student : data.studentDetails){
        if(!std::isnan(student.totalScore)){
            rankedStudents.append(student);
        }
    }
    std::sort(rankedStudents.begin(), rankedStudents.end(), [](const StudentAnalysisInfo& left, const StudentAnalysisInfo& right){
        return left.totalScore > right.totalScore;
    });

    double totalScoreSum = 0.0;
    for(const auto& student : rankedStudents){
        totalScoreSum += student.totalScore;
    }
    const double averageTotalScore = rankedStudents.isEmpty() ? 0.0 : totalScoreSum / rankedStudents.size();

    QStringList topLines;
    for(int i = 0; i < rankedStudents.size() && i < 5; ++i){
        topLines << QString("- %1（%2）：%3")
                        .arg(rankedStudents[i].name)
                        .arg(rankedStudents[i].className)
                        .arg(QString::number(rankedStudents[i].totalScore, 'f', 1));
    }
    const QString totalScoreSection = rankedStudents.isEmpty()
        ? "## 总分概览\n- 暂无可计算的总分数据\n"
        : QString(
            "## 总分概览\n"
            "- 平均总分：%1\n"
            "- 最高总分：%2\n"
            "- 最低总分：%3\n\n"
            "## 总分前五\n"
            "%4\n"
        )
            .arg(QString::number(averageTotalScore, 'f', 1))
            .arg(QString::number(rankedStudents.first().totalScore, 'f', 1))
            .arg(QString::number(rankedStudents.last().totalScore, 'f', 1))
            .arg(topLines.join("\n"));

    return QString(
        "# %1 学期报告\n\n"
        "## 基本概览\n"
        "- 学生总数：%2\n"
        "- 整体均分：%3\n"
        "- 最高平均分：%4\n"
        "- 最低平均分：%5\n"
        "- 班级构成：%6\n"
        "- 成绩段分布：%7\n\n"
        "## 单元表现\n"
        "%8\n\n"
        "%9\n\n"
        "## 教学建议\n"
        "- 分析来源：%10\n\n"
        "%11\n\n"
        "## 提示词参考\n"
        "```text\n%12\n```"
    )
        .arg(data.courseName)
        .arg(data.studentCount)
        .arg(QString::number(data.overallAverage, 'f', 1))
        .arg(QString::number(data.maxAverage, 'f', 1))
        .arg(QString::number(data.minAverage, 'f', 1))
        .arg(this->formatClassCompositionSummary(data.classCounts))
        .arg(this->formatScoreBandSummary(data.scoreBandCounts))
        .arg(unitLines.join("\n"))
        .arg(totalScoreSection)
        .arg(usedRemote ? "DeepSeek" : "内置分析算法")
        .arg(analysis)
        .arg(prompt);
}

bool MainWindow::exportCurrentCourseScoresToXlsx(const QString &exportPath, QString *errorMessage)
{
    int courseId = this->ui->subjectComboBox->currentData().toInt();
    if(courseId <= 0){
        if(errorMessage){
            *errorMessage = "当前课程无效，无法导出成绩表。";
        }
        return false;
    }

    QString currentPathCsv = QDir::tempPath() + "/EduStatSemesterTemp.csv";
    QFile file(currentPathCsv);
    if(!file.open(QIODevice::WriteOnly | QIODevice::Text)){
        if(errorMessage){
            *errorMessage = "创建临时成绩文件失败。";
        }
        return false;
    }

    QTextStream out(&file);
    QStringList headers;
    headers << "学号" << "班级" << "姓名";

    QSqlQuery unitQuery(this->db);
    unitQuery.prepare(R"(
        SELECT name, weight, score
        FROM unit
        WHERE course_id = ?
        ORDER BY unit_order ASC
    )");
    unitQuery.addBindValue(courseId);
    if(!unitQuery.exec()){
        file.close();
        QFile::remove(currentPathCsv);
        if(errorMessage){
            *errorMessage = "读取课程单元失败。";
        }
        return false;
    }
    QStringList unitNames;
    QVector<double> unitWeights;
    QVector<int> unitFullScores;
    while(unitQuery.next()){
        const QString unitName = unitQuery.value(0).toString();
        unitNames << unitName;
        unitWeights << unitQuery.value(1).toDouble();
        unitFullScores << qMax(1, unitQuery.value(2).toInt());
        headers << unitName;
    }
    headers << "总分";

    out << headers.join(",") << '\n';

    QSqlQuery studentQuery(this->db);
    studentQuery.prepare(R"(
        SELECT DISTINCT s.student_id, s.class, s.name
        FROM score sc
        JOIN student s ON sc.student_id = s.student_id
        WHERE sc.course_id = ?
        ORDER BY s.student_id ASC
    )");
    studentQuery.addBindValue(courseId);
    if(!studentQuery.exec()){
        file.close();
        QFile::remove(currentPathCsv);
        if(errorMessage){
            *errorMessage = "读取学生信息失败。";
        }
        return false;
    }

    while(studentQuery.next()){
        QStringList row;
        const QString studentId = studentQuery.value(0).toString();
        row << studentId << studentQuery.value(1).toString() << studentQuery.value(2).toString();
        double weightedTotal = 0.0;
        double totalWeight = 0.0;
        for(double weight : unitWeights){
            if(weight > 0.0){
                totalWeight += weight;
            }
        }

        for(int i = 0; i < unitNames.size(); ++i){
            const QString& unitName = unitNames[i];
            QSqlQuery scoreQuery(this->db);
            scoreQuery.prepare(R"(
                SELECT score
                FROM score
                WHERE student_id = ? AND course_id = ? AND unit_name = ?
            )");
            scoreQuery.addBindValue(studentId);
            scoreQuery.addBindValue(courseId);
            scoreQuery.addBindValue(unitName);
            if(scoreQuery.exec() && scoreQuery.next() && !scoreQuery.value(0).isNull()){
                const double scoreValue = scoreQuery.value(0).toDouble();
                row << QString::number(scoreValue, 'f', 1);
                const double weight = i < unitWeights.size() ? unitWeights[i] : 0.0;
                const int fullScore = i < unitFullScores.size() ? qMax(1, unitFullScores[i]) : 100;
                if(weight > 0.0){
                    weightedTotal += (scoreValue / fullScore) * weight * 100.0;
                }
            }else{
                row << "";
            }
        }
        row << (totalWeight > 0.0 ? QString::number(weightedTotal / totalWeight, 'f', 1) : "");

        out << row.join(",") << '\n';
    }
    file.close();

    QProcess process;
    process.start("./dist/csvToXlsx/csvToXlsx.exe", QStringList() << currentPathCsv << exportPath);
    if(!process.waitForStarted() || !process.waitForFinished() ||
       process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0){
        QFile::remove(currentPathCsv);
        if(errorMessage){
            *errorMessage = "成绩 Excel 转换失败，请检查 csvToXlsx 模块。";
        }
        return false;
    }

    QFile::remove(currentPathCsv);
    return true;
}

QString MainWindow::buildLocalCourseAnalysis(const CourseAnalysisData &data) const
{
    int bestIndex = 0;
    int weakestIndex = 0;
    for(int i = 1; i < data.unitAverages.size(); i++){
        if(data.unitAverages[i] > data.unitAverages[bestIndex]){
            bestIndex = i;
        }
        if(data.unitAverages[i] < data.unitAverages[weakestIndex]){
            weakestIndex = i;
        }
    }

    return QString(
        "内置分析\n"
        "课程：%1\n"
        "学生总数：%2\n"
        "整体均分：%3\n"
        "最高平均分：%4\n"
        "最低平均分：%5\n"
        "表现最强单元：%6（均分 %7）\n"
        "最需要跟进单元：%8（均分 %9）\n"
        "班级构成：%10\n"
        "成绩段分布：%11\n"
        "\n建议：\n"
        "1. 对“%8”安排针对性复习或课堂追问。\n"
        "2. 对均分高于 90 的学生可增加拔高任务，对低于 70 的学生安排同伴互助。\n"
        "3. 合班授课时可优先观察不同班级在薄弱单元上的差异。"
    ).arg(data.courseName)
     .arg(data.studentCount)
     .arg(QString::number(data.overallAverage, 'f', 1))
     .arg(QString::number(data.maxAverage, 'f', 1))
     .arg(QString::number(data.minAverage, 'f', 1))
     .arg(data.unitNames.value(bestIndex))
     .arg(QString::number(data.unitAverages.value(bestIndex), 'f', 1))
     .arg(data.unitNames.value(weakestIndex))
     .arg(QString::number(data.unitAverages.value(weakestIndex), 'f', 1))
     .arg(this->formatClassCompositionSummary(data.classCounts))
     .arg(this->formatScoreBandSummary(data.scoreBandCounts));
}

// AI辅助参考：Codex（基于 ChatGPT 5.4），2026-03
// 用途：DeepSeek 教学分析提示词构建
// 说明：提示词基础结构与分析维度参考 AI 建议，后续已根据项目数据结构与教学场景人工调整
QString MainWindow::buildDeepSeekPrompt(const CourseAnalysisData &data) const
{
    QStringList unitLines;
    QStringList assessmentLines;
    for(int i = 0; i < data.unitNames.size(); i++){
        unitLines << QString("%1: %2").arg(data.unitNames[i]).arg(QString::number(data.unitAverages[i], 'f', 1));
        const double weight = i < data.unitWeights.size() ? data.unitWeights[i] : 0.0;
        const int fullScore = i < data.unitFullScores.size() ? qMax(1, data.unitFullScores[i]) : 100;
        assessmentLines << QString("%1（权重%2，满分%3）")
                               .arg(data.unitNames[i])
                               .arg(QString::number(weight * 100.0, 'f', weight == std::floor(weight) ? 0 : 1) + "%")
                               .arg(fullScore);
    }

    QList<StudentAnalysisInfo> rankedStudents = data.studentDetails;
    std::sort(rankedStudents.begin(), rankedStudents.end(), [](const StudentAnalysisInfo& left, const StudentAnalysisInfo& right){
        const bool leftMissing = std::isnan(left.totalScore);
        const bool rightMissing = std::isnan(right.totalScore);
        if(leftMissing != rightMissing){
            return !leftMissing;
        }
        return left.totalScore > right.totalScore;
    });

    QList<StudentAnalysisInfo> promptStudents;
    if(rankedStudents.size() <= 30){
        promptStudents = rankedStudents;
    }else{
        const int topCount = 6;
        const int bottomCount = 6;
        for(int i = 0; i < rankedStudents.size() && i < topCount; ++i){
            promptStudents.append(rankedStudents[i]);
        }
        for(int i = qMax(topCount, rankedStudents.size() - bottomCount); i < rankedStudents.size(); ++i){
            promptStudents.append(rankedStudents[i]);
        }
    }

    QStringList studentLines;
    for(const auto& student : promptStudents){
        QStringList scoreParts;
        QStringList lowScoreUnits;
        QStringList missingUnits;
        for(int i = 0; i < data.unitNames.size() && i < student.unitScores.size(); ++i){
            if(std::isnan(student.unitScores[i])){
                missingUnits << data.unitNames[i];
            }else{
                const double score = student.unitScores[i];
                if(score < 60.0){
                    lowScoreUnits << QString("%1:%2").arg(data.unitNames[i]).arg(QString::number(score, 'f', 0));
                }
                scoreParts << QString("%1:%2").arg(data.unitNames[i]).arg(QString::number(score, 'f', 0));
            }
        }

        QString summary = QString("总分:%1，均分:%2")
                              .arg(std::isnan(student.totalScore) ? "0.0" : QString::number(student.totalScore, 'f', 1))
                              .arg(QString::number(student.averageScore, 'f', 1));
        if(!lowScoreUnits.isEmpty()){
            summary += QString("，低分单元:%1").arg(lowScoreUnits.join("、"));
        }
        if(!missingUnits.isEmpty()){
            summary += QString("，未录入:%1").arg(missingUnits.join("、"));
        }
        if(lowScoreUnits.isEmpty() && missingUnits.isEmpty() && !scoreParts.isEmpty()){
            summary += QString("，单元:%1").arg(scoreParts.mid(0, 3).join("，"));
        }

        studentLines << QString("%1（%2） %3")
                            .arg(student.name)
                            .arg(student.className)
                            .arg(summary);
    }

    return QString(
        "你是教学数据分析助手。请基于以下课程统计、考评结构和学生明细，用中文输出一段面向任课教师的教学分析。"
        "分析要具体、克制、可执行，不要空话，不要只重复数据。"
        "若某学生存在未录入成绩，本次分析中这些未录入项按0分理解为未完成，不需要额外解释技术细节。"
        "请严格按下面结构输出，每个小标题都保留：\n"
        "总体判断：\n"
        "优秀学生：\n"
        "重点关注学生：\n"
        "偏科与风险：\n"
        "教学建议：\n"
        "下次课堂建议：\n"
        "要求：1. 优秀学生和重点关注学生各列2到4人，尽量点名并简述原因；"
        "2. 重点关注学生用中性表达，例如基础薄弱、完成度不足、波动较大，不要使用攻击性表述；"
        "3. 教学建议要能直接落地，尽量结合当前最弱单元和班级分层情况；"
        "4. 控制在280字以内，尽量简洁。\n\n"
        "课程：%1\n"
        "学生数：%2\n"
        "整体均分：%3\n"
        "最高均分：%4\n"
        "最低均分：%5\n"
        "考评结构：%6\n"
        "总分说明：按各单元权重折算为100分制总分，未录入按0分处理\n"
        "单元均分：%7\n"
        "班级构成：%8\n"
        "成绩段分布：%9\n"
        "学生样本说明：当前课程共%10人，本次提供%11人的重点样本用于分析；若人数较多，样本优先覆盖高分、低分和风险学生。\n"
        "学生明细：\n%12"
    ).arg(data.courseName)
     .arg(data.studentCount)
     .arg(QString::number(data.overallAverage, 'f', 1))
     .arg(QString::number(data.maxAverage, 'f', 1))
     .arg(QString::number(data.minAverage, 'f', 1))
     .arg(assessmentLines.join("；"))
     .arg(unitLines.join("；"))
     .arg(this->formatClassCompositionSummary(data.classCounts))
     .arg(this->formatScoreBandSummary(data.scoreBandCounts))
     .arg(data.studentDetails.size())
     .arg(promptStudents.size())
     .arg(studentLines.join("\n"));
}

// AI辅助参考：Codex（基于 ChatGPT 5.4），2026-03
// 用途：DeepSeek API Key 读取逻辑
// 说明：基础读取流程参考 AI 建议，后续已结合运行目录与配置方式人工调整
QString MainWindow::loadDeepSeekApiKey() const
{
    QStringList candidates;
    candidates << QDir(QCoreApplication::applicationDirPath()).filePath("init.json")
               << QDir::current().filePath("init.json");

    for(const QString& path : candidates){
        QFile file(path);
        if(!file.open(QIODevice::ReadOnly)){
            continue;
        }
        const auto doc = QJsonDocument::fromJson(file.readAll());
        if(!doc.isObject()){
            continue;
        }
        const QString apiKey = doc.object().value("deepseekApi").toString().trimmed();
        if(!apiKey.isEmpty()){
            return apiKey;
        }
    }
    return "";
}

// AI辅助参考：Codex（基于 ChatGPT 5.4），2026-03
// 用途：Qt Network 通过 HTTPS 调用 DeepSeek API
// 说明：接口调用、超时控制与错误处理基础方案参考 AI 建议，后续已按项目实际需求人工重构
QString MainWindow::requestDeepSeekAnalysis(const CourseAnalysisData &data, bool *usedRemote, QString *statusMessage)
{
    if(usedRemote){
        *usedRemote = false;
    }
    if(statusMessage){
        *statusMessage = "未发起 DeepSeek 请求";
    }
    const QString apiKey = this->loadDeepSeekApiKey();
    if(apiKey.isEmpty()){
        if(statusMessage){
            *statusMessage = "未读取到 DeepSeek API Key";
        }
        return "";
    }
    if(!QSslSocket::supportsSsl()){
        if(statusMessage){
            *statusMessage = "当前环境缺少 SSL 支持，无法访问 HTTPS 接口";
        }
        return "";
    }

    const QString prompt = this->buildDeepSeekPrompt(data);
    QNetworkAccessManager manager;
    QNetworkRequest request(QUrl("https://api.deepseek.com/chat/completions"));
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    request.setHeader(QNetworkRequest::UserAgentHeader, "EduStat/1.0");
    request.setRawHeader("Authorization", QString("Bearer %1").arg(apiKey).toUtf8());
    request.setTransferTimeout(45000);

    QJsonObject payload;
    payload["model"] = "deepseek-chat";
    QJsonArray messages;
    messages.append(QJsonObject{{"role", "system"}, {"content", "你是教学统计分析助手。"}});
    messages.append(QJsonObject{{"role", "user"}, {"content", prompt}});
    payload["messages"] = messages;
    payload["temperature"] = 0.3;
    payload["max_tokens"] = 420;

    QNetworkReply* reply = manager.post(request, QJsonDocument(payload).toJson(QJsonDocument::Compact));
    QEventLoop loop;
    QTimer timer;
    timer.setSingleShot(true);
    QObject::connect(&timer, &QTimer::timeout, &loop, &QEventLoop::quit);
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    // 可能会发送请求超时，在大数据下
    timer.start(45000);
    loop.exec();

    if(timer.isActive()){
        timer.stop();
    }else{
        reply->abort();
        if(statusMessage){
            *statusMessage = "请求超时";
        }
        reply->deleteLater();
        return "";
    }

    if(reply->error() != QNetworkReply::NoError){
        if(statusMessage){
            *statusMessage = QString("网络请求失败：%1").arg(reply->errorString());
        }
        reply->deleteLater();
        return "";
    }

    const int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QByteArray responseBytes = reply->readAll();
    if(httpStatus < 200 || httpStatus >= 300){
        QString detail = QString::fromUtf8(responseBytes).trimmed();
        if(detail.size() > 160){
            detail = detail.left(160) + "...";
        }
        if(statusMessage){
            *statusMessage = detail.isEmpty()
                ? QString("接口返回 HTTP %1").arg(httpStatus)
                : QString("接口返回 HTTP %1：%2").arg(httpStatus).arg(detail);
        }
        reply->deleteLater();
        return "";
    }

    const auto responseDoc = QJsonDocument::fromJson(responseBytes);
    reply->deleteLater();
    if(!responseDoc.isObject()){
        if(statusMessage){
            *statusMessage = "接口返回内容不是有效 JSON";
        }
        return "";
    }

    const auto choices = responseDoc.object().value("choices").toArray();
    if(choices.isEmpty()){
        if(statusMessage){
            *statusMessage = "接口返回内容中没有 choices 字段";
        }
        return "";
    }
    const QString content = choices.first().toObject().value("message").toObject().value("content").toString().trimmed();
    if(content.isEmpty()){
        if(statusMessage){
            *statusMessage = "接口返回成功，但内容为空";
        }
        return "";
    }
    if(usedRemote){
        *usedRemote = true;
    }
    if(statusMessage){
        *statusMessage = "已连接 DeepSeek 并成功返回结果";
    }
    return content;
}

void MainWindow::updateClassInformationPage()
{
    this->ui->classRefreshPushButton->setEnabled(false);
    this->ui->classRefreshPushButton->setText("分析中...");
    this->ui->analysisStatusValueLabel->setText("分析来源：正在整理当前课程数据");
    this->ui->networkStatusValueLabel->setText("网络状态：正在检测外部服务可用性");
    QApplication::processEvents();

    CourseAnalysisData data;
    if(!this->loadCourseAnalysisData(data)){
        this->ui->studentCountValueLabel->setText("--");
        this->ui->overallAverageValueLabel->setText("--");
        this->ui->bestUnitValueLabel->setText("--");
        this->ui->weakestUnitValueLabel->setText("--");
        this->ui->analysisStatusValueLabel->setText("分析来源：暂无可分析数据");
        this->ui->networkStatusValueLabel->setText("网络状态：未发起检测");
        this->ui->classAnalyzetextEdit->setPlainText("当前课程还没有足够的数据生成班级分析。");
        this->ui->promptPreviewTextEdit->clear();
        this->ui->classRefreshPushButton->setEnabled(true);
        this->ui->classRefreshPushButton->setText("刷新分析");
        return;
    }

    this->updateBarChart(data);
    this->updatePieChart(data);
    this->updateLineChart(data);

    int bestIndex = 0;
    int weakestIndex = 0;
    for(int i = 1; i < data.unitAverages.size(); i++){
        if(data.unitAverages[i] > data.unitAverages[bestIndex]){
            bestIndex = i;
        }
        if(data.unitAverages[i] < data.unitAverages[weakestIndex]){
            weakestIndex = i;
        }
    }

    this->ui->studentCountValueLabel->setText(QString::number(data.studentCount));
    this->ui->overallAverageValueLabel->setText(QString::number(data.overallAverage, 'f', 1));
    this->ui->bestUnitValueLabel->setText(
        QString("%1\n%2").arg(data.unitNames.value(bestIndex)).arg(QString::number(data.unitAverages.value(bestIndex), 'f', 1))
    );
    this->ui->weakestUnitValueLabel->setText(
        QString("%1\n%2").arg(data.unitNames.value(weakestIndex)).arg(QString::number(data.unitAverages.value(weakestIndex), 'f', 1))
    );

    bool usedRemote = false;
    const QString prompt = this->buildDeepSeekPrompt(data);
    QString remoteStatus;
    QString analysis = this->requestDeepSeekAnalysis(data, &usedRemote, &remoteStatus);
    if(analysis.isEmpty()){
        analysis = this->buildLocalCourseAnalysis(data);
    }

    QString finalText = usedRemote
        ? QString("AI分析（DeepSeek）\n%1").arg(analysis)
        : analysis;
    this->ui->analysisStatusValueLabel->setText(
        usedRemote ? "分析来源：DeepSeek 已返回结果" : "分析来源：内置分析算法（本次 DeepSeek 未成功返回）"
    );
    this->ui->networkStatusValueLabel->setText(
        usedRemote
            ? QString("网络状态：%1").arg(remoteStatus)
            : QString("网络状态：%1，已自动回退到本地分析").arg(remoteStatus)
    );
    this->ui->classAnalyzetextEdit->setPlainText(finalText);
    this->ui->promptPreviewTextEdit->setPlainText(prompt);
    this->ui->classRefreshPushButton->setEnabled(true);
    this->ui->classRefreshPushButton->setText("刷新分析");
}

void MainWindow::exportSemesterReport()
{
    CourseAnalysisData data;
    if(!this->loadCourseAnalysisData(data)){
        QMessageBox::information(this, "提示", "当前课程还没有足够的数据生成学期报告。", QMessageBox::Ok);
        return;
    }

    const QString defaultDir = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation).isEmpty()
        ? QDir::homePath()
        : QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    const QString defaultPath = QDir(defaultDir).filePath(QString("%1_学期报告.md").arg(data.courseName));

    QString reportPath = QFileDialog::getSaveFileName(
        this,
        "导出学期报告",
        defaultPath,
        "Markdown (*.md);;Text (*.txt)"
    );
    if(reportPath.isEmpty()){
        return;
    }
    if(QFileInfo(reportPath).suffix().isEmpty()){
        reportPath += ".md";
    }

    this->statusBar()->showMessage("正在生成学期报告...", 3000);
    QApplication::processEvents();

    bool usedRemote = false;
    const QString prompt = this->buildDeepSeekPrompt(data);
    QString remoteStatus;
    QString analysis = this->requestDeepSeekAnalysis(data, &usedRemote, &remoteStatus);
    if(analysis.isEmpty()){
        analysis = this->buildLocalCourseAnalysis(data);
    }

    QFile reportFile(reportPath);
    if(!reportFile.open(QIODevice::WriteOnly | QIODevice::Text)){
        QMessageBox::critical(this, "错误", "无法创建学期报告文件。", QMessageBox::Ok);
        return;
    }
    QTextStream reportOut(&reportFile);
    reportOut << this->buildSemesterReportContent(data, analysis, prompt, usedRemote);
    reportFile.close();

    QFileInfo reportInfo(reportPath);
    const QString xlsxPath = reportInfo.dir().filePath(reportInfo.completeBaseName() + "_成绩表.xlsx");
    QString exportError;
    const bool exportedXlsx = this->exportCurrentCourseScoresToXlsx(xlsxPath, &exportError);

    QString resultMessage = QString("学期报告已导出到：\n%1").arg(reportPath);
    if(exportedXlsx){
        resultMessage += QString("\n\n成绩表已导出到：\n%1").arg(xlsxPath);
    }else{
        resultMessage += QString("\n\n成绩表未导出成功：%1").arg(exportError);
    }
    resultMessage += usedRemote
        ? "\n\n本次报告使用了 DeepSeek 分析。"
        : "\n\n本次报告使用内置分析算法生成。";
    if(!remoteStatus.isEmpty()){
        resultMessage += QString("\nDeepSeek 状态：%1").arg(remoteStatus);
    }

    this->statusBar()->showMessage("学期报告导出完成", 4000);
    QMessageBox::information(this, "导出完成", resultMessage, QMessageBox::Ok);
}

void MainWindow::updateSubjectManagePage()
{
    this->selectedSubjectCard_ = nullptr;
    while(this->subjectManageFlowLayout->count() > 0){
        QLayoutItem* item = this->subjectManageFlowLayout->takeAt(0);
        if(!item){
            continue;
        }
        QWidget* widget = item->widget();
        if(widget){
            widget->deleteLater();
        }
        delete item;
    }

    QSqlQuery courseQuery(this->db);
    courseQuery.prepare(R"(
        SELECT course_id, name
        FROM course
        ORDER BY course_id ASC
    )");
    if(!courseQuery.exec()){
        spdlog::error("updateSubjectManagePage load course failed: {}", courseQuery.lastError().text().toStdString());
        return;
    }

    while(courseQuery.next()){
        const int courseId = courseQuery.value(0).toInt();
        const QString courseName = courseQuery.value(1).toString().trimmed();

        auto* card = new SubjectCard(courseId, QString("%1").arg(courseName), this->ui->subjectManageScrollAreaWidgetContents);

        QSqlQuery unitQuery(this->db);
        unitQuery.prepare(R"(
            SELECT name, weight
            FROM unit
            WHERE course_id = ?
            ORDER BY unit_order ASC
        )");
        unitQuery.addBindValue(courseId);
        if(!unitQuery.exec()){
            spdlog::error("updateSubjectManagePage load unit failed: {}", unitQuery.lastError().text().toStdString());
            card->deleteLater();
            continue;
        }

        bool hasUnit = false;
        while(unitQuery.next()){
            hasUnit = true;
            const QString unitName = unitQuery.value(0).toString();
            const int weightPercent = qRound(unitQuery.value(1).toDouble() * 100.0);
            card->addUnit(unitName, weightPercent);
        }
        if(!hasUnit){
            card->addUnit("暂未配置单元", 0);
            card->setStatsEnabled(false);
        }

        QObject::connect(card, &SubjectCard::deleteClicked, this, [this, card]{
            this->deleteSubjectCard(card);
        });
        QObject::connect(card, &SubjectCard::clicked, this, [this, card]{
            this->setSelectedSubjectCard(card);
        });
        this->subjectManageFlowLayout->addWidget(card);
    }

    if(this->subjectManageFlowLayout->count() == 0){
        auto* emptyLabel = new QLabel("当前还没有学科，点击“+新增学科”开始配置。", this->ui->subjectManageScrollAreaWidgetContents);
        emptyLabel->setStyleSheet("color:#9aa7b3; font-size:12px; padding:18px;");
        this->subjectManageFlowLayout->addWidget(emptyLabel);
    }

    this->ui->subjectManageScrollAreaWidgetContents->adjustSize();
}

void MainWindow::updateTeamSummaryText()
{
    if(this->currentTeams_.isEmpty()){
        this->ui->currentTeamSummaryLabel->setText("还没有生成组队");
        return;
    }

    int totalStudents = 0;
    for(const auto& team : this->currentTeams_){
        totalStudents += team.size();
    }

    QString mode = this->ui->teamModeComboBox->currentText();
    QString scoreRule = this->ui->useScoreCheckBox->isChecked() ? "参考成绩" : "不看成绩";
    this->ui->currentTeamSummaryLabel->setText(
        QString("%1 组，共 %2 人\n规则：%3 / %4 / 每组 %5 人")
            .arg(this->currentTeams_.size())
            .arg(totalStudents)
            .arg(mode)
            .arg(scoreRule)
            .arg(this->ui->teamSizeSpinBox->value())
    );
}

void MainWindow::renderTeams(const QList<QList<TeamStudentInfo> > &teams)
{
    while(this->teamUpFlowLayout->count() > 0){
        QLayoutItem* item = this->teamUpFlowLayout->takeAt(0);
        if(item){
            if(item->widget()){
                item->widget()->deleteLater();
            }
            delete item;
        }
    }

    for(int i = 0; i < teams.size(); i++){
        auto* card = new TeamCard(this->ui->teampUpScrollAreaWidgetContents);
        card->setTeamName(QString("第 %1 组").arg(i + 1));
        for(const auto& member : teams[i]){
            card->addMember(member.name);
        }
        this->teamUpFlowLayout->addWidget(card);
    }
}

void MainWindow::generateTeams()
{
    QList<TeamStudentInfo> students = this->loadStudentsForTeamUp();
    if(students.isEmpty()){
        QMessageBox::information(this,"提示","当前课程还没有可用于组队的成绩数据",QMessageBox::Ok);
        return;
    }

    int teamSize = this->ui->teamSizeSpinBox->value();
    if(teamSize <= 0){
        QMessageBox::warning(this,"提示","每组人数需要大于 0",QMessageBox::Ok);
        return;
    }

    if(this->ui->teamModeComboBox->currentText() == "强配弱平衡" && this->ui->useScoreCheckBox->isChecked()){
        std::sort(students.begin(), students.end(), [](const TeamStudentInfo& a, const TeamStudentInfo& b){
            return a.averageScore > b.averageScore;
        });
    }else{
        for(int i = students.size() - 1; i > 0; i--){
            int j = QRandomGenerator::global()->bounded(i + 1);
            students.swapItemsAt(i, j);
        }
    }

    int teamCount = (students.size() + teamSize - 1) / teamSize;
    QList<QList<TeamStudentInfo>> teams;
    teams.resize(teamCount);

    if(this->ui->teamModeComboBox->currentText() == "强配弱平衡" && this->ui->useScoreCheckBox->isChecked()){
        bool reverse = false;
        int teamIndex = 0;
        for(const auto& student : students){
            teams[teamIndex].append(student);
            if(!reverse){
                teamIndex++;
                if(teamIndex >= teamCount){
                    teamIndex = qMax(0, teamCount - 1);
                    reverse = true;
                }
            }else{
                teamIndex--;
                if(teamIndex < 0){
                    teamIndex = 0;
                    reverse = false;
                }
            }
        }
    }else{
        for(int i = 0; i < students.size(); i++){
            teams[i / teamSize].append(students[i]);
        }
    }

    this->currentTeams_ = teams;
    this->renderTeams(this->currentTeams_);
    this->updateTeamSummaryText();
    this->statusBar()->showMessage("已生成当前组队方案", 4000);
}

void MainWindow::saveCurrentTeamsToHistory()
{
    if(this->currentTeams_.isEmpty()){
        QMessageBox::information(this,"提示","请先生成当前组队",QMessageBox::Ok);
        return;
    }

    QString historyKey = QString("组队方案 %1").arg(this->teamHistoryIndex_++);
    this->teamHistory_[historyKey] = this->currentTeams_;
    QString itemText = QString("%1  |  %2").arg(historyKey, QDateTime::currentDateTime().toString("MM-dd HH:mm"));
    auto* item = new QListWidgetItem(itemText, this->ui->teamHistoryListWidget);
    item->setData(Qt::UserRole, historyKey);
    this->ui->teamHistoryListWidget->insertItem(0, item);
    this->statusBar()->showMessage("当前组队已保存到历史", 4000);
}

void MainWindow::restoreTeamHistory(QListWidgetItem *item)
{
    if(item == nullptr){
        return;
    }
    QString historyKey = item->data(Qt::UserRole).toString();
    if(!this->teamHistory_.contains(historyKey)){
        return;
    }

    this->currentTeams_ = this->teamHistory_[historyKey];
    this->renderTeams(this->currentTeams_);
    int totalStudents = 0;
    for(const auto& team : this->currentTeams_){
        totalStudents += team.size();
    }
    this->ui->currentTeamSummaryLabel->setText(
        QString("历史方案：%1\n共 %2 组，%3 人").arg(historyKey).arg(this->currentTeams_.size()).arg(totalStudents)
    );
    this->statusBar()->showMessage(QString("已载入 %1").arg(historyKey), 4000);
}

void MainWindow::startRollCall()
{
    QList<RollCallStudentInfo> students = this->loadStudentsForRollCall();
    if(students.isEmpty()){
        QMessageBox::information(this,"提示","当前课程还没有可用于点名的学生数据",QMessageBox::Ok);
        return;
    }

    QList<RollCallStudentInfo> candidates;
    QString mode = this->ui->rollCallModeComboBox->currentText();
    if(mode == "只抽未点到"){
        for(const auto& student : students){
            if(!this->rollCallHistoryIds_.contains(student.studentId)){
                candidates.append(student);
            }
        }
    }else if(mode == "尽量不重复"){
        QList<RollCallStudentInfo> freshStudents;
        QList<RollCallStudentInfo> usedStudents;
        for(const auto& student : students){
            if(this->rollCallHistoryIds_.contains(student.studentId)){
                usedStudents.append(student);
            }else{
                freshStudents.append(student);
            }
        }
        candidates = freshStudents;
        if(candidates.isEmpty()){
            candidates = usedStudents;
        }
    }else{
        candidates = students;
    }

    if(candidates.isEmpty()){
        QMessageBox::information(this,"提示","当前模式下没有可抽取的学生，请先重置记录",QMessageBox::Ok);
        return;
    }

    int count = qMin(this->ui->spinBox->value(), candidates.size());
    for(int i = candidates.size() - 1; i > 0; i--){
        int j = QRandomGenerator::global()->bounded(i + 1);
        candidates.swapItemsAt(i, j);
    }

    QStringList resultLines;
    for(int i = 0; i < count; i++){
        const auto& student = candidates[i];
        QString line = QString("%1  %2").arg(student.studentId, student.name);
        if(this->ui->rollCallShowClassCheckBox->isChecked()){
            line += QString("  [%1]").arg(student.className);
        }
        resultLines << line;
        this->rollCallHistoryIds_.append(student.studentId);

        auto* item = new QListWidgetItem(
            QString("%1  %2")
                .arg(QTime::currentTime().toString("HH:mm"))
                .arg(line),
            this->ui->rollCallHistoryListWidget
        );
        this->ui->rollCallHistoryListWidget->insertItem(0, item);

        if(i == 0){
            this->ui->rollCallHighlightNameLabel->setText(student.name);
            this->ui->rollCallHighlightMetaLabel->setText(
                this->ui->rollCallShowClassCheckBox->isChecked()
                    ? QString("%1  |  %2").arg(student.studentId, student.className)
                    : student.studentId
            );
        }
    }

    this->ui->plainTextEdit->setPlainText(resultLines.join("\n"));
    this->updateRollCallSummaryText(
        QString("本轮已抽取 %1 人，共有 %2 名学生可用于点名。")
            .arg(count)
            .arg(students.size())
    );
    this->animateRollCallHighlight();
    this->statusBar()->showMessage(QString("点名完成，本轮抽取 %1 人").arg(count), 4000);
}

void MainWindow::resetRollCallHistory()
{
    this->rollCallHistoryIds_.clear();
    this->ui->rollCallHistoryListWidget->clear();
    this->ui->plainTextEdit->clear();
    this->ui->rollCallHighlightNameLabel->setText("等待点名");
    this->ui->rollCallHighlightMetaLabel->setText("学号 / 班级 会显示在这里");
    this->updateRollCallSummaryText("点名记录已重置，可以重新开始抽取。");
    this->statusBar()->showMessage("点名历史已清空", 3000);
}

void MainWindow::updateStudentInformationTable()
{
    this->updatingStudentInformationTable_ = true;
    this->ui->studentInformationTableWidget->clear();
    this->ui->studentInformationTableWidget->setRowCount(0);
    this->ui->studentInformationTableWidget->setColumnCount(0);

    int courseId = this->ui->subjectComboBox->currentData().toInt();
    if(courseId <= 0){
        this->updatingStudentInformationTable_ = false;
        return;
    }

    // 1. 读取表头
    QStringList headers;
    headers << "学号" << "班级" << "姓名";

    QStringList unitNames;
    {
        QSqlQuery query(this->db);
        query.prepare(R"(
            SELECT name
            FROM unit
            WHERE course_id = ?
            ORDER BY unit_order ASC
        )");
        query.addBindValue(courseId);

        if(!query.exec()){
            spdlog::error("updateStudentInformationTable load headers error: {}", query.lastError().text().toStdString());
            QMessageBox::critical(this, "错误", "读取课程单元失败", QMessageBox::Ok);
            this->updatingStudentInformationTable_ = false;
            return;
        }

        while(query.next()){
            QString unitName = query.value(0).toString();
            unitNames << unitName;
            headers << unitName;
        }
    }

    this->ui->studentInformationTableWidget->setColumnCount(headers.size());
    this->ui->studentInformationTableWidget->setHorizontalHeaderLabels(headers);

    // 2. 读取当前课程下的学生列表
    QList<QString> studentIds;
    QMap<QString, QString> studentClassMap;
    QMap<QString, QString> studentNameMap;
    QString keyword = this->ui->searchLineEdit->text().trimmed();

    {
        QSqlQuery query(this->db);
        QString sql = R"(
            SELECT DISTINCT s.student_id, s.class, s.name
            FROM score sc
            JOIN student s ON sc.student_id = s.student_id
            WHERE sc.course_id = ?
        )";
        if(!keyword.isEmpty()){
            sql += R"(
                AND (
                    CAST(s.student_id AS TEXT) LIKE ?
                    OR s.name LIKE ?
                    OR s.class LIKE ?
                )
            )";
        }
        sql += " ORDER BY s.student_id ASC ";
        query.prepare(sql);
        query.addBindValue(courseId);
        if(!keyword.isEmpty()){
            QString likeKeyword = "%" + keyword + "%";
            query.addBindValue(likeKeyword);
            query.addBindValue(likeKeyword);
            query.addBindValue(likeKeyword);
        }

        if(!query.exec()){
            spdlog::error("updateStudentInformationTable load students error: {}", query.lastError().text().toStdString());
            QMessageBox::critical(this, "错误", "读取学生列表失败", QMessageBox::Ok);
            this->updatingStudentInformationTable_ = false;
            return;
        }

        while(query.next()){
            QString studentId = query.value(0).toString();
            QString className = query.value(1).toString();
            QString name = query.value(2).toString();

            studentIds.append(studentId);
            studentClassMap[studentId] = className;
            studentNameMap[studentId] = name;
        }
    }

    // 3. 读取当前课程下所有成绩
    // scoreMap[student_id][unit_name] = score
    QMap<QString, QMap<QString, QString>> scoreMap;

    {
        QSqlQuery query(this->db);
        query.prepare(R"(
            SELECT student_id, unit_name, score
            FROM score
            WHERE course_id = ?
        )");
        query.addBindValue(courseId);

        if(!query.exec()){
            spdlog::error("updateStudentInformationTable load scores error: {}", query.lastError().text().toStdString());
            QMessageBox::critical(this, "错误", "读取成绩失败", QMessageBox::Ok);
            this->updatingStudentInformationTable_ = false;
            return;
        }

        while(query.next()){
            QString studentId = query.value(0).toString();
            QString unitName = query.value(1).toString();
            QString score = query.value(2).toString();

            scoreMap[studentId][unitName] = score;
        }
    }

    // 4. 填充表格
    this->ui->studentInformationTableWidget->setRowCount(studentIds.size());

    for(int row = 0; row < studentIds.size(); row++){
        QString studentId = studentIds[row];

        auto* item0 = new QTableWidgetItem(studentId);
        auto* item1 = new QTableWidgetItem(studentClassMap[studentId]);
        auto* item2 = new QTableWidgetItem(studentNameMap[studentId]);

        item0->setFlags(item0->flags() & ~Qt::ItemIsEditable);
        item0->setData(Qt::UserRole, false);
        item1->setData(Qt::UserRole, false);
        item2->setData(Qt::UserRole, false);
        item0->setTextAlignment(Qt::AlignCenter);
        item1->setTextAlignment(Qt::AlignCenter);
        item2->setTextAlignment(Qt::AlignCenter);

        this->ui->studentInformationTableWidget->setItem(row, 0, item0);
        this->ui->studentInformationTableWidget->setItem(row, 1, item1);
        this->ui->studentInformationTableWidget->setItem(row, 2, item2);

        for(int i = 0; i < unitNames.size(); i++){
            QString unitName = unitNames[i];
            QString scoreText = scoreMap[studentId].value(unitName, "");

            auto* item = new QTableWidgetItem(scoreText);
            item->setData(Qt::UserRole, false);
            item->setTextAlignment(Qt::AlignCenter);
            this->ui->studentInformationTableWidget->setItem(row, i + 3, item);
        }
    }

    auto* headerView = this->ui->studentInformationTableWidget->horizontalHeader();
    headerView->setSectionResizeMode(QHeaderView::Fixed);
    this->ui->studentInformationTableWidget->setColumnWidth(0, 140);
    this->ui->studentInformationTableWidget->setColumnWidth(1, 120);
    this->ui->studentInformationTableWidget->setColumnWidth(2, 120);
    for(int i = 3; i < headers.size(); ++i){
        this->ui->studentInformationTableWidget->setColumnWidth(i, 110);
    }
    this->updatingStudentInformationTable_ = false;
}

void MainWindow::searchStudentInformation()
{
    this->updateStudentInformationTable();
    QString keyword = this->ui->searchLineEdit->text().trimmed();
    if(keyword.isEmpty()){
        this->statusBar()->showMessage("已显示当前课程的全部学生", 3000);
    }else{
        this->statusBar()->showMessage(QString("已按“%1”完成搜索").arg(keyword), 3000);
    }
}

void MainWindow::updateSubjectComboBox()
{
    QString previousSubjectName = this->ui->subjectComboBox->currentText().trimmed();
    this->ui->subjectComboBox->blockSignals(true);
    this->ui->subjectComboBox->clear();

    QSqlQuery query(this->db);
    query.prepare(R"(
        SELECT course_id, name
        FROM course
        ORDER BY course_id ASC
    )");
    if(!query.exec()){
        this->ui->subjectComboBox->blockSignals(false);
        spdlog::error("updateSubjectComboBox failed: {}", query.lastError().text().toStdString());
        return;
    }

    int previousIndex = -1;
    int currentIndex = 0;
    while(query.next()){
        int courseId = query.value(0).toInt();
        QString subjectName = query.value(1).toString();
        this->ui->subjectComboBox->addItem(subjectName, courseId);
        if(subjectName == previousSubjectName){
            previousIndex = currentIndex;
        }
        currentIndex++;
    }

    if(previousIndex >= 0){
        this->ui->subjectComboBox->setCurrentIndex(previousIndex);
    }
    this->ui->subjectComboBox->blockSignals(false);
}


void MainWindow::addStudentInformationTableRow(const QStringList &rowData)
{
    int curRow = this->ui->studentInformationTableWidget->rowCount();
    this->ui->studentInformationTableWidget->insertRow(curRow);
    for(size_t i = 0;i < rowData.size();i++){
        auto* item = new QTableWidgetItem(rowData[i]);
        if(i == 0){
            item->setFlags(item->flags() & ~Qt::ItemIsEditable);
        }
        item->setTextAlignment(Qt::AlignCenter);
        this->ui->studentInformationTableWidget->setItem(curRow,i,item);
    }
}

void MainWindow::addStudentInformation()
{
    int courseId = this->ui->subjectComboBox->currentData().toInt();
    int columnCount = this->ui->studentInformationTableWidget->columnCount();
    if(courseId <= 0 || columnCount < 3){
        QMessageBox::warning(this,"提示","请先选择课程并确保课程单元已配置",QMessageBox::Ok);
        return;
    }

    this->updatingStudentInformationTable_ = true;
    int curRow = this->ui->studentInformationTableWidget->rowCount();
    this->ui->studentInformationTableWidget->insertRow(curRow);
    for(int i = 0; i < columnCount; i++){
        QString initialText;
        auto* item = new QTableWidgetItem(initialText);
        item->setData(Qt::UserRole, true);
        item->setBackground(QBrush(QColor(245, 250, 228)));
        item->setForeground(QBrush(Qt::black));
        item->setTextAlignment(Qt::AlignCenter);
        this->ui->studentInformationTableWidget->setItem(curRow, i, item);
    }
    this->updatingStudentInformationTable_ = false;
    this->statusBar()->showMessage("已新增一行，请填写学号、班级、姓名；成绩可以先留空，点保存后再入库。", 6000);
    this->ui->studentInformationTableWidget->setCurrentCell(curRow, 0);
    this->ui->studentInformationTableWidget->editItem(this->ui->studentInformationTableWidget->item(curRow, 0));
}

void MainWindow::saveStudentInformation()
{
    this->updatingStudentInformationTable_ = true;
    if(QWidget* focusWidget = QApplication::focusWidget()){
        focusWidget->clearFocus();
    }
    this->updatingStudentInformationTable_ = false;

    int courseId = this->ui->subjectComboBox->currentData().toInt();
    if(courseId <= 0){
        QMessageBox::warning(this,"提示","请先选择课程",QMessageBox::Ok);
        return;
    }

    QList<int> pendingRows;
    for(int row = 0; row < this->ui->studentInformationTableWidget->rowCount(); row++){
        auto* studentIdItem = this->ui->studentInformationTableWidget->item(row, 0);
        if(studentIdItem && studentIdItem->data(Qt::UserRole).toBool()){
            pendingRows.append(row);
        }
    }

    if(pendingRows.isEmpty()){
        this->statusBar()->showMessage("没有待保存的新学生，现有修改会自动保存。", 4000);
        return;
    }

    if(!this->db.transaction()){
        QMessageBox::critical(this,"错误","数据库事物开启失败",QMessageBox::Ok);
        return;
    }

    for(int row : pendingRows){
        auto* studentIdItem = this->ui->studentInformationTableWidget->item(row,0);
        auto* classItem = this->ui->studentInformationTableWidget->item(row,1);
        auto* nameItem = this->ui->studentInformationTableWidget->item(row,2);
        if(!studentIdItem || !classItem || !nameItem){
            this->db.rollback();
            QMessageBox::warning(this,"提示",QString("第 %1 行数据不完整，请重新填写").arg(row + 1),QMessageBox::Ok);
            return;
        }

        QString studentId = studentIdItem->text().trimmed();
        QString className = classItem->text().trimmed();
        QString studentName = nameItem->text().trimmed();
        if(studentId.isEmpty() || className.isEmpty() || studentName.isEmpty()){
            this->db.rollback();
            QMessageBox::warning(this,"提示",QString("第 %1 行的学号、班级、姓名不能为空").arg(row + 1),QMessageBox::Ok);
            return;
        }

        bool idOk = false;
        studentId.toLongLong(&idOk);
        if(!idOk){
            this->db.rollback();
            QMessageBox::warning(this,"提示",QString("第 %1 行的学号必须是纯数字").arg(row + 1),QMessageBox::Ok);
            return;
        }

        QSqlQuery studentQuery(this->db);
        studentQuery.prepare(R"(
            INSERT INTO student(student_id,name,class)
            VALUES(?,?,?)
            ON CONFLICT(student_id) DO UPDATE SET
                name = excluded.name,
                class = excluded.class
        )");
        studentQuery.addBindValue(studentId);
        studentQuery.addBindValue(studentName);
        studentQuery.addBindValue(className);
        if(!studentQuery.exec()){
            this->db.rollback();
            QString errorText = studentQuery.lastError().text();
            spdlog::error("saveStudentInformation save student failed: {}", errorText.toStdString());
            QMessageBox::critical(this,"错误",QString("保存第 %1 行学生信息失败：%2").arg(row + 1).arg(errorText),QMessageBox::Ok);
            return;
        }
        studentQuery.finish();

        for(int currentColumn = 3; currentColumn < this->ui->studentInformationTableWidget->columnCount(); currentColumn++){
            auto* scoreItem = this->ui->studentInformationTableWidget->item(row, currentColumn);
            auto* headerItem = this->ui->studentInformationTableWidget->horizontalHeaderItem(currentColumn);
            if(!headerItem){
                this->db.rollback();
                QMessageBox::critical(this,"错误","读取成绩表头失败",QMessageBox::Ok);
                return;
            }

            QString scoreText = scoreItem ? scoreItem->text().trimmed() : "";
            QVariant scoreValue;
            if(scoreText.isEmpty()){
                scoreValue = QVariant();
            }else{
                bool scoreOk = false;
                double numericScore = scoreText.toDouble(&scoreOk);
                if(!scoreOk){
                    this->db.rollback();
                    QMessageBox::warning(this,"提示",QString("第 %1 行的“%2”成绩必须是数字").arg(row + 1).arg(headerItem->text()),QMessageBox::Ok);
                    return;
                }
                scoreValue = numericScore;
            }

            QSqlQuery scoreQuery(this->db);
            scoreQuery.prepare(R"(
                INSERT INTO score(student_id,course_id,unit_name,score)
                VALUES(?,?,?,?)
                ON CONFLICT(student_id,course_id,unit_name) DO UPDATE SET
                    score = excluded.score
            )");
            scoreQuery.addBindValue(studentId);
            scoreQuery.addBindValue(courseId);
            scoreQuery.addBindValue(headerItem->text());
            scoreQuery.addBindValue(scoreValue);
            if(!scoreQuery.exec()){
                this->db.rollback();
                QString errorText = scoreQuery.lastError().text();
                spdlog::error("saveStudentInformation save score failed: {}", errorText.toStdString());
                QMessageBox::critical(this,"错误",QString("保存第 %1 行的成绩失败：%2").arg(row + 1).arg(errorText),QMessageBox::Ok);
                return;
            }
            scoreQuery.finish();
        }
    }

    if(!this->db.commit()){
        this->db.rollback();
        QString errorText = this->db.lastError().text();
        spdlog::error("saveStudentInformation commit failed: {}", errorText.toStdString());
        QMessageBox::critical(this,"错误",QString("保存学生信息失败：%1").arg(errorText),QMessageBox::Ok);
        return;
    }

    this->statusBar()->showMessage(QString("已保存 %1 条新学生记录").arg(pendingRows.size()), 5000);
    updateStudentInformationTable();
}

void MainWindow::loadStudentInformation()
{
    if(this->ui->subjectComboBox->count() <= 0){
        QMessageBox::information(this,"提示","请先添加学科之后导入",QMessageBox::Ok);
        return;
    }
    QString loadFilePath = QFileDialog::getOpenFileName(this,"选择Execl","","Excel (*.xlsx *.xls *.csv)");
    if(loadFilePath.isEmpty()) return;
    // 先excel转csv,再次读csv
    // 先判断是否是csv
    QFileInfo info(loadFilePath);
    QString suffix = info.suffix().toLower();
    QString csvPath = loadFilePath;
    if(suffix == "xlsx" || suffix == "xls"){
        csvPath = QDir::tempPath() + "/EduStat_load.csv";
        QString program = "./dist/xlsxToCsv/xlsxToCsv.exe";
        QStringList args;
        args << loadFilePath << csvPath;
        if(not QFile::exists(program)){
            spdlog::error("找不到xlsx to csv的转换程序");
            QMessageBox::critical(this,"错误","系统文件残缺，请检查转换模块",QMessageBox::Ok);
            return;
        }
        {
            QProcess process;
            process.start(program,args);
            if(!process.waitForStarted()){
                spdlog::error("loadStudentInformation error : {} ",process.errorString().toStdString());
                QMessageBox::critical(this, "错误", "转换程序启动失败", QMessageBox::Ok);
                return;
            }

            if(!process.waitForFinished()){
                spdlog::error("loadStudentInformation error : {} ",process.errorString().toStdString());
                QMessageBox::critical(this, "错误", "转换程序执行失败", QMessageBox::Ok);
                return;
            }

            if(process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0){
                spdlog::error("loadStudentInformation error : {} ",process.errorString().toStdString());
                QMessageBox::critical(this, "错误", "Excel 转 CSV 失败", QMessageBox::Ok);
                return;
            }
        }
    }
    QFile file(csvPath);
    if(not file.open(QIODevice::ReadOnly | QIODevice::Text)){
        spdlog::error("csv load error : {} ",file.errorString().toStdString());
        QMessageBox::critical(this,"错误","系统缓存csv load 错误",QMessageBox::Ok);
        return;
    }
    QTextStream in(&file);
    int courseId = this->ui->subjectComboBox->currentData().toInt();
    if(courseId <= 0){
        file.close();
        QMessageBox::warning(this,"提示","当前学科编号无效，请重新选择学科",QMessageBox::Ok);
        return;
    }

    QStringList unitNames;
    {
        QSqlQuery unitQuery(this->db);
        unitQuery.prepare(R"(
            SELECT name
            FROM unit
            WHERE course_id = ?
            ORDER BY unit_order ASC
        )");
        unitQuery.addBindValue(courseId);
        if(!unitQuery.exec()){
            file.close();
            spdlog::error("loadStudentInformation load unit failed: {}", unitQuery.lastError().text().toStdString());
            QMessageBox::critical(this,"错误","读取课程单元失败",QMessageBox::Ok);
            return;
        }
        while(unitQuery.next()){
            unitNames << normalizeImportText(unitQuery.value(0).toString());
        }
    }
    if(unitNames.isEmpty()){
        file.close();
        QMessageBox::warning(this,"提示","当前学科还没有配置单元，无法导入成绩",QMessageBox::Ok);
        return;
    }

    if(not this->db.transaction()){
        file.close();
        spdlog::error("loadStudentInformation 事物开启失败");
        QMessageBox::critical(this,"错误","数据库事物开启失败",QMessageBox::Ok);
        return;
    }

    QString headerLine;
    while(!in.atEnd() && headerLine.trimmed().isEmpty()){
        headerLine = in.readLine();
    }
    if(headerLine.isEmpty()){
        this->db.rollback();
        file.close();
        QMessageBox::warning(this,"提示","导入文件为空",QMessageBox::Ok);
        return;
    }

    QStringList headers = headerLine.split(',', Qt::KeepEmptyParts);
    for(int i = 0; i < headers.size(); i++){
        headers[i] = normalizeImportText(headers[i]);
    }
    if(headers.size() < 3){
        this->db.rollback();
        file.close();
        QMessageBox::warning(this,"提示","表头格式不正确，至少需要学号、班级、姓名三列",QMessageBox::Ok);
        return;
    }
    if(headers[0] != "学号" || headers[1] != "班级" || headers[2] != "姓名"){
        this->db.rollback();
        file.close();
        QMessageBox::warning(this,"提示","表头必须以“学号,班级,姓名”开头",QMessageBox::Ok);
        return;
    }

    QStringList expectedHeaders;
    expectedHeaders << "学号" << "班级" << "姓名";
    expectedHeaders << unitNames;
    if(headers != expectedHeaders){
        this->db.rollback();
        file.close();
        QString expectedText = expectedHeaders.join(",");
        QString currentText = headers.join(",");
        QMessageBox::warning(
            this,
            "提示",
            QString("导入表头和当前课程安排不一致。\n当前课程应为：%1\n导入文件实际为：%2")
                .arg(expectedText, currentText),
            QMessageBox::Ok
        );
        return;
    }

    QSqlQuery studentQuery(this->db);
    studentQuery.prepare(R"(
        INSERT INTO student(student_id,name,class)
        VALUES(?,?,?)
        ON CONFLICT(student_id) DO UPDATE SET
            name = excluded.name,
            class = excluded.class
    )");

    QSqlQuery scoreQuery(this->db);
    scoreQuery.prepare(R"(
        INSERT INTO score(student_id,course_id,unit_name,score)
        VALUES(?,?,?,?)
        ON CONFLICT(student_id,course_id,unit_name) DO UPDATE SET
            score = excluded.score
    )");

    int importCount = 0;
    int lineNumber = 1;
    while(not in.atEnd()){
        QString line = in.readLine();
        lineNumber++;
        if(line.trimmed().isEmpty()){
            continue;
        }

        QStringList parts = line.split(',', Qt::KeepEmptyParts);
        if(parts.size() < headers.size()){
            parts.resize(headers.size());
        }

        QString studentId = parts[0].trimmed();
        QString className = parts[1].trimmed();
        QString studentName = parts[2].trimmed();

        if(studentId.isEmpty() || className.isEmpty() || studentName.isEmpty()){
            this->db.rollback();
            file.close();
            QMessageBox::warning(this,"提示",QString("第 %1 行的学号、班级或姓名为空").arg(lineNumber),QMessageBox::Ok);
            return;
        }

        bool idOk = false;
        studentId.toLongLong(&idOk);
        if(!idOk){
            this->db.rollback();
            file.close();
            QMessageBox::warning(this,"提示",QString("第 %1 行的学号不是纯数字").arg(lineNumber),QMessageBox::Ok);
            return;
        }

        studentQuery.bindValue(0, studentId);
        studentQuery.bindValue(1, studentName);
        studentQuery.bindValue(2, className);
        if(!studentQuery.exec()){
            this->db.rollback();
            file.close();
            spdlog::error("loadStudentInformation upsert student failed: {}", studentQuery.lastError().text().toStdString());
            QMessageBox::critical(this,"错误",QString("写入学生信息失败，第 %1 行").arg(lineNumber),QMessageBox::Ok);
            return;
        }

        for(const auto& unitName : unitNames){
            int columnIndex = unitNames.indexOf(unitName) + 3;
            QString scoreText = columnIndex < parts.size() ? parts[columnIndex].trimmed() : "";

            scoreQuery.bindValue(0, studentId);
            scoreQuery.bindValue(1, courseId);
            scoreQuery.bindValue(2, unitName);
            if(scoreText.isEmpty()){
                scoreQuery.bindValue(3, QVariant());
            }else{
                bool scoreOk = false;
                double scoreValue = scoreText.toDouble(&scoreOk);
                if(!scoreOk){
                    this->db.rollback();
                    file.close();
                    QMessageBox::warning(this,"提示",QString("第 %1 行的单元“%2”成绩不是数字").arg(lineNumber).arg(unitName),QMessageBox::Ok);
                    return;
                }
                scoreQuery.bindValue(3, scoreValue);
            }
            if(!scoreQuery.exec()){
                this->db.rollback();
                file.close();
                spdlog::error("loadStudentInformation upsert score failed: {}", scoreQuery.lastError().text().toStdString());
                QMessageBox::critical(this,"错误",QString("写入成绩失败，第 %1 行，单元：%2").arg(lineNumber).arg(unitName),QMessageBox::Ok);
                return;
            }
        }
        importCount++;
    }

    if(importCount <= 0){
        this->db.rollback();
        file.close();
        QMessageBox::warning(this,"提示","没有读取到可导入的数据行",QMessageBox::Ok);
        return;
    }

    if(not this->db.commit()){
        file.close();
        spdlog::error("loadStudentInformation 事物提交失败");
        QMessageBox::critical(this,"错误","数据库事物提失败",QMessageBox::Ok);
        return;
    }
    file.close();

    // 更新学生TableWidget
    updateStudentInformationTable();
    QMessageBox::information(this,"成功",QString("成功导入 %1 条学生成绩").arg(importCount),QMessageBox::Ok);
}

void MainWindow::studentDeleteSelected()
{
    int courseId = this->ui->subjectComboBox->currentData().toInt();
    if(courseId <= 0){
        QMessageBox::warning(this,"提示","请先选择课程",QMessageBox::Ok);
        return;
    }

    QSet<int> set;
    for(const auto& item : this->ui->studentInformationTableWidget->selectedItems())
        set.insert(item->row());
    if(set.isEmpty()){
        QMessageBox::warning(this,"提示","请选中需要删除的行",QMessageBox::Ok);
        return;
    }
    QList<int> list = set.values();
    if(QMessageBox::question(this,"确认",QString("确定删除%1行?").arg(list.size()),QMessageBox::Ok | QMessageBox::No) == QMessageBox::No) return;
    std::sort(std::begin(list),std::end(list),std::greater<int>());

    if(!this->db.transaction()){
        QMessageBox::critical(this,"错误","数据库事物开启失败",QMessageBox::Ok);
        return;
    }

    for(const auto row : list){
        auto* studentIdItem = this->ui->studentInformationTableWidget->item(row,0);
        if(!studentIdItem || studentIdItem->text().trimmed().isEmpty()){
            this->db.rollback();
            QMessageBox::critical(this,"错误","选中行缺少学号，无法删除",QMessageBox::Ok);
            return;
        }
        QString studentId = studentIdItem->text().trimmed();

        QSqlQuery deleteScoreQuery(this->db);
        deleteScoreQuery.prepare(R"(
            DELETE FROM score
            WHERE student_id = ? AND course_id = ?
        )");
        deleteScoreQuery.addBindValue(studentId);
        deleteScoreQuery.addBindValue(courseId);
        if(!deleteScoreQuery.exec()){
            this->db.rollback();
            spdlog::error("studentDeleteSelected delete score failed: {}", deleteScoreQuery.lastError().text().toStdString());
            QMessageBox::critical(this,"错误",QString("删除学生 %1 的课程成绩失败").arg(studentId),QMessageBox::Ok);
            return;
        }

        QSqlQuery countQuery(this->db);
        countQuery.prepare(R"(
            SELECT COUNT(*)
            FROM score
            WHERE student_id = ?
        )");
        countQuery.addBindValue(studentId);
        if(!countQuery.exec() || !countQuery.next()){
            this->db.rollback();
            spdlog::error("studentDeleteSelected count score failed: {}", countQuery.lastError().text().toStdString());
            QMessageBox::critical(this,"错误",QString("检查学生 %1 的剩余成绩失败").arg(studentId),QMessageBox::Ok);
            return;
        }

        if(countQuery.value(0).toInt() == 0){
            QSqlQuery deleteStudentQuery(this->db);
            deleteStudentQuery.prepare(R"(
                DELETE FROM student
                WHERE student_id = ?
            )");
            deleteStudentQuery.addBindValue(studentId);
            if(!deleteStudentQuery.exec()){
                this->db.rollback();
                spdlog::error("studentDeleteSelected delete student failed: {}", deleteStudentQuery.lastError().text().toStdString());
                QMessageBox::critical(this,"错误",QString("删除学生 %1 失败").arg(studentId),QMessageBox::Ok);
                return;
            }
        }
    }

    if(!this->db.commit()){
        this->db.rollback();
        QMessageBox::critical(this,"错误","删除学生后提交失败",QMessageBox::Ok);
        return;
    }

    updateStudentInformationTable();
}

void MainWindow::studentInformationItemChanged(QTableWidgetItem *item)
{
    if(this->updatingStudentInformationTable_ || item == nullptr){
        return;
    }

    int row = item->row();
    int courseId = this->ui->subjectComboBox->currentData().toInt();
    if(courseId <= 0){
        return;
    }

    auto* studentIdItem = this->ui->studentInformationTableWidget->item(row,0);
    auto* classItem = this->ui->studentInformationTableWidget->item(row,1);
    auto* nameItem = this->ui->studentInformationTableWidget->item(row,2);
    if(!studentIdItem || !classItem || !nameItem){
        return;
    }

    QString studentId = studentIdItem->text().trimmed();
    QString className = classItem->text().trimmed();
    QString studentName = nameItem->text().trimmed();
    bool isNewRow = studentIdItem->data(Qt::UserRole).toBool();

    if(isNewRow){
        this->statusBar()->showMessage("新学生行已修改，点击“保存”后写入数据库。", 3000);
        return;
    }

    if(studentId.isEmpty() || className.isEmpty() || studentName.isEmpty()){
        QMessageBox::warning(this,"提示","学号、班级、姓名不能为空",QMessageBox::Ok);
        updateStudentInformationTable();
        return;
    }

    bool idOk = false;
    studentId.toLongLong(&idOk);
    if(!idOk){
        QMessageBox::warning(this,"提示","学号必须是纯数字",QMessageBox::Ok);
        updateStudentInformationTable();
        return;
    }

    QList<double> scoreValues;
    for(int currentColumn = 3; currentColumn < this->ui->studentInformationTableWidget->columnCount(); currentColumn++){
        auto* scoreItem = this->ui->studentInformationTableWidget->item(row, currentColumn);
        QString scoreText = scoreItem ? scoreItem->text().trimmed() : "";
        if(scoreText.isEmpty()){
            scoreValues.append(std::numeric_limits<double>::quiet_NaN());
            continue;
        }

        bool scoreOk = false;
        double scoreValue = scoreText.toDouble(&scoreOk);
        if(!scoreOk){
            QMessageBox::warning(this,"提示","成绩必须是数字",QMessageBox::Ok);
            updateStudentInformationTable();
            return;
        }
        scoreValues.append(scoreValue);
    }

    if(!this->db.transaction()){
        QMessageBox::critical(this,"错误","数据库事物开启失败",QMessageBox::Ok);
        updateStudentInformationTable();
        return;
    }

    QSqlQuery studentQuery(this->db);
    studentQuery.prepare(R"(
        INSERT INTO student(student_id,name,class)
        VALUES(?,?,?)
        ON CONFLICT(student_id) DO UPDATE SET
            name = excluded.name,
            class = excluded.class
    )");
    studentQuery.addBindValue(studentId);
    studentQuery.addBindValue(studentName);
    studentQuery.addBindValue(className);
    if(!studentQuery.exec()){
        this->db.rollback();
        spdlog::error("studentInformationItemChanged update student failed: {}", studentQuery.lastError().text().toStdString());
        QMessageBox::critical(this,"错误",isNewRow ? "新增学生失败" : "更新学生信息失败",QMessageBox::Ok);
        updateStudentInformationTable();
        return;
    }

    for(int currentColumn = 3; currentColumn < this->ui->studentInformationTableWidget->columnCount(); currentColumn++){
        auto* headerItem = this->ui->studentInformationTableWidget->horizontalHeaderItem(currentColumn);
        if(!headerItem){
            this->db.rollback();
            updateStudentInformationTable();
            return;
        }

        QSqlQuery scoreQuery(this->db);
        scoreQuery.prepare(R"(
            INSERT INTO score(student_id,course_id,unit_name,score)
            VALUES(?,?,?,?)
            ON CONFLICT(student_id,course_id,unit_name) DO UPDATE SET
                score = excluded.score
        )");
        scoreQuery.addBindValue(studentId);
        scoreQuery.addBindValue(courseId);
        scoreQuery.addBindValue(headerItem->text());
        if(std::isnan(scoreValues[currentColumn - 3])){
            scoreQuery.addBindValue(QVariant());
        }else{
            scoreQuery.addBindValue(scoreValues[currentColumn - 3]);
        }
        if(!scoreQuery.exec()){
            this->db.rollback();
            spdlog::error("studentInformationItemChanged update score failed: {}", scoreQuery.lastError().text().toStdString());
            QMessageBox::critical(this,"错误","更新成绩失败",QMessageBox::Ok);
            updateStudentInformationTable();
            return;
        }
    }

    if(!this->db.commit()){
        this->db.rollback();
        QMessageBox::critical(this,"错误",isNewRow ? "新增学生失败" : "保存学生信息失败",QMessageBox::Ok);
        updateStudentInformationTable();
        return;
    }

    this->statusBar()->showMessage(QString("已保存学生 %1 的修改").arg(studentId), 3000);
}

void MainWindow::exportStudentInformation()
{
    QString exportPath = QFileDialog::getSaveFileName(this,"导出 Excel","","设置导出Excel路径 (*.xlsx)");
    if(exportPath.isEmpty()) return;
    if(not exportPath.endsWith(".xlsx",Qt::CaseInsensitive)){
        exportPath += ".xlsx";
    }
    QString currentPathCsv = QDir::tempPath() + "/EduStatTemp.csv";
    QFile file(currentPathCsv);
    if(not file.open(QIODevice::WriteOnly | QIODevice::Text)){
        spdlog::error("exportStudentInformation file opened error : {}",file.errorString().toStdString());
        QMessageBox::critical(this,"错误","创建xlsx失败",QMessageBox::Ok);
        return;
    }
    QTextStream out(&file);
    int row = this->ui->studentInformationTableWidget->rowCount();
    int col = this->ui->studentInformationTableWidget->columnCount();
    int courseId = this->ui->subjectComboBox->currentData().toInt();
    QVector<double> unitWeights;
    QVector<int> unitFullScores;
    if(courseId > 0){
        QSqlQuery unitQuery(this->db);
        unitQuery.prepare(R"(
            SELECT weight, score
            FROM unit
            WHERE course_id = ?
            ORDER BY unit_order ASC
        )");
        unitQuery.addBindValue(courseId);
        if(unitQuery.exec()){
            while(unitQuery.next()){
                unitWeights << unitQuery.value(0).toDouble();
                unitFullScores << qMax(1, unitQuery.value(1).toInt());
            }
        }
    }
    qDebug() << "开始表头";
    for(int i = 0; i < col;i++){
        if(i) out << ',';
        auto* header = this->ui->studentInformationTableWidget->horizontalHeaderItem(i);
        out << header->text();
    }
    out << ",总分";
    qDebug() << "完成表头" ;
    out << '\n';
    for(int i = 0;i < row;i++){
        double weightedTotal = 0.0;
        double totalWeight = 0.0;
        for(double weight : unitWeights){
            if(weight > 0.0){
                totalWeight += weight;
            }
        }
        for(int j = 0;j < col;j++){
            if(j) out << ',';
            auto* item = this->ui->studentInformationTableWidget->item(i,j);
            out << (item ? item->text() : "");
            if(j >= 3 && (j - 3) < unitWeights.size()){
                auto* scoreItem = this->ui->studentInformationTableWidget->item(i,j);
                if(scoreItem && !scoreItem->text().trimmed().isEmpty()){
                    bool ok = false;
                    const double scoreValue = scoreItem->text().trimmed().toDouble(&ok);
                    if(ok){
                        const double weight = unitWeights[j - 3];
                        const int fullScore = (j - 3) < unitFullScores.size() ? qMax(1, unitFullScores[j - 3]) : 100;
                        if(weight > 0.0){
                            weightedTotal += (scoreValue / fullScore) * weight * 100.0;
                        }
                    }
                }
            }
        }
        out << ',' << (totalWeight > 0.0 ? QString::number(weightedTotal / totalWeight, 'f', 1) : "");
        out << '\n';
    }
    qDebug() << "完成表单";
    file.close();
    {
        QStringList para;
        para << currentPathCsv << exportPath;
        QProcess process;
        process.start("./dist/csvToXlsx/csvToXlsx.exe",para);
        if(not process.waitForStarted()){
            QFile::remove(currentPathCsv);
            spdlog::error("csv to xlsx started error : {} ",process.errorString().toStdString());
            return;
        }
        if(not process.waitForFinished()){
            QFile::remove(currentPathCsv);
            spdlog::error("csv to xlsx not fished : {}",process.errorString().toStdString());
            return;
        }
        if(process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0){
            QFile::remove(currentPathCsv);
            spdlog::error("csv to xlsx errro : {} ",process.errorString().toStdString());
            QMessageBox::critical(this,"错误","导出excel失败",QMessageBox::Ok);
            return;
        }
    }
    QFile::remove(currentPathCsv);
    spdlog::info("csv to xlsx successful !");
    QMessageBox::information(this,"成功",QString("成功导出 %1").arg(exportPath),QMessageBox::Ok);
}

// AI辅助参考：Codex（基于 ChatGPT 5.4），2026-03
// 用途：SQLite 数据库表结构初始化
// 说明：基础表结构设计参考 AI 建议，后续已按实际业务需求进行轻量化调整
void MainWindow::initSQLite()
{
    this->db = QSqlDatabase::addDatabase("QSQLITE");
    this->db.setDatabaseName("EduStatSystem.db");
    if(not this->db.open()){
        spdlog::error("SQLite Open Error");
        return;
    }
    spdlog::info("SQLite opened Successfully!");
    QSqlQuery query(this->db);
    // SQLite配置
    query.exec("PRAGMA foreign_keys = ON");
    // student表
    query.exec(R"(
        CREATE TABLE IF NOT EXISTS student(
        student_id INTEGER PRIMARY KEY,
        name TEXT,
        class TEXT
        )
    )");
    // course表
    query.exec(R"(
        CREATE TABLE IF NOT EXISTS course(
        course_id INTEGER PRIMARY KEY,
        name TEXT
        )
    )");

    // unit表
    query.exec(R"(
        CREATE TABLE IF NOT EXISTS unit(
            course_id INTEGER,
            name TEXT,
            weight REAL,
            score INTEGER,
            unit_order INTEGER,
            PRIMARY KEY(course_id,name)
        )
    )");
    // score表
    query.exec(R"(
        CREATE TABLE IF NOT EXISTS score(
        student_id INTEGER,
        course_id INTEGER,
        unit_name TEXT,
        score REAL,
        PRIMARY KEY(student_id,course_id,unit_name)
    )
    )");

}


void MainWindow::deleteSubjectCard(SubjectCard *card)
{
    if(!card){
        return;
    }

    const int courseId = card->getCourseId();
    const QString courseName = card->getSubjectName();
    if(QMessageBox::question(
           this,
           "确认删除",
           QString("确认删除学科“%1”吗？这会同时删除该学科的单元配置和相关成绩。").arg(courseName),
           QMessageBox::Yes | QMessageBox::No
       ) != QMessageBox::Yes){
        return;
    }

    if(!this->db.transaction()){
        QMessageBox::critical(this, "错误", "开启删除事务失败", QMessageBox::Ok);
        return;
    }

    QSqlQuery deleteScoreQuery(this->db);
    deleteScoreQuery.prepare(R"(
        DELETE FROM score
        WHERE course_id = ?
    )");
    deleteScoreQuery.addBindValue(courseId);
    if(!deleteScoreQuery.exec()){
        this->db.rollback();
        spdlog::error("deleteSubjectCard delete score failed: {}", deleteScoreQuery.lastError().text().toStdString());
        QMessageBox::critical(this, "错误", "删除学科成绩失败", QMessageBox::Ok);
        return;
    }

    QSqlQuery deleteUnitQuery(this->db);
    deleteUnitQuery.prepare(R"(
        DELETE FROM unit
        WHERE course_id = ?
    )");
    deleteUnitQuery.addBindValue(courseId);
    if(!deleteUnitQuery.exec()){
        this->db.rollback();
        spdlog::error("deleteSubjectCard delete unit failed: {}", deleteUnitQuery.lastError().text().toStdString());
        QMessageBox::critical(this, "错误", "删除学科单元失败", QMessageBox::Ok);
        return;
    }

    QSqlQuery deleteCourseQuery(this->db);
    deleteCourseQuery.prepare(R"(
        DELETE FROM course
        WHERE course_id = ?
    )");
    deleteCourseQuery.addBindValue(courseId);
    if(!deleteCourseQuery.exec()){
        this->db.rollback();
        spdlog::error("deleteSubjectCard delete course failed: {}", deleteCourseQuery.lastError().text().toStdString());
        QMessageBox::critical(this, "错误", "删除学科失败", QMessageBox::Ok);
        return;
    }

    if(!this->db.commit()){
        this->db.rollback();
        QMessageBox::critical(this, "错误", "提交删除学科失败", QMessageBox::Ok);
        return;
    }

    this->selectedSubjectCard_ = nullptr;
    this->updateSubjectComboBox();
    this->updateStudentInformationTable();
    this->updateClassInformationPage();
    this->updateSubjectManagePage();
    this->statusBar()->showMessage(QString("已删除学科：%1").arg(courseName), 3000);
}

void MainWindow::addSubjectDeleteTableWidgetLine()
{
    QSet<int> selectRows;
    for(const auto& x : this->ui->addSubjectTableWidget->selectedItems()) selectRows.insert(x->row());
    if(selectRows.isEmpty()){
        QMessageBox::warning(this,"提示","请选择要删除的行");
        return;
    }
    if(QMessageBox::question(this,"确认删除",QString("确认删除 %1 行吗?").arg(selectRows.size()),QMessageBox::Yes | QMessageBox::No) == QMessageBox::No) return;
    QList<int> rows = selectRows.values();
    std::sort(std::begin(rows),std::end(rows),std::greater<int>());
    for(int row : rows)
        this->ui->addSubjectTableWidget->removeRow(row);
}

void MainWindow::addSubjectAddUnitLine()
{
    int row = ui->addSubjectTableWidget->rowCount();
    this->ui->addSubjectTableWidget->insertRow(row);
    for(int col = 0;col < ui->addSubjectTableWidget->columnCount() ;col++){
        auto* item = new QTableWidgetItem("");
        item->setTextAlignment(Qt::AlignCenter);
        this->ui->addSubjectTableWidget->setItem(row,col,item);
    }
    if(auto* scoreItem = this->ui->addSubjectTableWidget->item(row,2)){
        scoreItem->setText("100");
    }
}

void MainWindow::addSubjectAdjustedWeight()
{
    int row = this->ui->addSubjectTableWidget->rowCount();
    if(row <= 0){
        this->ui->addSubjectWeightLineEdit->setText("0");
        return;
    }
    double sum = 0;
    QList<double> weight(row,0);
    for(int i = 0;i < row;i++){
        auto item = this->ui->addSubjectTableWidget->item(i,1);
        if(not item) continue;
        double x = item->text().toDouble();
        sum += x;
        weight[i] = x;
    }
    if(::fabs(sum) < 1e-6){
        double averge = 1.0 / row;
        for(int i = 0;i < row;i++)
            this->ui->addSubjectTableWidget->item(i,1)->setText(QString("%1").arg(averge,0,'f',2));
    }else{
        for(int i = 0;i < row;i++){
            double x = weight[i] / sum;
            this->ui->addSubjectTableWidget->item(i,1)->setText(QString("%1").arg(x,0,'f',2));
        }
    }
    this->ui->addSubjectWeightLineEdit->setText("1");
}

void MainWindow::addSubjectCompletedAndExit()
{
    // 先调整权重
    this->addSubjectAdjustedWeight();

    const QString subjectIdText = this->ui->addSubjectIdLineEdit->text().trimmed();
    const QString subjectNameText = normalizeSingleLineText(this->ui->addSubjectNameLineEdit->text());

    this->ui->addSubjectIdLineEdit->setText(subjectIdText);
    this->ui->addSubjectNameLineEdit->setText(subjectNameText);

    if(subjectIdText.isEmpty()){
        QMessageBox::warning(this,"提示","请输入学科编号",QMessageBox::Ok);
        return;
    }
    bool flag = false;
    auto id = subjectIdText.toInt(&flag);
    if(not flag){
        QMessageBox::warning(this,"提示","学科编号请使用纯数字",QMessageBox::Ok);
        return;
    }
    Q_UNUSED(id);
    if(subjectNameText.isEmpty()){
        QMessageBox::warning(this,"提示","请输入学科名称",QMessageBox::Ok);
        return;
    }
    if(this->ui->addSubjectWeightLineEdit->text().isEmpty()){
        QMessageBox::warning(this,"提示","权重和不能为空，请检查权重比例",QMessageBox::Ok);
        return;
    }
    if(this->ui->addSubjectTableWidget->rowCount() <= 0){
        QMessageBox::warning(this,"提示","请输入课程的单元设置",QMessageBox::Ok);
        return;
    }


    QSqlQuery query(this->db);
    if(not this->db.transaction()){
        spdlog::error("addSubecjtCompleteAndExit transaction opened error.");
        return;
    }
    QString course_create_sql = QString(R"(
        INSERT INTO course(course_id,name)
        VALUES(?,?)
    )");
    query.prepare(course_create_sql);
    query.addBindValue(subjectIdText);
    query.addBindValue(subjectNameText);
    flag = query.exec();
    if(not flag){
        QMessageBox::warning(this,"提示","学科编号需要唯一",QMessageBox::Ok);
        this->db.rollback();
        return;
    }
    for(int i = 0;i < static_cast<int>(this->ui->addSubjectTableWidget->rowCount());i++){
        QSqlQuery unitQuery(this->db);
        auto item01 = this->ui->addSubjectTableWidget->item(i,0);
        if(item01){
            item01->setText(normalizeSingleLineText(item01->text()));
        }
        if(not item01 || item01->text().isEmpty()){
            QMessageBox::warning(this,"提示","请确保单元格不要为空",QMessageBox::Ok);
            this->db.rollback();
            return;
        }
        auto item02 = this->ui->addSubjectTableWidget->item(i,1);
        if(not item02 || item02->text().isEmpty()){
            QMessageBox::warning(this,"提示","请确保单元格不要为空",QMessageBox::Ok);
            this->db.rollback();
            return;
        }
        auto item03 = this->ui->addSubjectTableWidget->item(i,2);
        if(not item03 || item03->text().isEmpty()){
            QMessageBox::warning(this,"提示","请确保单元格不要为空",QMessageBox::Ok);
            this->db.rollback();
            return;
        }
        QString unit_name_sql = item01->text();
        QString unit_weight_sql = item02->text();
        QString unit_score_sql = item03->text();
        QString unit_create_sql = QString("INSERT INTO unit(course_id,name,weight,score,unit_order) VALUES(?,?,?,?,?)");

        unitQuery.prepare(unit_create_sql);
        unitQuery.addBindValue(subjectIdText); // 1
        unitQuery.addBindValue(item01->text()); // 2
        unitQuery.addBindValue(item02->text()); // 3
        unitQuery.addBindValue(item03->text()); // 4
        unitQuery.addBindValue(i); // 5
        // qDebug()<< unit_create_sql<< ' ' << this->ui->addSubjectIdLineEdit->text() << ' ' << item01->text() << ' ' << item02->text() << ' '<< item03->text() << i << '\n';
        flag = unitQuery.exec();
        if(not flag){
            QMessageBox::warning(this,"错误","SQLite load unit error ",QMessageBox::Ok);
            spdlog::error("SQLite load unit error from addSubjectCompletedAndExit : {}", unitQuery.lastError().text().toStdString());
            this->db.rollback();
            return;
        }
    }
    this->db.commit();
    this->updateSubjectComboBox();
    this->updateStudentInformationTable();
    this->updateSubjectManagePage();
    this->ui->addSubjectIdLineEdit->setText(QString::number(this->nextSubjectId()));
    this->ui->addSubjectNameLineEdit->clear();
    this->ui->addSubjectWeightLineEdit->setText("0");
    this->ui->addSubjectTableWidget->setRowCount(0);
    QMessageBox::information(this,"成功","添加科目完成",QMessageBox::Ok);
    this->ui->stackedWidget->setCurrentWidget(this->ui->subjectManagePage);
}
