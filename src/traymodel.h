#pragma once

#include <QAbstractListModel>
#include <QList>

/**
 * Small StatusNotifierItem host.
 *
 * Plasma's private StatusNotifierModel is convenient inside a plasmoid but is
 * not reliable for a standalone shell: depending on host registration it can
 * expose rows with empty role data. Owning the (small) protocol here keeps the
 * tray deterministic and gives the QML side flat, lower-case roles.
 */
class TrayModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    enum Role {
        ServiceRole = Qt::UserRole + 1,
        IconNameRole,
        TitleRole,
        TooltipRole,
        ItemIsMenuRole,
        AttentionRole,
        IdRole,
        MenuPathRole,
    };
    Q_ENUM(Role)

    explicit TrayModel(QObject *parent = nullptr);

    int count() const;
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE QString serviceAt(int row) const;
    Q_INVOKABLE void refresh();

Q_SIGNALS:
    void countChanged();

private:
    struct Item {
        QString service;
        QString path;
        QString interface;
        QString iconName;
        QString title;
        QString tooltip;
        QString id;
        QString menuPath;
        bool itemIsMenu = false;
        bool attention = false;
    };

    void watchItem(const QString &service);
    void unwatchItem(const QString &service);
    void refreshItem(const QString &service);
    void readAllItems();

private Q_SLOTS:
    void onItemRegistered(const QString &service) { watchItem(service); }
    void onItemUnregistered(const QString &service) { unwatchItem(service); }
    void onItemChanged();

private:
    QList<Item> m_items;
};
