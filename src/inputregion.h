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

    Q_INVOKABLE void apply(const QRect &barRect, const QRect &popupRect, const QRect &panelRect, bool fullScreen = false);

private:
    void update();

    QWindow *m_window = nullptr;
    QRect m_barRect;
    QRect m_popupRect;
    QRect m_panelRect;
    bool m_fullScreen = false;
};
