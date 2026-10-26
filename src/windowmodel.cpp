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
    };
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
