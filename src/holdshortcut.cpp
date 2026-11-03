#include "holdshortcut.h"

#include <KGlobalAccel>

#include <QAction>
#include <QDebug>
#include <QKeySequence>

namespace
{
// Long enough that a deliberate hold is never cut short, short enough that a
// lost release (for example when kglobalacceld restarts mid-hold) cannot leave
// the HUD invisible forever.
constexpr int releaseWatchdogMs = 30000;
}

HoldShortcut::HoldShortcut(QObject *parent)
    : QObject(parent)
{
    m_action = new QAction(this);
    m_action->setObjectName(QStringLiteral("hold-to-hide"));
    m_action->setText(tr("按住隐藏 HUD"));
    m_action->setProperty("componentName", QStringLiteral("endfield-tray"));
    m_action->setProperty("componentDisplayName", QStringLiteral("Endfield Tray"));

    const QKeySequence defaultShortcut(Qt::META | Qt::Key_H);
    KGlobalAccel::self()->setDefaultShortcut(m_action, {defaultShortcut});
    KGlobalAccel::self()->setShortcut(m_action, {defaultShortcut});

    connect(KGlobalAccel::self(), &KGlobalAccel::globalShortcutActiveChanged, this, [this](QAction *action, bool active) {
        if (action == m_action) {
            setHeld(active);
        }
    });

    // Fallback for setups that only deliver the activation itself: start
    // hiding on the trigger, and let the watchdog bring the HUD back if the
    // release never arrives.
    connect(m_action, &QAction::triggered, this, [this] {
        setHeld(true);
    });

    m_watchdog.setSingleShot(true);
    m_watchdog.setInterval(releaseWatchdogMs);
    connect(&m_watchdog, &QTimer::timeout, this, [this] {
        if (m_held) {
            qWarning("endfield-tray: hold shortcut release was not received, restoring the HUD.");
            setHeld(false);
        }
    });
}

bool HoldShortcut::held() const
{
    return m_held;
}

void HoldShortcut::setHeld(bool held)
{
    if (m_held == held) {
        return;
    }

    m_held = held;
    if (m_held) {
        m_watchdog.start();
    } else {
        m_watchdog.stop();
    }
    Q_EMIT heldChanged();
}
