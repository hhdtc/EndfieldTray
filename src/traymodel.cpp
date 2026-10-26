#include "traymodel.h"

#include <QCoreApplication>
#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusVariant>
#include <QDebug>
#include <QTimer>

#include <utility>

namespace
{
QString serviceName(const QString &item)
{
    const int slash = item.indexOf(QLatin1Char('/'));
    return slash >= 0 ? item.left(slash) : item;
}

QString objectPath(const QString &item)
{
    const int slash = item.indexOf(QLatin1Char('/'));
    return slash >= 0 ? item.mid(slash) : QStringLiteral("/StatusNotifierItem");
}

QVariantMap readVariantMap(const QVariant &value)
{
    QVariantMap map;
    if (!value.isValid()) {
        return map;
    }
    if (value.userType() == qMetaTypeId<QDBusArgument>()) {
        const QDBusArgument argument = value.value<QDBusArgument>();
        argument.beginMap();
        while (!argument.atEnd()) {
            argument.beginMapEntry();
            QString key;
            QVariant entry;
            argument >> key >> entry;
            argument.endMapEntry();
            map.insert(key, entry);
        }
        argument.endMap();
        return map;
    }
    if (value.canConvert<QVariantMap>()) {
        return value.toMap();
    }
    return map;
}
} // namespace

TrayModel::TrayModel(QObject *parent)
    : QAbstractListModel(parent)
{
    auto bus = QDBusConnection::sessionBus();
    const QString hostName = QStringLiteral("org.kde.StatusNotifierHost-endfield-%1").arg(QCoreApplication::applicationPid());
    bus.registerService(hostName);

    QDBusMessage registerHost = QDBusMessage::createMethodCall(QStringLiteral("org.kde.StatusNotifierWatcher"),
                                                               QStringLiteral("/StatusNotifierWatcher"),
                                                               QStringLiteral("org.kde.StatusNotifierWatcher"),
                                                               QStringLiteral("RegisterStatusNotifierHost"));
    registerHost << hostName;
    bus.send(registerHost);

    bus.connect(QStringLiteral("org.kde.StatusNotifierWatcher"),
                QStringLiteral("/StatusNotifierWatcher"),
                QStringLiteral("org.kde.StatusNotifierWatcher"),
                QStringLiteral("StatusNotifierItemRegistered"),
                this,
                SLOT(onItemRegistered(QString)));
    bus.connect(QStringLiteral("org.kde.StatusNotifierWatcher"),
                QStringLiteral("/StatusNotifierWatcher"),
                QStringLiteral("org.kde.StatusNotifierWatcher"),
                QStringLiteral("StatusNotifierItemUnregistered"),
                this,
                SLOT(onItemUnregistered(QString)));

    readAllItems();
    auto *refreshTimer = new QTimer(this);
    refreshTimer->setInterval(15000);
    connect(refreshTimer, &QTimer::timeout, this, &TrayModel::refresh);
    refreshTimer->start();
}

int TrayModel::count() const
{
    return m_items.size();
}

int TrayModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_items.size();
}

QVariant TrayModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size()) {
        return {};
    }
    const Item &item = m_items.at(index.row());
    switch (role) {
    case ServiceRole:
        return item.service;
    case IconNameRole:
        return item.iconName;
    case TitleRole:
        return item.title.isEmpty() ? item.id : item.title;
    case TooltipRole:
        return item.tooltip;
    case ItemIsMenuRole:
        return item.itemIsMenu;
    case AttentionRole:
        return item.attention;
    case IdRole:
        return item.id;
    case MenuPathRole:
        return item.menuPath;
    default:
        return {};
    }
}

QHash<int, QByteArray> TrayModel::roleNames() const
{
    return {
        {ServiceRole, "service"},
        {IconNameRole, "iconName"},
        {TitleRole, "title"},
        {TooltipRole, "tooltip"},
        {ItemIsMenuRole, "itemIsMenu"},
        {AttentionRole, "attention"},
        {IdRole, "id"},
        {MenuPathRole, "menuPath"},
    };
}

QString TrayModel::serviceAt(int row) const
{
    return row >= 0 && row < m_items.size() ? m_items.at(row).service : QString();
}

void TrayModel::readAllItems()
{
    QDBusMessage message = QDBusMessage::createMethodCall(QStringLiteral("org.kde.StatusNotifierWatcher"),
                                                          QStringLiteral("/StatusNotifierWatcher"),
                                                          QStringLiteral("org.freedesktop.DBus.Properties"),
                                                          QStringLiteral("Get"));
    message << QStringLiteral("org.kde.StatusNotifierWatcher") << QStringLiteral("RegisteredStatusNotifierItems");
    const QDBusMessage reply = QDBusConnection::sessionBus().call(message, QDBus::Block, 1000);
    if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().isEmpty()) {
        return;
    }
    QVariant value = reply.arguments().constFirst();
    if (value.userType() == qMetaTypeId<QDBusVariant>()) {
        value = value.value<QDBusVariant>().variant();
    }
    const QStringList services = value.toStringList();
    for (const QString &service : services) {
        watchItem(service);
    }
}

void TrayModel::watchItem(const QString &service)
{
    if (service.isEmpty() || m_items.size() > 64) {
        return;
    }
    for (const Item &item : m_items) {
        if (item.service == service) {
            return;
        }
    }

    Item item;
    item.service = service;
    item.path = objectPath(service);
    item.interface = QStringLiteral("org.kde.StatusNotifierItem");

    beginInsertRows(QModelIndex(), m_items.size(), m_items.size());
    m_items.append(item);
    endInsertRows();
    Q_EMIT countChanged();

    refreshItem(service);

    QDBusConnection bus = QDBusConnection::sessionBus();
    for (const QString &signal : {QStringLiteral("NewIcon"), QStringLiteral("NewTitle"), QStringLiteral("NewStatus"),
                                  QStringLiteral("NewToolTip"), QStringLiteral("NewMenu"), QStringLiteral("NewAttentionIcon")}) {
        bus.connect(serviceName(service), objectPath(service), item.interface, signal, this,
                    SLOT(onItemChanged()));
    }
    bus.connect(serviceName(service), objectPath(service), QStringLiteral("org.freedesktop.DBus.Properties"),
                QStringLiteral("PropertiesChanged"), this, SLOT(onItemChanged()));
}

void TrayModel::unwatchItem(const QString &service)
{
    for (int i = 0; i < m_items.size(); ++i) {
        if (m_items.at(i).service != service) {
            continue;
        }
        beginRemoveRows(QModelIndex(), i, i);
        m_items.removeAt(i);
        endRemoveRows();
        Q_EMIT countChanged();
        return;
    }
}

void TrayModel::refreshItem(const QString &service)
{
    int row = -1;
    for (int i = 0; i < m_items.size(); ++i) {
        if (m_items.at(i).service == service) {
            row = i;
            break;
        }
    }
    if (row < 0) {
        return;
    }

    const Item current = m_items.at(row);
    QDBusMessage message = QDBusMessage::createMethodCall(serviceName(current.service),
                                                          current.path,
                                                          QStringLiteral("org.freedesktop.DBus.Properties"),
                                                          QStringLiteral("GetAll"));
    message << current.interface;
    const QDBusMessage reply = QDBusConnection::sessionBus().call(message, QDBus::Block, 700);
    if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().isEmpty()) {
        return;
    }

    const QVariantMap properties = readVariantMap(reply.arguments().constFirst());
    if (properties.isEmpty()) {
        return;
    }

    Item &item = m_items[row];
    item.iconName = properties.value(QStringLiteral("IconName")).toString();
    item.title = properties.value(QStringLiteral("Title")).toString();
    item.id = properties.value(QStringLiteral("Id")).toString();
    item.itemIsMenu = properties.value(QStringLiteral("ItemIsMenu")).toBool();
    const QString status = properties.value(QStringLiteral("Status")).toString();
    item.attention = status.compare(QLatin1String("NeedsAttention"), Qt::CaseInsensitive) == 0;

    const QVariant menu = properties.value(QStringLiteral("Menu"));
    if (menu.userType() == qMetaTypeId<QDBusObjectPath>()) {
        item.menuPath = menu.value<QDBusObjectPath>().path();
    } else {
        item.menuPath = menu.toString();
    }

    // Some implementations only publish ToolTip, not Title.
    if (item.title.isEmpty()) {
        const QString tooltip = properties.value(QStringLiteral("ToolTipTitle")).toString();
        if (!tooltip.isEmpty()) {
            item.title = tooltip;
        }
    }

    Q_EMIT dataChanged(index(row, 0), index(row, 0));
}

void TrayModel::refresh()
{
    for (const Item &item : std::as_const(m_items)) {
        refreshItem(item.service);
    }
}

void TrayModel::onItemChanged()
{
    refresh();
}
