#pragma once

#include <QObject>
#include <QVariantList>

typedef struct _GDBusConnection GDBusConnection;

/**
 * Minimal StatusNotifierItem companion.
 *
 * The tray icons themselves are provided by Plasma's StatusNotifierModel in
 * QML. This object only performs the two things the model cannot: sending
 * activation requests and importing a com.canonical.dbusmenu tree.
 *
 * Menu layouts are read with GDBus because QtDBus cannot represent the
 * `(ia{sv}av)` recursive variant used by DBusMenu in every environment.
 */
class TrayController : public QObject
{
    Q_OBJECT

public:
    explicit TrayController(QObject *parent = nullptr);
    ~TrayController() override;

    Q_INVOKABLE bool itemIsMenu(const QString &service);
    Q_INVOKABLE void activate(const QString &service, int button);
    Q_INVOKABLE QVariantList menuFor(const QString &service);
    Q_INVOKABLE QVariantList submenuFor(const QString &service, int parentId);
    Q_INVOKABLE void triggerMenu(const QString &service, int itemId);
    Q_INVOKABLE void aboutToShow(const QString &service, int itemId);

Q_SIGNALS:
    void errorOccurred(const QString &message);

private:
    struct ItemAddress {
        QString service;
        QString path;
        QString interface;
    };

    ItemAddress addressFor(const QString &service) const;
    QVariant property(const ItemAddress &address, const QString &name) const;
    QVariantList layout(const QString &service, int parentId);
    GDBusConnection *bus();

    GDBusConnection *m_bus = nullptr;
};
