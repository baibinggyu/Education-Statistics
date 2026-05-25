#pragma once

#include <QObject>

struct VideoPlayerProxy : QObject {
    Q_OBJECT
public:
    using QObject::QObject;
    Q_INVOKABLE void open(const QString& path);
};
