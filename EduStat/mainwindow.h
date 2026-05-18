#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QMainWindow>
#include <QtCharts/QtCharts>
#include <QtCharts/QChartView>
#include <QtCharts/QLineSeries>
#include <QtCharts/QBarSeries>
#include <QtCharts/QPieSeries>
#include <QList>
#include <QString>
#include <QScrollArea>
#include <QMap>
#include <QVector>
#include <QListWidgetItem>
#include <QStringList>
#include <QPropertyAnimation>
#include <QGraphicsOpacityEffect>
#include <limits>
#include "flowlayout.h"
#include "subjectcard.h"
#include <QtSql/QSqlDatabase>
#include "ui_mainwindow.h"
QT_BEGIN_NAMESPACE
namespace Ui {
class MainWindow;
}
QT_END_NAMESPACE

class MainWindow : public QMainWindow
{
    Q_OBJECT

public:
    MainWindow(QWidget *parent = nullptr);
    ~MainWindow();
signals:

public slots:

    void updateSubjectComboBox();
    void generateTeams();
    void saveCurrentTeamsToHistory();
    void restoreTeamHistory(QListWidgetItem* item);
    void startRollCall();
    void resetRollCallHistory();
    void updateClassInformationPage();
    void updateSubjectManagePage();
    void exportSemesterReport();

    void deleteSubjectCard(SubjectCard* card); // 删除学科管理里面的学科卡片

    // 增加学科
    // 增加单元
    void addSubjectDeleteTableWidgetLine(); // 删除增加学科中的选中行
    void addSubjectAddUnitLine(); // 增加学科单元
    void addSubjectAdjustedWeight(); // 自动调整单元的权重，依据比例 0为1
    void addSubjectCompletedAndExit(); // 检测 完成 数据库 添加 学科

    // 学生信息
    void addStudentInformationTableRow(const QStringList& rowData);
    void addStudentInformation();
    // 导入学生信息
    void loadStudentInformation();
    void saveStudentInformation();
    // 选中删除的学生信信息 记得跟新数据库
    void studentDeleteSelected();
    // 导出学生信息为xlsx  具体就是先导出为csv 之后csv转换为xlsx
    void exportStudentInformation();
    // 刷新学生也的信息
    void updateStudentInformationTable();
    void searchStudentInformation();
    void studentInformationItemChanged(QTableWidgetItem* item);
private:
    struct TeamStudentInfo{
        QString studentId;
        QString name;
        QString className;
        double averageScore = 0.0;
    };
    struct RollCallStudentInfo{
        QString studentId;
        QString name;
        QString className;
    };
    struct StudentAnalysisInfo{
        QString studentId;
        QString name;
        QString className;
        QVector<double> unitScores;
        double averageScore = 0.0;
        double totalScore = std::numeric_limits<double>::quiet_NaN();
    };
    struct CourseAnalysisData{
        QString courseName;
        QStringList unitNames;
        QVector<double> unitWeights;
        QVector<int> unitFullScores;
        QVector<double> unitAverages;
        QMap<QString, int> classCounts;
        QMap<QString, int> scoreBandCounts;
        QList<double> studentAverages;
        QList<StudentAnalysisInfo> studentDetails;
        int studentCount = 0;
        double overallAverage = 0.0;
        double maxAverage = 0.0;
        double minAverage = 0.0;
    };

    void updateTeamSummaryText();
    void renderTeams(const QList<QList<TeamStudentInfo>>& teams);
    QList<TeamStudentInfo> loadStudentsForTeamUp();
    QList<RollCallStudentInfo> loadStudentsForRollCall();
    void updateRollCallSummaryText(const QString& text);
    void animateRollCallHighlight();
    bool loadCourseAnalysisData(CourseAnalysisData& data);


    // chart ai generator by gpt5.4 + codex
    void updateBarChart(const CourseAnalysisData& data);
    void updatePieChart(const CourseAnalysisData& data);
    void updateLineChart(const CourseAnalysisData& data);



    int nextSubjectId() const;
    QList<QPair<QString, int>> sortedClassCounts(const QMap<QString, int>& classCounts) const;
    QString formatClassCompositionSummary(const QMap<QString, int>& classCounts, int maxItems = 6) const;
    QString formatScoreBandSummary(const QMap<QString, int>& scoreBandCounts) const;
    void setSelectedSubjectCard(SubjectCard* card);
    QString buildSemesterReportContent(const CourseAnalysisData& data, const QString& analysis, const QString& prompt, bool usedRemote) const;
    bool exportCurrentCourseScoresToXlsx(const QString& exportPath, QString* errorMessage);
    QString buildLocalCourseAnalysis(const CourseAnalysisData& data) const;


    // deepseek api generator by gpt5.4 + codex
    QString buildDeepSeekPrompt(const CourseAnalysisData& data) const;
    QString requestDeepSeekAnalysis(const CourseAnalysisData& data, bool* usedRemote, QString* statusMessage = nullptr);
    QString loadDeepSeekApiKey() const;

    void initSQLite(); // 初始化数据库
    Ui::MainWindow *ui;
    FlowLayout* teamUpFlowLayout;
    FlowLayout* subjectManageFlowLayout;
    // 数据库
    QSqlDatabase db;
    bool updatingStudentInformationTable_ = false;
    QList<QList<TeamStudentInfo>> currentTeams_;
    QMap<QString, QList<QList<TeamStudentInfo>>> teamHistory_;
    int teamHistoryIndex_ = 1;
    QList<QString> rollCallHistoryIds_;
    QGraphicsOpacityEffect* rollCallHighlightEffect_ = nullptr;
    QPropertyAnimation* rollCallHighlightAnimation_ = nullptr;
    SubjectCard* selectedSubjectCard_ = nullptr;

};

#endif // MAINWINDOW_H




