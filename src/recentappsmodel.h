#pragma once

#include <QAbstractListModel>
#include <QIcon>
#include <QList>
#include <QTimer>

class WindowModel;

/**
 * Groups open windows by application and exposes the most recently used
 * applications first. The bar renders the first three groups; every group can
 * expand to its individual windows on hover.
 */
class RecentAppsModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    enum Role {
        AppNameRole = Qt::UserRole + 1,
        AppIdRole,
        IconRole,
        CountRole,
        ActiveRole,
        WindowsRole,
        RecencyRole,
    };
    Q_ENUM(Role)

    explicit RecentAppsModel(WindowModel *windows, QObject *parent = nullptr);

    int count() const;
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void activateWindow(int groupIndex, int windowIndex);
    Q_INVOKABLE void activateGroup(int groupIndex);
    Q_INVOKABLE void bumpApp(const QString &appId);
    Q_INVOKABLE void setActive(bool active);
    Q_INVOKABLE QVariantMap groupAt(int groupIndex) const;

Q_SIGNALS:
    void countChanged();

private:
    struct WindowRef {
        int row = -1;
        QString title;
        bool active = false;
        bool minimized = false;
        qint64 lastActivated = 0;
    };
    struct Group {
        QString appId;
        QString appName;
        QIcon icon;
        QList<WindowRef> windows;
        bool active = false;
        int recency = 0;
    };

    void scheduleRebuild();
    void rebuild();

    WindowModel *m_windows;
    QList<Group> m_groups;
    QHash<QString, int> m_recency;
    QString m_lastActiveApp;
    int m_sequence = 0;
    bool m_active = true;
    QTimer m_rebuildTimer;
};
