#pragma once
#include <QStyledItemDelegate>
#include <QLineEdit>
#include <QDoubleValidator>

class WeightDelegate : public QStyledItemDelegate
{
public:
    explicit WeightDelegate(QObject *parent = nullptr)
        : QStyledItemDelegate(parent) {}

    QWidget *createEditor(QWidget *parent,
                          const QStyleOptionViewItem &,
                          const QModelIndex &) const override;
};
