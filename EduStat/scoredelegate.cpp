#include "scoredelegate.h"


QWidget *WeightDelegate::createEditor(QWidget *parent, const QStyleOptionViewItem &, const QModelIndex &) const
{

     QLineEdit *editor = new QLineEdit(parent);

     // 限制输入 0~1000 的数字
     QDoubleValidator *validator = new QDoubleValidator(0,1000,2,editor);
     validator->setNotation(QDoubleValidator::StandardNotation);

     editor->setValidator(validator);

     return editor;

}
