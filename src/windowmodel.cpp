#include "windowmodel.h"

#include <abstracttasksmodel.h>
#include <tasksmodel.h>

#include <QIcon>

using namespace TaskManager;

WindowModel::WindowModel(QObject *parent)
    : QSortFilterProxyModel(parent)
    , m_tasks(new TasksModel(this))
{
    m_tasks->setFilterByVirtualDesktop(false);
    m_tasks->setFilterByCurrentVirtualDesktop(false);
    m_tasks->setFilterByScreen(false);
    m_tasks->setFilterByActivity(false);
    m_tasks->setSortMode(TasksModel::SortAlpha);
    m_tasks->setGroupMode(TasksModel::GroupDisabled);
    m_tasks->setSeparateLaunchers(true);

    setSourceModel(m_tasks);
    setDynamicSortFilter(true);
    setSortRole(Qt::DisplayRole);

    connect(m_tasks, &QAbstractItemModel::modelReset, this, &WindowModel::countChanged);
    connect(m_tasks, &QAbstractItemModel::rowsInserted, this, &WindowModel::countChanged);
    connect(m_tasks, &QAbstractItemModel::rowsRemoved, this, &WindowModel::countChanged);
    connect(this, &QAbstractItemModel::rowsInserted, this, &WindowModel::countChanged);
    connect(this, &QAbstractItemModel::rowsRemoved, this, &WindowModel::countChanged);
    connect(this, &QAbstractItemModel::modelReset, this, &WindowModel::countChanged);

    connect(m_tasks, &QAbstractItemModel::dataChanged, this, &WindowModel::updateFullScreenActive);
    connect(m_tasks, &QAbstractItemModel::rowsInserted, this, &WindowModel::updateFullScreenActive);
    connect(m_tasks, &QAbstractItemModel::rowsRemoved, this, &WindowModel::updateFullScreenActive);
    connect(m_tasks, &QAbstractItemModel::modelReset, this, &WindowModel::updateFullScreenActive);
    connect(m_tasks, &QAbstractItemModel::layoutChanged, this, &WindowModel::updateFullScreenActive);
    updateFullScreenActive();
}

int WindowModel::count() const
{
    return rowCount();
}

int WindowModel::rowCount(const QModelIndex &parent) const
{
    return QSortFilterProxyModel::rowCount(parent);
}

bool WindowModel::filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const
{
    const QModelIndex idx = m_tasks->index(sourceRow, 0, sourceParent);
    if (!idx.isValid()) {
        return false;
    }
    return idx.data(AbstractTasksModel::IsWindow).toBool()
        && !idx.data(AbstractTasksModel::SkipTaskbar).toBool();
}

QVariant WindowModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid()) {
        return {};
    }

    const QModelIndex src = mapToSource(index);
    switch (role) {
    case TitleRole:
        return src.data(Qt::DisplayRole).toString();
    case AppNameRole:
        return src.data(AbstractTasksModel::AppName).toString();
    case IconRole:
        return src.data(Qt::DecorationRole);
    case ActiveRole:
        return src.data(AbstractTasksModel::IsActive).toBool();
    case MinimizedRole:
        return src.data(AbstractTasksModel::IsMinimized).toBool();
    case ClosableRole:
        return src.data(AbstractTasksModel::IsClosable).toBool();
    case DesktopRole: {
        const QVariant desktops = src.data(AbstractTasksModel::VirtualDesktops);
        const QList<int> list = desktops.value<QList<int>>();
        return list.isEmpty() ? 0 : list.first();
    }
    case AppIdRole:
        return src.data(AbstractTasksModel::AppId).toString();
    case FullScreenRole:
        return src.data(AbstractTasksModel::IsFullScreen).toBool();
    default:
        return QSortFilterProxyModel::data(index, role);
    }
}

QHash<int, QByteArray> WindowModel::roleNames() const
{
    return {
        {TitleRole, "title"},
        {AppNameRole, "appName"},
        {IconRole, "icon"},
        {ActiveRole, "active"},
        {MinimizedRole, "minimized"},
        {ClosableRole, "closable"},
        {DesktopRole, "desktop"},
        {AppIdRole, "appId"},
        {FullScreenRole, "fullScreen"},
    };
}

void WindowModel::updateFullScreenActive()
{
    bool active = false;
    for (int row = 0; row < m_tasks->rowCount(); ++row) {
        const QModelIndex idx = m_tasks->index(row, 0);
        if (!idx.isValid()
            || !idx.data(AbstractTasksModel::IsWindow).toBool()
            || idx.data(AbstractTasksModel::SkipTaskbar).toBool()
            || !idx.data(AbstractTasksModel::IsFullScreen).toBool()
            || !idx.data(AbstractTasksModel::IsActive).toBool()
            || idx.data(AbstractTasksModel::IsMinimized).toBool()) {
            continue;
        }
        active = true;
        break;
    }
    if (m_fullScreenActive != active) {
        m_fullScreenActive = active;
        Q_EMIT fullScreenActiveChanged();
    }
}

QModelIndex WindowModel::sourceIndexForRow(int row) const
{
    const QModelIndex proxyIndex = index(row, 0);
    if (!proxyIndex.isValid()) {
        return {};
    }
    return mapToSource(proxyIndex);
}

void WindowModel::activate(int row)
{
    const QModelIndex src = sourceIndexForRow(row);
    if (src.isValid()) {
        m_tasks->requestActivate(src);
    }
}

void WindowModel::closeWindow(int row)
{
    const QModelIndex src = sourceIndexForRow(row);
    if (src.isValid()) {
        m_tasks->requestClose(src);
    }
}

void WindowModel::toggleMinimize(int row)
{
    const QModelIndex src = sourceIndexForRow(row);
    if (src.isValid()) {
        m_tasks->requestToggleMinimized(src);
    }
}
