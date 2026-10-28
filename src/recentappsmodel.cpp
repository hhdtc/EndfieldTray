#include "recentappsmodel.h"
#include "windowmodel.h"

#include <QTimer>
#include <QVariantMap>

#include <algorithm>

RecentAppsModel::RecentAppsModel(WindowModel *windows, QObject *parent)
    : QAbstractListModel(parent)
    , m_windows(windows)
{
    m_rebuildTimer.setSingleShot(true);
    m_rebuildTimer.setInterval(0);
    connect(&m_rebuildTimer, &QTimer::timeout, this, &RecentAppsModel::rebuild);

    connect(m_windows, &QAbstractItemModel::rowsInserted, this, &RecentAppsModel::scheduleRebuild);
    connect(m_windows, &QAbstractItemModel::rowsRemoved, this, &RecentAppsModel::scheduleRebuild);
    connect(m_windows, &QAbstractItemModel::modelReset, this, &RecentAppsModel::scheduleRebuild);
    connect(m_windows, &QAbstractItemModel::layoutChanged, this, &RecentAppsModel::scheduleRebuild);
    connect(m_windows, &QAbstractItemModel::dataChanged, this, &RecentAppsModel::scheduleRebuild);
    rebuild();
}

int RecentAppsModel::count() const
{
    return m_groups.size();
}

int RecentAppsModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_groups.size();
}

QVariant RecentAppsModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_groups.size()) {
        return {};
    }
    const Group &group = m_groups.at(index.row());
    switch (role) {
    case AppNameRole:
        return group.appName;
    case AppIdRole:
        return group.appId;
    case IconRole:
        return group.icon;
    case CountRole:
        return group.windows.size();
    case ActiveRole:
        return group.active;
    case RecencyRole:
        return group.recency;
    case WindowsRole: {
        QVariantList windows;
        for (int i = 0; i < group.windows.size(); ++i) {
            const WindowRef &window = group.windows.at(i);
            QVariantMap entry;
            entry.insert(QStringLiteral("title"), window.title);
            entry.insert(QStringLiteral("active"), window.active);
            entry.insert(QStringLiteral("minimized"), window.minimized);
            entry.insert(QStringLiteral("index"), i);
            windows.append(entry);
        }
        return windows;
    }
    default:
        return {};
    }
}

QHash<int, QByteArray> RecentAppsModel::roleNames() const
{
    return {
        {AppNameRole, "appName"},
        {AppIdRole, "appId"},
        {IconRole, "icon"},
        {CountRole, "windowCount"},
        {ActiveRole, "active"},
        {WindowsRole, "windows"},
        {RecencyRole, "recency"},
    };
}

void RecentAppsModel::scheduleRebuild()
{
    if (!m_active) {
        return;
    }
    if (!m_rebuildTimer.isActive()) {
        m_rebuildTimer.start();
    }
}

void RecentAppsModel::setActive(bool active)
{
    if (m_active == active) {
        return;
    }
    m_active = active;
    if (active) {
        rebuild();
    } else {
        m_rebuildTimer.stop();
    }
}

void RecentAppsModel::rebuild()
{
    QHash<QString, Group> groups;
    for (int row = 0; row < m_windows->rowCount(); ++row) {
        const QModelIndex index = m_windows->index(row, 0);
        const QString appName = index.data(WindowModel::AppNameRole).toString();
        QString appId = index.data(WindowModel::AppIdRole).toString();
        if (appId.isEmpty()) {
            appId = appName;
        }
        if (appId.isEmpty()) {
            continue;
        }
        auto it = groups.find(appId);
        if (it == groups.end()) {
            Group group;
            group.appId = appId;
            QString displayName = appName.isEmpty() ? appId : appName;
            if (displayName.startsWith(QLatin1String("Google ")))
                displayName = displayName.mid(7);
            else if (displayName.startsWith(QLatin1String("Mozilla ")))
                displayName = displayName.mid(8);
            else if (displayName.startsWith(QLatin1String("Microsoft ")))
                displayName = displayName.mid(10);

            // KDE often returns names like "Dolphin 文件管理器"; for the narrow
            // chip, keep the latin product name only.
            const int space = displayName.indexOf(QLatin1Char(' '));
            if (space > 0) {
                const QString tail = displayName.mid(space + 1);
                for (const QChar ch : tail) {
                    if (ch.unicode() >= 0x2e80) {
                        displayName.truncate(space);
                        break;
                    }
                }
            }
            group.appName = displayName;
            group.icon = qvariant_cast<QIcon>(index.data(WindowModel::IconRole));
            groups.insert(appId, group);
            it = groups.find(appId);
        }
        WindowRef ref;
        ref.row = row;
        ref.title = index.data(WindowModel::TitleRole).toString();
        ref.active = index.data(WindowModel::ActiveRole).toBool();
        ref.minimized = index.data(WindowModel::MinimizedRole).toBool();
        ref.lastActivated = index.data(WindowModel::LastActivatedRole).toLongLong();
        it->windows.append(ref);
        it->active = it->active || ref.active;
    }

    // Record the application of the currently active window. This makes the
    // order follow actual use, not just model order.
    QString activeApp;
    for (auto it = groups.cbegin(); it != groups.cend(); ++it) {
        if (it->active) {
            activeApp = it->appId;
            break;
        }
    }
    if (!activeApp.isEmpty() && activeApp != m_lastActiveApp) {
        m_lastActiveApp = activeApp;
        m_recency.insert(activeApp, ++m_sequence);
    }

    QList<Group> ordered = groups.values();
    for (Group &group : ordered) {
        group.recency = m_recency.value(group.appId, 0);
        std::sort(group.windows.begin(), group.windows.end(), [](const WindowRef &a, const WindowRef &b) {
            if (a.active != b.active) {
                return a.active;
            }
            if (a.lastActivated != b.lastActivated) {
                return a.lastActivated > b.lastActivated;
            }
            return a.title.localeAwareCompare(b.title) < 0;
        });
    }
    std::sort(ordered.begin(), ordered.end(), [](const Group &a, const Group &b) {
        if (a.recency != b.recency) {
            return a.recency > b.recency;
        }
        if (a.active != b.active) {
            return a.active;
        }
        return a.appName.localeAwareCompare(b.appName) < 0;
    });

    if (ordered.size() == m_groups.size()) {
        bool same = true;
        for (int i = 0; i < ordered.size(); ++i) {
            if (ordered.at(i).appId != m_groups.at(i).appId
                || ordered.at(i).windows.size() != m_groups.at(i).windows.size()) {
                same = false;
                break;
            }
        }
        if (same) {
            m_groups = ordered;
            Q_EMIT dataChanged(index(0, 0), index(m_groups.size() - 1, 0));
            return;
        }
    }

    beginResetModel();
    m_groups = ordered;
    endResetModel();
    Q_EMIT countChanged();
}

void RecentAppsModel::activateWindow(int groupIndex, int windowIndex)
{
    if (groupIndex < 0 || groupIndex >= m_groups.size()) {
        return;
    }
    const Group &group = m_groups.at(groupIndex);
    if (windowIndex < 0 || windowIndex >= group.windows.size()) {
        return;
    }
    const WindowRef window = group.windows.at(windowIndex);
    m_windows->activate(window.row);
    bumpApp(group.appId);
}

void RecentAppsModel::activateGroup(int groupIndex)
{
    if (groupIndex < 0 || groupIndex >= m_groups.size()) {
        return;
    }
    const Group &group = m_groups.at(groupIndex);
    if (group.windows.isEmpty()) {
        return;
    }

    // Single window: focused -> minimize; otherwise restore/activate.
    if (group.windows.size() == 1) {
        const WindowRef &window = group.windows.constFirst();
        if (window.active && !window.minimized) {
            m_windows->toggleMinimize(window.row);
        } else {
            m_windows->activate(window.row);
        }
        bumpApp(group.appId);
        return;
    }

    // Multiple windows: inactive group -> most recently used window.
    // Active group -> cycle to the next window, like the KDE task manager.
    int target = 0;
    if (group.active) {
        // Cycle through a stable order, not the active-first display order;
        // otherwise a three-window group would only toggle between two.
        QList<WindowRef> stable = group.windows;
        std::sort(stable.begin(), stable.end(), [](const WindowRef &a, const WindowRef &b) {
            return a.row < b.row;
        });
        int activeIndex = -1;
        for (int i = 0; i < stable.size(); ++i) {
            if (stable.at(i).active) {
                activeIndex = i;
                break;
            }
        }
        if (activeIndex >= 0) {
            target = (activeIndex + 1) % stable.size();
            m_windows->activate(stable.at(target).row);
        } else {
            m_windows->activate(stable.constFirst().row);
        }
        bumpApp(group.appId);
        return;
    }
    m_windows->activate(group.windows.at(target).row);
    bumpApp(group.appId);
}

QVariantMap RecentAppsModel::groupAt(int groupIndex) const
{
    if (groupIndex < 0 || groupIndex >= m_groups.size()) {
        return {};
    }
    const Group &group = m_groups.at(groupIndex);
    QVariantMap result;
    result.insert(QStringLiteral("appName"), group.appName);
    result.insert(QStringLiteral("appId"), group.appId);
    result.insert(QStringLiteral("windows"), data(index(groupIndex, 0), WindowsRole));
    return result;
}

void RecentAppsModel::bumpApp(const QString &appId)
{
    if (appId.isEmpty()) {
        return;
    }
    m_lastActiveApp = appId;
    m_recency.insert(appId, ++m_sequence);
    scheduleRebuild();
}
