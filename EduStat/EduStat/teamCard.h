#ifndef TEAMCARD_H
#define TEAMCARD_H

#include <QWidget>
#include <QString>
#include <QLabel>
#include <QVBoxLayout>
#include <QList>
#include <QScrollArea>
#include <QFrame>
class TeamCard : public QWidget
{
    Q_OBJECT
public:
    explicit TeamCard(QWidget *parent = nullptr);
    void setTeamName(const QString& name);
    void addMember(const QString& name);

public slots:

protected:
signals:
private:
    QString teamName;
    QList<QString> members;
    QLabel* teamLabel;
    QLabel* memberCountLabel;
    QLabel* summaryLabel;
    QWidget* membersWidget;
    QScrollArea* scrollArea;
    QVBoxLayout* mainLayout; // 主布局
    QVBoxLayout* membersLayout; // 成员布局
    enum{
        FixdHeight = 248
    };
};

#endif // TEAMCARD_H
