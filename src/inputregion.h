#pragma once

#include <QObject>
#include <QRect>

class QWindow;

/**
 * Restricts input on the transparent full-screen layer surface to the visible
 * bar / popup / panel. Without this, the transparent area would swallow clicks
 * and the collapsed bar could not be genuinely small.
 */
class InputRegion : public QObject
{
    Q_OBJECT

public:
    explicit InputRegion(QObject *parent = nullptr);

    void setWindow(QWindow *window);

    Q_INVOKABLE void apply(const QRect &barRect, const QRect &popupRect, bool fullScreen, const QRect &fullRect = QRect());

private:
    void update();

    QWindow *m_window = nullptr;
    QRect m_barRect;
    QRect m_popupRect;
    QRect m_fullRect;
    bool m_fullScreen = false;
};
