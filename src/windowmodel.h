#pragma once

#include <QSortFilterProxyModel>

namespace TaskManager
{
class TasksModel;
}

/**
 * Flat, window-only view over Plasma's task model.
 *
 * Plasma's task manager does the hard Wayland work (foreign toplevels,
 * activation, minimization and close requests); we only filter launchers and
 * startup tasks out and present a compact, stable, alphabetical list.
 */
class WindowModel : public QSortFilterProxyModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(bool fullScreenActive READ fullScreenActive NOTIFY fullScreenActiveChanged)

public:
    enum Role {
        TitleRole = Qt::UserRole + 1,
        AppNameRole,
        IconRole,
        ActiveRole,
        MinimizedRole,
        ClosableRole,
        DesktopRole,
        AppIdRole,
        FullScreenRole,
        LastActivatedRole,
    };
    Q_ENUM(Role)

    explicit WindowModel(QObject *parent = nullptr);

    int count() const;
    bool fullScreenActive() const { return m_fullScreenActive; }
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void activate(int row);
    Q_INVOKABLE void closeWindow(int row);
    Q_INVOKABLE void toggleMinimize(int row);

Q_SIGNALS:
    void countChanged();
    void fullScreenActiveChanged();

protected:
    bool filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const override;

private:
    QModelIndex sourceIndexForRow(int row) const;
    void updateFullScreenActive();

    bool m_fullScreenActive = false;

    TaskManager::TasksModel *m_tasks;
};
