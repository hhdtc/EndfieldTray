#include "traycontroller.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusVariant>
#include <QDebug>
#include <QStringList>
#include <QDateTime>

#include <functional>

#undef signals
#include <gio/gio.h>

namespace
{
constexpr int kMaxMenuDepth = 8;
constexpr int kMaxMenuItems = 400;

QString cleanLabel(QString label)
{
    // DBusMenu uses GTK-style mnemonics. "&&" is a literal ampersand.
    label.replace(QStringLiteral("&&"), QStringLiteral("\u0001"));
    label.remove(QLatin1Char('&'));
    label.replace(QStringLiteral("\u0001"), QStringLiteral("&"));
    return label;
}

QString variantString(GVariant *value)
{
    if (!value) {
        return {};
    }
    if (g_variant_is_of_type(value, G_VARIANT_TYPE_STRING)) {
        return QString::fromUtf8(g_variant_get_string(value, nullptr));
    }
    if (g_variant_is_of_type(value, G_VARIANT_TYPE_OBJECT_PATH)) {
        return QString::fromUtf8(g_variant_get_string(value, nullptr));
    }
    return {};
}
} // namespace

TrayController::TrayController(QObject *parent)
    : QObject(parent)
{
}

TrayController::~TrayController()
{
    if (m_bus) {
        g_object_unref(m_bus);
        m_bus = nullptr;
    }
}

GDBusConnection *TrayController::bus()
{
    if (m_bus) {
        return m_bus;
    }

    GError *error = nullptr;
    m_bus = g_bus_get_sync(G_BUS_TYPE_SESSION, nullptr, &error);
    if (!m_bus) {
        qWarning() << "endfield-tray: failed to open session bus for tray menus:" << (error ? error->message : "unknown error");
        if (error) {
            g_error_free(error);
        }
    }
    return m_bus;
}

TrayController::ItemAddress TrayController::addressFor(const QString &service) const
{
    ItemAddress address;
    const int slash = service.indexOf(QLatin1Char('/'));
    if (slash >= 0) {
        address.service = service.left(slash);
        address.path = service.mid(slash);
    } else {
        address.service = service;
        address.path = QStringLiteral("/StatusNotifierItem");
    }
    address.interface = QStringLiteral("org.kde.StatusNotifierItem");
    return address;
}

QVariant TrayController::property(const ItemAddress &address, const QString &name) const
{
    QDBusMessage msg = QDBusMessage::createMethodCall(address.service,
                                                       address.path,
                                                       QStringLiteral("org.freedesktop.DBus.Properties"),
                                                       QStringLiteral("Get"));
    msg << address.interface << name;
    const QDBusMessage reply = QDBusConnection::sessionBus().call(msg, QDBus::Block, 700);
    if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().isEmpty()) {
        return {};
    }
    const QVariant first = reply.arguments().constFirst();
    if (first.userType() == qMetaTypeId<QDBusVariant>()) {
        return first.value<QDBusVariant>().variant();
    }
    return first;
}

bool TrayController::itemIsMenu(const QString &service)
{
    const ItemAddress address = addressFor(service);
    return property(address, QStringLiteral("ItemIsMenu")).toBool();
}

void TrayController::activate(const QString &service, int button)
{
    const ItemAddress address = addressFor(service);
    QString method;
    switch (button) {
    case Qt::MiddleButton:
        method = QStringLiteral("SecondaryActivate");
        break;
    case Qt::RightButton:
        method = QStringLiteral("ContextMenu");
        break;
    case Qt::LeftButton:
    default:
        method = QStringLiteral("Activate");
        break;
    }

    QDBusMessage msg = QDBusMessage::createMethodCall(address.service, address.path, address.interface, method);
    msg << 0 << 0;
    QDBusConnection::sessionBus().send(msg);
}

QVariantList TrayController::menuFor(const QString &service)
{
    const ItemAddress address = addressFor(service);
    QVariant menuPath = property(address, QStringLiteral("Menu"));
    if (!menuPath.isValid()) {
        return {};
    }

    QString path = menuPath.toString();
    if (menuPath.userType() == qMetaTypeId<QDBusObjectPath>()) {
        path = menuPath.value<QDBusObjectPath>().path();
    }
    if (path.isEmpty() || path == QLatin1String("/")) {
        return {};
    }

    aboutToShow(service, 0);
    return layout(service, 0);
}

QVariantList TrayController::submenuFor(const QString &service, int parentId)
{
    aboutToShow(service, parentId);
    return layout(service, parentId);
}

QVariantList TrayController::layout(const QString &service, int parentId)
{
    GDBusConnection *connection = bus();
    if (!connection) {
        return {};
    }

    const ItemAddress address = addressFor(service);
    QVariant menuPath = property(address, QStringLiteral("Menu"));
    QString path = menuPath.toString();
    if (menuPath.userType() == qMetaTypeId<QDBusObjectPath>()) {
        path = menuPath.value<QDBusObjectPath>().path();
    }
    if (path.isEmpty() || path == QLatin1String("/")) {
        return {};
    }

    GError *error = nullptr;
    GVariant *reply = g_dbus_connection_call_sync(connection,
                                                  address.service.toUtf8().constData(),
                                                  path.toUtf8().constData(),
                                                  "com.canonical.dbusmenu",
                                                  "GetLayout",
                                                  g_variant_new("(iias)", parentId, 1, nullptr),
                                                  G_VARIANT_TYPE("(u(ia{sv}av))"),
                                                  G_DBUS_CALL_FLAGS_NONE,
                                                  900,
                                                  nullptr,
                                                  &error);
    if (!reply) {
        if (error) {
            qWarning() << "endfield-tray: DBusMenu GetLayout failed for" << service << error->message;
            g_error_free(error);
        }
        return {};
    }

    guint32 revision = 0;
    GVariant *root = nullptr;
    g_variant_get(reply, "(u@(ia{sv}av))", &revision, &root);
    Q_UNUSED(revision)

    QVariantList result;
    int budget = kMaxMenuItems;

    std::function<QVariantList(GVariant *, int)> parse = [&](GVariant *node, int depth) -> QVariantList {
        QVariantList items;
        if (!node || depth > kMaxMenuDepth || budget <= 0) {
            return items;
        }

        gint id = -1;
        GVariant *props = nullptr;
        GVariant *children = nullptr;
        g_variant_get(node, "(i@a{sv}@av)", &id, &props, &children);

        QVariantMap properties;
        GVariantIter propIter;
        const gchar *key = nullptr;
        GVariant *value = nullptr;
        g_variant_iter_init(&propIter, props);
        while (g_variant_iter_next(&propIter, "{&sv}", &key, &value)) {
            const QString propertyName = QString::fromUtf8(key);
            if (g_variant_is_of_type(value, G_VARIANT_TYPE_BOOLEAN)) {
                properties.insert(propertyName, g_variant_get_boolean(value));
            } else if (g_variant_is_of_type(value, G_VARIANT_TYPE_INT32)) {
                properties.insert(propertyName, g_variant_get_int32(value));
            } else if (g_variant_is_of_type(value, G_VARIANT_TYPE_STRING)
                       || g_variant_is_of_type(value, G_VARIANT_TYPE_OBJECT_PATH)) {
                properties.insert(propertyName, variantString(value));
            }
            g_variant_unref(value);
        }

        const bool visible = !properties.contains(QStringLiteral("visible"))
            || properties.value(QStringLiteral("visible")).toBool();
        const bool separator = properties.contains(QStringLiteral("type"))
            && properties.value(QStringLiteral("type")).toString() == QLatin1String("separator");
        const bool enabled = !properties.contains(QStringLiteral("enabled"))
            || properties.value(QStringLiteral("enabled")).toBool();

        if (!visible) {
            g_variant_unref(props);
            g_variant_unref(children);
            return items;
        }

        QVariantList childItems;
        GVariantIter childIter;
        GVariant *childValue = nullptr;
        g_variant_iter_init(&childIter, children);
        while ((childValue = g_variant_iter_next_value(&childIter))) {
            GVariant *child = g_variant_get_variant(childValue);
            childItems += parse(child, depth + 1);
            g_variant_unref(child);
            g_variant_unref(childValue);
        }

        if (separator) {
            QVariantMap item;
            item.insert(QStringLiteral("id"), id);
            item.insert(QStringLiteral("separator"), true);
            item.insert(QStringLiteral("label"), QString());
            item.insert(QStringLiteral("enabled"), false);
            item.insert(QStringLiteral("visible"), true);
            item.insert(QStringLiteral("hasChildren"), false);
            item.insert(QStringLiteral("checked"), false);
            item.insert(QStringLiteral("checkable"), false);
            item.insert(QStringLiteral("icon"), QString());
            item.insert(QStringLiteral("children"), QVariantList{});
            items.append(item);
        } else {
            QVariantMap item;
            item.insert(QStringLiteral("id"), id);
            item.insert(QStringLiteral("separator"), false);
            item.insert(QStringLiteral("label"), cleanLabel(properties.value(QStringLiteral("label")).toString()));
            item.insert(QStringLiteral("enabled"), enabled);
            item.insert(QStringLiteral("visible"), true);

            const QString toggleType = properties.value(QStringLiteral("toggle-type")).toString();
            const int toggleState = properties.value(QStringLiteral("toggle-state"), 0).toInt();
            item.insert(QStringLiteral("checkable"), !toggleType.isEmpty());
            item.insert(QStringLiteral("checked"), toggleState == 1);
            item.insert(QStringLiteral("icon"), properties.value(QStringLiteral("icon-name")).toString());
            item.insert(QStringLiteral("hasChildren"), !childItems.isEmpty());
            item.insert(QStringLiteral("children"), childItems);
            items.append(item);
            --budget;
        }

        g_variant_unref(props);
        g_variant_unref(children);
        return items;
    };

    result = parse(root, 0);
    if (result.size() == 1) {
        // `parse` returns the parent node itself; callers want its children.
        result = result.constFirst().toMap().value(QStringLiteral("children")).toList();
    }
    g_variant_unref(root);
    g_variant_unref(reply);
    return result;
}

void TrayController::triggerMenu(const QString &service, int itemId)
{
    const ItemAddress address = addressFor(service);
    QVariant menuPath = property(address, QStringLiteral("Menu"));
    QString path = menuPath.toString();
    if (menuPath.userType() == qMetaTypeId<QDBusObjectPath>()) {
        path = menuPath.value<QDBusObjectPath>().path();
    }
    if (path.isEmpty() || path == QLatin1String("/")) {
        return;
    }

    QDBusMessage msg = QDBusMessage::createMethodCall(address.service,
                                                       path,
                                                       QStringLiteral("com.canonical.dbusmenu"),
                                                       QStringLiteral("Event"));
    msg << itemId << QStringLiteral("clicked")
        << QVariant::fromValue(QDBusVariant(QVariant(QString())))
        << static_cast<uint>(QDateTime::currentMSecsSinceEpoch() & 0xffffffffU);
    QDBusConnection::sessionBus().send(msg);
}

void TrayController::aboutToShow(const QString &service, int itemId)
{
    const ItemAddress address = addressFor(service);
    QVariant menuPath = property(address, QStringLiteral("Menu"));
    QString path = menuPath.toString();
    if (menuPath.userType() == qMetaTypeId<QDBusObjectPath>()) {
        path = menuPath.value<QDBusObjectPath>().path();
    }
    if (path.isEmpty() || path == QLatin1String("/")) {
        return;
    }

    QDBusMessage msg = QDBusMessage::createMethodCall(address.service,
                                                       path,
                                                       QStringLiteral("com.canonical.dbusmenu"),
                                                       QStringLiteral("AboutToShow"));
    msg << itemId;
    QDBusConnection::sessionBus().call(msg, QDBus::Block, 400);
}
