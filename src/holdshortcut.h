#pragma once

#include <QObject>
#include <QTimer>

class QAction;

/**
 * Registers a global "hold to hide" shortcut (Meta+H by default) through
 * KGlobalAccel.
 *
 * While the shortcut is held, held() stays true so the HUD can step out of the
 * way (for example while moving windows around). KGlobalAccel reports the press
 * and the release separately, which is why a real key combination is used
 * instead of a bare modifier: Wayland does not expose the global modifier
 * state to clients, and modifier-only shortcuts only fire once on release.
 */
class HoldShortcut : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool held READ held NOTIFY heldChanged)

public:
    explicit HoldShortcut(QObject *parent = nullptr);

    bool held() const;

Q_SIGNALS:
    void heldChanged();

private:
    void setHeld(bool held);

    QAction *m_action = nullptr;
    QTimer m_watchdog;
    bool m_held = false;
};
