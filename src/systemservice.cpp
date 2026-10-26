#include "systemservice.h"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QSysInfo>
#include <QtMath>
#include <QRegularExpression>

#include <algorithm>

namespace
{
QStringList splitNmcli(const QString &line)
{
    QStringList fields;
    QString current;
    bool escaped = false;
    for (const QChar ch : line) {
        if (escaped) {
            current.append(ch);
            escaped = false;
        } else if (ch == QLatin1Char('\\')) {
            escaped = true;
        } else if (ch == QLatin1Char(':')) {
            fields.append(current);
            current.clear();
        } else {
            current.append(ch);
        }
    }
    fields.append(current);
    return fields;
}

QString powerProfileLabel(const QString &profile)
{
    if (profile == QLatin1String("power-saver")) {
        return QStringLiteral("省电");
    }
    if (profile == QLatin1String("balanced")) {
        return QStringLiteral("平衡");
    }
    if (profile == QLatin1String("performance")) {
        return QStringLiteral("性能");
    }
    return profile;
}

QString readTextFile(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return {};
    }
    return QString::fromUtf8(file.readAll()).trimmed();
}

int readIntFile(const QString &path, int fallback = 0)
{
    bool ok = false;
    const int value = readTextFile(path).toInt(&ok);
    return ok ? value : fallback;
}

qint64 readNumberFile(const QString &path)
{
    bool ok = false;
    const qint64 value = readTextFile(path).toLongLong(&ok);
    return ok ? value : 0;
}

bool serviceRegistered(const QString &service)
{
    auto *iface = QDBusConnection::sessionBus().interface();
    return iface && iface->isServiceRegistered(service).value();
}

void callSession(const QString &service, const QString &path, const QString &interface, const QString &method)
{
    QDBusMessage message = QDBusMessage::createMethodCall(service, path, interface, method);
    QDBusConnection::sessionBus().send(message);
}

void callSystem(const QString &service, const QString &path, const QString &interface, const QString &method, const QVariantList &arguments = {})
{
    QDBusMessage message = QDBusMessage::createMethodCall(service, path, interface, method);
    for (const QVariant &argument : arguments) {
        message << argument;
    }
    QDBusConnection::systemBus().send(message);
}
} // namespace

SystemService::SystemService(QObject *parent)
    : QObject(parent)
{
    m_wifiAvailable = !QStandardPaths::findExecutable(QStringLiteral("nmcli")).isEmpty();
    m_powerProfileAvailable = !QStandardPaths::findExecutable(QStringLiteral("powerprofilesctl")).isEmpty();

    m_audioTimer.setInterval(3000);
    connect(&m_audioTimer, &QTimer::timeout, this, &SystemService::pollAudio);

    m_netTimer.setInterval(30000);
    connect(&m_netTimer, &QTimer::timeout, this, &SystemService::pollNetwork);

    m_batteryTimer.setInterval(60000);
    connect(&m_batteryTimer, &QTimer::timeout, this, &SystemService::pollBattery);

    m_volumeApplyTimer.setSingleShot(true);
    m_volumeApplyTimer.setInterval(55);
    connect(&m_volumeApplyTimer, &QTimer::timeout, this, &SystemService::applyVolume);

}

QString SystemService::userName() const
{
    return qEnvironmentVariable("USER", qEnvironmentVariable("LOGNAME", QStringLiteral("USER")));
}

QString SystemService::hostName() const
{
    return QSysInfo::machineHostName();
}

void SystemService::refreshAll()
{
    pollAudio();
    pollNetwork();
    pollBattery();
    refreshNetworks();
    refreshPowerProfile();
    refreshAudioSinks();
}

void SystemService::setUiActive(bool active)
{
    m_uiActive = active;

    if (active) {
        m_audioTimer.start();
        m_netTimer.start();
        m_batteryTimer.start();
        pollAudio();
        pollNetwork();
        pollBattery();
    } else {
        m_audioTimer.stop();
        m_netTimer.stop();
        m_batteryTimer.stop();
    }

    // Fill the first frame even while the bar starts collapsed; after this
    // one-shot fetch the timers stay quiet until the user hovers again.
    if (!m_uiInitialized) {
        m_uiInitialized = true;
        pollAudio();
        pollNetwork();
        pollBattery();
    }
}

void SystemService::run(const QString &program,
                        const QStringList &arguments,
                        std::function<void(int, const QString &, const QString &)> callback)
{
    auto *process = new QProcess(this);
    process->setProcessChannelMode(QProcess::SeparateChannels);
    connect(process, &QProcess::errorOccurred, this, [process, callback](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) {
            callback(-1, QString(), process->errorString());
            process->deleteLater();
        }
    });
    connect(process, qOverload<int, QProcess::ExitStatus>(&QProcess::finished), this,
            [process, callback](int exitCode, QProcess::ExitStatus status) {
                const QString out = QString::fromUtf8(process->readAllStandardOutput());
                const QString err = QString::fromUtf8(process->readAllStandardError());
                callback(status == QProcess::NormalExit ? exitCode : -1, out, err);
                process->deleteLater();
            });
    process->start(program, arguments);
}

void SystemService::pollAudio()
{
    if (m_audioProcess) {
        return;
    }

    const QString wpctl = QStandardPaths::findExecutable(QStringLiteral("wpctl"));
    if (wpctl.isEmpty()) {
        m_audioBackend = QStringLiteral("PULSEAUDIO");
        auto *process = new QProcess(this);
        m_audioProcess = process;
        connect(process, qOverload<int, QProcess::ExitStatus>(&QProcess::finished), this,
                [this, process](int, QProcess::ExitStatus) {
                    const QString out = QString::fromUtf8(process->readAllStandardOutput());
                    const int percentIndex = out.indexOf(QLatin1Char('%'));
                    if (percentIndex > 0) {
                        int start = percentIndex - 1;
                        while (start >= 0 && out.at(start).isDigit()) {
                            --start;
                        }
                        bool ok = false;
                        const int value = out.mid(start + 1, percentIndex - start - 1).toInt(&ok);
                        if (ok && value != m_volume) {
                            m_volume = qBound(0, value, 100);
                            Q_EMIT volumeChanged();
                        }
                    }
                    m_audioProcess = nullptr;
                    process->deleteLater();
                });
        process->start(QStringLiteral("pactl"),
                       {QStringLiteral("get-sink-volume"), QStringLiteral("@DEFAULT_SINK@")});
        return;
    }

    m_audioBackend = QStringLiteral("PIPEWIRE");
    auto *process = new QProcess(this);
    m_audioProcess = process;
    connect(process, qOverload<int, QProcess::ExitStatus>(&QProcess::finished), this,
            [this, process](int exitCode, QProcess::ExitStatus status) {
                const QString out = QString::fromUtf8(process->readAllStandardOutput());
                if (status == QProcess::NormalExit && exitCode == 0) {
                    static const QRegularExpression volumePattern(QStringLiteral("Volume:\\s*([0-9]+(?:\\.[0-9]+)?)"));
                    const QRegularExpressionMatch match = volumePattern.match(out);
                    if (match.hasMatch()) {
                        const int value = qBound(0, qRound(match.captured(1).toDouble() * 100.0), 100);
                        const bool muted = out.contains(QStringLiteral("[MUTED]"));
                        if (value != m_volume) {
                            m_volume = value;
                            Q_EMIT volumeChanged();
                        }
                        if (muted != m_muted) {
                            m_muted = muted;
                            Q_EMIT mutedChanged();
                        }
                    }
                }
                m_audioProcess = nullptr;
                process->deleteLater();
            });
    process->start(wpctl, {QStringLiteral("get-volume"), QStringLiteral("@DEFAULT_AUDIO_SINK@")});
}

void SystemService::setVolume(int percent)
{
    const int value = qBound(0, percent, 100);
    if (value == m_volume) {
        return;
    }
    m_volume = value;
    m_pendingVolume = value;
    Q_EMIT volumeChanged();
    m_volumeApplyTimer.start();
}

void SystemService::adjustVolume(int delta)
{
    setVolume(m_volume + delta);
}

void SystemService::toggleMute()
{
    const QString wpctl = QStandardPaths::findExecutable(QStringLiteral("wpctl"));
    if (!wpctl.isEmpty()) {
        QProcess::startDetached(wpctl,
                                {QStringLiteral("set-mute"), QStringLiteral("@DEFAULT_AUDIO_SINK@"), QStringLiteral("toggle")});
    } else {
        QProcess::startDetached(QStringLiteral("pactl"),
                                {QStringLiteral("set-sink-mute"), QStringLiteral("@DEFAULT_SINK@"), QStringLiteral("toggle")});
    }
    QTimer::singleShot(180, this, &SystemService::pollAudio);
}

void SystemService::applyVolume()
{
    if (m_pendingVolume < 0) {
        return;
    }
    const int value = m_pendingVolume;
    m_pendingVolume = -1;

    const QString wpctl = QStandardPaths::findExecutable(QStringLiteral("wpctl"));
    if (!wpctl.isEmpty()) {
        QProcess::startDetached(wpctl,
                                {QStringLiteral("set-volume"),
                                 QStringLiteral("@DEFAULT_AUDIO_SINK@"),
                                 QStringLiteral("%1%").arg(value)});
    } else {
        QProcess::startDetached(QStringLiteral("pactl"),
                                {QStringLiteral("set-sink-volume"),
                                 QStringLiteral("@DEFAULT_SINK@"),
                                 QStringLiteral("%1%").arg(value)});
    }
}

void SystemService::pollNetwork()
{
    if (!m_wifiAvailable || m_netPollRunning) {
        return;
    }
    m_netPollRunning = true;

    run(QStringLiteral("nmcli"),
        {QStringLiteral("-t"), QStringLiteral("-f"), QStringLiteral("DEVICE,TYPE,STATE,CONNECTION"), QStringLiteral("device"), QStringLiteral("status")},
        [this](int code, const QString &out, const QString &) {
            if (code == 0) {
                parseDeviceStatus(out);
            }
            run(QStringLiteral("nmcli"),
                {QStringLiteral("-t"), QStringLiteral("-f"), QStringLiteral("IN-USE,SSID,SIGNAL,SECURITY"), QStringLiteral("device"), QStringLiteral("wifi"), QStringLiteral("list"), QStringLiteral("--rescan"), QStringLiteral("no")},
                [this](int listCode, const QString &listOut, const QString &) {
                    if (listCode == 0) {
                        parseWifiList(listOut, false);
                    }
                    run(QStringLiteral("nmcli"), {QStringLiteral("-t"), QStringLiteral("radio"), QStringLiteral("wifi")},
                        [this](int radioCode, const QString &radioOut, const QString &) {
                            if (radioCode == 0) {
                                parseRadio(radioOut);
                            }
                            m_netPollRunning = false;
                            Q_EMIT wifiChanged();
                        });
                });
        });
}

void SystemService::parseDeviceStatus(const QString &output)
{
    bool connected = false;
    QString ssid;
    QString iface;

    const QStringList lines = output.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
    for (const QString &line : lines) {
        const QStringList fields = splitNmcli(line);
        if (fields.size() < 4 || fields.at(1) != QLatin1String("wifi")) {
            continue;
        }
        const QString device = fields.at(0);
        const QString state = fields.at(2);
        const QString connection = fields.at(3);
        iface = device;
        if (state == QLatin1String("connected")) {
            connected = true;
            ssid = connection;
        }
    }

    if (m_wifiIface != iface) {
        m_wifiIface = iface;
    }
    if (m_wifiConnected != connected) {
        m_wifiConnected = connected;
    }
    if (!ssid.isEmpty() && m_wifiSsid != ssid) {
        m_wifiSsid = ssid;
    }
    if (!connected && m_wifiSsid != ssid) {
        m_wifiSsid = ssid;
        m_wifiSignal = 0;
    }
}

void SystemService::parseWifiList(const QString &output, bool replaceNetworks)
{
    struct Network {
        QString ssid;
        QString security;
        int signal = 0;
        bool active = false;
    };

    QHash<QString, Network> networks;
    const QStringList lines = output.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
    for (const QString &line : lines) {
        const QStringList fields = splitNmcli(line);
        if (fields.size() < 4) {
            continue;
        }
        const bool active = fields.at(0).trimmed() == QLatin1String("*")
            || fields.at(0).trimmed().contains(QLatin1Char('*'));
        const QString ssid = fields.at(1);
        if (ssid.isEmpty()) {
            continue;
        }
        bool ok = false;
        const int signal = qBound(0, fields.at(2).toInt(&ok), 100);
        QString security = fields.at(3).trimmed();
        if (security.isEmpty() || security == QLatin1String("--")) {
            security = QStringLiteral("OPEN");
        }

        auto it = networks.find(ssid);
        if (it == networks.end() || active || signal > it->signal) {
            networks.insert(ssid, Network{ssid, security, signal, active});
        }
    }

    QList<Network> sorted = networks.values();
    std::sort(sorted.begin(), sorted.end(), [](const Network &a, const Network &b) {
        if (a.active != b.active) {
            return a.active;
        }
        if (a.signal != b.signal) {
            return a.signal > b.signal;
        }
        return a.ssid.localeAwareCompare(b.ssid) < 0;
    });

    QVariantList list;
    for (const Network &network : sorted) {
        QVariantMap entry;
        entry.insert(QStringLiteral("ssid"), network.ssid);
        entry.insert(QStringLiteral("security"), network.security);
        entry.insert(QStringLiteral("secure"), network.security != QLatin1String("OPEN"));
        entry.insert(QStringLiteral("signal"), network.signal);
        entry.insert(QStringLiteral("active"), network.active);
        list.append(entry);

        if (network.active) {
            m_wifiConnected = true;
            if (m_wifiSsid != network.ssid) {
                m_wifiSsid = network.ssid;
            }
            if (m_wifiSignal != network.signal) {
                m_wifiSignal = network.signal;
            }
        }
    }

    if (!list.isEmpty()) {
        if (m_wifiSsid.isEmpty() || replaceNetworks) {
            m_wifiSsid = sorted.first().ssid;
        }
    }

    if (replaceNetworks || m_wifiNetworks.isEmpty()) {
        m_wifiNetworks = list;
        Q_EMIT wifiNetworksChanged();
    }
    Q_EMIT wifiChanged();
}

void SystemService::parseRadio(const QString &output)
{
    const QString state = output.trimmed();
    const bool enabled = !state.contains(QLatin1String("disabled")) && !state.contains(QLatin1String("unavailable"));
    if (enabled != m_wifiEnabled) {
        m_wifiEnabled = enabled;
        Q_EMIT wifiChanged();
    }
}

void SystemService::refreshNetworks()
{
    if (!m_wifiAvailable || m_scanRunning) {
        return;
    }
    m_scanRunning = true;
    if (!m_scanning) {
        m_scanning = true;
        Q_EMIT scanningChanged();
    }

    run(QStringLiteral("nmcli"), {QStringLiteral("-t"), QStringLiteral("radio"), QStringLiteral("wifi")},
        [this](int code, const QString &out, const QString &) {
            if (code == 0) {
                parseRadio(out);
            }
        });
    run(QStringLiteral("nmcli"),
        {QStringLiteral("-t"), QStringLiteral("-f"), QStringLiteral("IN-USE,SSID,SIGNAL,SECURITY"), QStringLiteral("device"), QStringLiteral("wifi"), QStringLiteral("list"), QStringLiteral("--rescan"), QStringLiteral("yes")},
        [this](int code, const QString &out, const QString &err) {
            if (code == 0) {
                parseWifiList(out, true);
            } else {
                Q_EMIT networkResult(false, err.trimmed().isEmpty() ? QStringLiteral("Wi-Fi 扫描失败") : err.trimmed());
            }
            m_scanRunning = false;
            if (m_scanning) {
                m_scanning = false;
                Q_EMIT scanningChanged();
            }
        });
}

void SystemService::connectWifi(const QString &ssid, const QString &password)
{
    if (ssid.isEmpty() || m_connecting) {
        return;
    }
    m_connecting = true;
    Q_EMIT connectingChanged();

    QStringList args{QStringLiteral("--wait"), QStringLiteral("30"), QStringLiteral("device"), QStringLiteral("wifi"), QStringLiteral("connect"), ssid};
    if (!password.isEmpty()) {
        args << QStringLiteral("password") << password;
    }

    run(QStringLiteral("nmcli"), args, [this, ssid](int code, const QString &, const QString &err) {
        m_connecting = false;
        Q_EMIT connectingChanged();
        const bool ok = code == 0;
        QString message;
        if (ok) {
            message = QStringLiteral("已连接到 %1").arg(ssid);
        } else {
            message = err.trimmed();
            if (message.isEmpty()) {
                message = QStringLiteral("连接失败");
            }
        }
        Q_EMIT networkResult(ok, message);
        QTimer::singleShot(400, this, [this] {
            refreshNetworks();
            pollNetwork();
        });
    });
}

void SystemService::disconnectWifi()
{
    if (m_wifiIface.isEmpty()) {
        Q_EMIT networkResult(false, QStringLiteral("没有可断开的 Wi-Fi 设备"));
        return;
    }
    run(QStringLiteral("nmcli"), {QStringLiteral("device"), QStringLiteral("disconnect"), m_wifiIface},
        [this](int code, const QString &, const QString &err) {
            Q_EMIT networkResult(code == 0, code == 0 ? QStringLiteral("Wi-Fi 已断开") : err.trimmed());
            QTimer::singleShot(300, this, &SystemService::pollNetwork);
        });
}

void SystemService::setWifiEnabled(bool enabled)
{
    run(QStringLiteral("nmcli"), {QStringLiteral("radio"), QStringLiteral("wifi"), enabled ? QStringLiteral("on") : QStringLiteral("off")},
        [this, enabled](int code, const QString &, const QString &err) {
            if (code == 0) {
                m_wifiEnabled = enabled;
                Q_EMIT wifiChanged();
                Q_EMIT networkResult(true, enabled ? QStringLiteral("Wi-Fi 已开启") : QStringLiteral("Wi-Fi 已关闭"));
                QTimer::singleShot(400, this, &SystemService::refreshNetworks);
            } else {
                Q_EMIT networkResult(false, err.trimmed());
            }
        });
}

void SystemService::pollBattery()
{
    bool present = false;
    int percent = 0;
    QString status;
    QString path;
    QString time;
    bool charging = false;
    bool onAc = false;
    int health = 0;

    const QDir powerSupply(QStringLiteral("/sys/class/power_supply"));
    const QStringList entries = powerSupply.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &entry : entries) {
        const QString base = powerSupply.filePath(entry);
        const QString type = readTextFile(base + QStringLiteral("/type"));
        if (type == QLatin1String("Battery") && readTextFile(base + QStringLiteral("/capacity")).toInt() > 0) {
            present = true;
            path = base;
            percent = qBound(0, readIntFile(base + QStringLiteral("/capacity")), 100);
            status = readTextFile(base + QStringLiteral("/status"));
            charging = status.compare(QLatin1String("Charging"), Qt::CaseInsensitive) == 0;

            qint64 energyNow = readNumberFile(base + QStringLiteral("/energy_now"));
            qint64 energyFull = readNumberFile(base + QStringLiteral("/energy_full"));
            qint64 powerNow = readNumberFile(base + QStringLiteral("/power_now"));
            if (energyNow == 0) {
                energyNow = readNumberFile(base + QStringLiteral("/charge_now"));
                energyFull = readNumberFile(base + QStringLiteral("/charge_full"));
                powerNow = readNumberFile(base + QStringLiteral("/current_now"));
            }
            const bool discharging = status.compare(QLatin1String("Discharging"), Qt::CaseInsensitive) == 0;
            if (powerNow > 0 && energyNow > 0 && (charging || discharging)) {
                const qint64 remaining = charging ? qMax<qint64>(0, energyFull - energyNow) : energyNow;
                const double hours = static_cast<double>(remaining) / static_cast<double>(powerNow);
                const int totalMinutes = qRound(hours * 60.0);
                if (totalMinutes >= 0 && totalMinutes < 100 * 60) {
                    time = QStringLiteral("%1H %2M").arg(totalMinutes / 60).arg(totalMinutes % 60, 2, 10, QLatin1Char('0'));
                }
            }

            const qint64 design = readNumberFile(base + QStringLiteral("/energy_full_design"));
            if (design > 0 && energyFull > 0) {
                health = qBound(0, qRound(100.0 * static_cast<double>(energyFull) / static_cast<double>(design)), 100);
            } else {
                health = 100;
            }
        } else if (type == QLatin1String("Mains") || entry.startsWith(QLatin1String("AC"))) {
            if (readIntFile(base + QStringLiteral("/online")) == 1) {
                onAc = true;
            }
        }
    }

    const bool presentChanged = present != m_batteryPresent;
    m_batteryPresent = present;
    m_batteryPercent = percent;
    m_batteryStatus = status;
    m_batteryPath = path;
    m_batteryTime = time;
    m_charging = charging;
    m_onAc = onAc;
    m_batteryHealth = health;

    if (presentChanged || present) {
        Q_EMIT batteryChanged();
    }
}

void SystemService::refreshPowerProfile()
{
    if (!m_powerProfileAvailable || m_profileQueryRunning) {
        return;
    }
    m_profileQueryRunning = true;
    run(QStringLiteral("powerprofilesctl"), {QStringLiteral("list")},
        [this](int code, const QString &out, const QString &) {
            QStringList available;
            QString active;
            if (code == 0) {
                static const QRegularExpression linePattern(
                    QStringLiteral("^\\s*(\\*)?\\s*(power-saver|balanced|performance):"));
                const QStringList lines = out.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
                for (const QString &line : lines) {
                    const QRegularExpressionMatch match = linePattern.match(line);
                    if (!match.hasMatch()) {
                        continue;
                    }
                    const QString id = match.captured(2);
                    if (!available.contains(id)) {
                        available.append(id);
                    }
                    if (!match.captured(1).isEmpty()) {
                        active = id;
                    }
                }
            }

            const QStringList fixedOrder{QStringLiteral("power-saver"), QStringLiteral("balanced"), QStringLiteral("performance")};
            QVariantList profiles;
            for (const QString &id : fixedOrder) {
                if (!available.isEmpty() && !available.contains(id)) {
                    continue;
                }
                QVariantMap entry;
                entry.insert(QStringLiteral("id"), id);
                entry.insert(QStringLiteral("label"), powerProfileLabel(id));
                entry.insert(QStringLiteral("active"), id == active);
                profiles.append(entry);
            }
            m_powerProfiles = profiles;
            if (!active.isEmpty() && active != m_powerProfile) {
                m_powerProfile = active;
                Q_EMIT powerProfileChanged();
            }
            Q_EMIT powerProfilesChanged();
            m_profileQueryRunning = false;
        });
}

void SystemService::setPowerProfile(const QString &profile)
{
    if (!m_powerProfileAvailable || profile.isEmpty()) {
        return;
    }
    run(QStringLiteral("powerprofilesctl"), {QStringLiteral("set"), profile},
        [this, profile](int code, const QString &, const QString &err) {
            if (code == 0) {
                m_powerProfile = profile;
                Q_EMIT powerProfileChanged();
                Q_EMIT powerProfileResult(true, QStringLiteral("电源模式：%1").arg(powerProfileLabel(profile)));
                refreshPowerProfile();
            } else {
                Q_EMIT powerProfileResult(false, err.trimmed().isEmpty() ? QStringLiteral("无法切换电源模式") : err.trimmed());
            }
        });
}

void SystemService::refreshAudioSinks()
{
    if (m_sinkQueryRunning || QStandardPaths::findExecutable(QStringLiteral("pactl")).isEmpty()) {
        return;
    }
    m_sinkQueryRunning = true;

    run(QStringLiteral("pactl"), {QStringLiteral("-f"), QStringLiteral("json"), QStringLiteral("list"), QStringLiteral("sinks")},
        [this](int code, const QString &out, const QString &) {
            QVariantList sinks;
            if (code == 0) {
                const QJsonDocument document = QJsonDocument::fromJson(out.toUtf8());
                const QJsonArray array = document.array();
                for (const QJsonValue &value : array) {
                    const QJsonObject object = value.toObject();
                    const QString name = object.value(QStringLiteral("name")).toString();
                    if (name.isEmpty()) {
                        continue;
                    }
                    const QJsonObject properties = object.value(QStringLiteral("properties")).toObject();
                    QString label = properties.value(QStringLiteral("device.profile.description")).toString();
                    if (label.isEmpty()) {
                        label = properties.value(QStringLiteral("node.nick")).toString();
                    }
                    if (label.isEmpty()) {
                        label = object.value(QStringLiteral("description")).toString(name);
                    }

                    QVariantMap entry;
                    entry.insert(QStringLiteral("id"), name);
                    entry.insert(QStringLiteral("name"), label);
                    entry.insert(QStringLiteral("active"), false);
                    entry.insert(QStringLiteral("icon"),
                                 properties.value(QStringLiteral("device.icon_name")).toString());
                    sinks.append(entry);
                }
            }

            run(QStringLiteral("pactl"), {QStringLiteral("get-default-sink")},
                [this, sinks](int sinkCode, const QString &sinkOut, const QString &) mutable {
                    const QString defaultSink = sinkOut.trimmed();
                    QString description;
                    for (int i = 0; i < sinks.size(); ++i) {
                        QVariantMap entry = sinks.at(i).toMap();
                        const bool active = sinkCode == 0 && entry.value(QStringLiteral("id")).toString() == defaultSink;
                        entry.insert(QStringLiteral("active"), active);
                        if (active) {
                            description = entry.value(QStringLiteral("name")).toString();
                        } else if (description.isEmpty() && sinkCode != 0) {
                            description = entry.value(QStringLiteral("name")).toString();
                        }
                        sinks[i] = entry;
                    }

                    std::sort(sinks.begin(), sinks.end(), [](const QVariant &a, const QVariant &b) {
                        const bool aActive = a.toMap().value(QStringLiteral("active")).toBool();
                        const bool bActive = b.toMap().value(QStringLiteral("active")).toBool();
                        if (aActive != bActive) {
                            return aActive;
                        }
                        return a.toMap().value(QStringLiteral("name")).toString()
                            .localeAwareCompare(b.toMap().value(QStringLiteral("name")).toString()) < 0;
                    });

                    m_audioSinks = sinks;
                    if (!defaultSink.isEmpty()) {
                        m_audioSinkName = defaultSink;
                        if (description.isEmpty()) {
                            description = defaultSink;
                        }
                        m_audioSinkDescription = description;
                    }
                    Q_EMIT audioSinksChanged();
                    Q_EMIT audioSinkChanged();
                    m_sinkQueryRunning = false;
                });
        });
}

void SystemService::setAudioSink(const QString &sinkName)
{
    if (sinkName.isEmpty()) {
        return;
    }
    run(QStringLiteral("pactl"), {QStringLiteral("set-default-sink"), sinkName},
        [this, sinkName](int code, const QString &, const QString &err) {
            if (code != 0) {
                Q_EMIT audioResult(false, err.trimmed().isEmpty() ? QStringLiteral("无法切换输出设备") : err.trimmed());
                return;
            }
            m_audioSinkName = sinkName;
            Q_EMIT audioResult(true, QStringLiteral("输出设备已切换"));

            // Move already-playing streams as well, not just the default for new
            // streams. This mirrors what users expect from a KDE device picker.
            run(QStringLiteral("pactl"),
                {QStringLiteral("list"), QStringLiteral("short"), QStringLiteral("sink-inputs")},
                [this, sinkName](int listCode, const QString &out, const QString &) {
                    if (listCode == 0) {
                        const QStringList lines = out.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
                        for (const QString &line : lines) {
                            const QStringList fields = line.split(QLatin1Char('\t'));
                            if (fields.isEmpty() || fields.first().isEmpty()) {
                                continue;
                            }
                            run(QStringLiteral("pactl"),
                                {QStringLiteral("move-sink-input"), fields.first(), sinkName},
                                [](int, const QString &, const QString &) {});
                        }
                    }
                    QTimer::singleShot(150, this, [this] { pollAudio(); refreshAudioSinks(); });
                });
        });
}

bool SystemService::powerAction(const QString &action)
{
    if (action == QLatin1String("sleep")) {
        callSystem(QStringLiteral("org.freedesktop.login1"),
                   QStringLiteral("/org/freedesktop/login1"),
                   QStringLiteral("org.freedesktop.login1.Manager"),
                   QStringLiteral("Suspend"),
                   {false});
        Q_EMIT powerResult(true, QStringLiteral("进入睡眠"));
        return true;
    }

    if (action == QLatin1String("lock")) {
        QProcess::startDetached(QStringLiteral("loginctl"), {QStringLiteral("lock-session")});
        Q_EMIT powerResult(true, QStringLiteral("已锁定屏幕"));
        return true;
    }

    const bool kdeShutdown = serviceRegistered(QStringLiteral("org.kde.Shutdown"));
    if (action == QLatin1String("logout")) {
        if (kdeShutdown) {
            callSession(QStringLiteral("org.kde.Shutdown"), QStringLiteral("/Shutdown"), QStringLiteral("org.kde.Shutdown"), QStringLiteral("logout"));
        } else {
            QProcess::startDetached(QStringLiteral("loginctl"), {QStringLiteral("terminate-user"), userName()});
        }
        Q_EMIT powerResult(true, QStringLiteral("正在注销"));
        return true;
    }

    if (action == QLatin1String("reboot")) {
        if (kdeShutdown) {
            callSession(QStringLiteral("org.kde.Shutdown"), QStringLiteral("/Shutdown"), QStringLiteral("org.kde.Shutdown"), QStringLiteral("logoutAndReboot"));
        } else {
            callSystem(QStringLiteral("org.freedesktop.login1"),
                       QStringLiteral("/org/freedesktop/login1"),
                       QStringLiteral("org.freedesktop.login1.Manager"),
                       QStringLiteral("Reboot"),
                       {false});
        }
        Q_EMIT powerResult(true, QStringLiteral("正在重启"));
        return true;
    }

    if (action == QLatin1String("shutdown")) {
        if (kdeShutdown) {
            callSession(QStringLiteral("org.kde.Shutdown"), QStringLiteral("/Shutdown"), QStringLiteral("org.kde.Shutdown"), QStringLiteral("logoutAndShutdown"));
        } else {
            callSystem(QStringLiteral("org.freedesktop.login1"),
                       QStringLiteral("/org/freedesktop/login1"),
                       QStringLiteral("org.freedesktop.login1.Manager"),
                       QStringLiteral("PowerOff"),
                       {false});
        }
        Q_EMIT powerResult(true, QStringLiteral("正在关机"));
        return true;
    }

    return false;
}
