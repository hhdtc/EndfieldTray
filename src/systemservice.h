#pragma once

#include <QObject>
#include <QProcess>
#include <QTimer>
#include <QVariantList>

#include <functional>

class QProcess;

/**
 * System integration that intentionally stays outside the compositor's
 * private APIs: PipeWire via wpctl, NetworkManager via nmcli, power via
 * logind / org.kde.Shutdown and battery via sysfs.
 */
class SystemService : public QObject
{
    Q_OBJECT

    Q_PROPERTY(int volume READ volume NOTIFY volumeChanged)
    Q_PROPERTY(bool muted READ muted NOTIFY mutedChanged)
    Q_PROPERTY(QString audioBackend READ audioBackend NOTIFY audioBackendChanged)

    Q_PROPERTY(bool wifiAvailable READ wifiAvailable CONSTANT)
    Q_PROPERTY(bool wifiEnabled READ wifiEnabled NOTIFY wifiChanged)
    Q_PROPERTY(bool wifiConnected READ wifiConnected NOTIFY wifiChanged)
    Q_PROPERTY(QString wifiSsid READ wifiSsid NOTIFY wifiChanged)
    Q_PROPERTY(int wifiSignal READ wifiSignal NOTIFY wifiChanged)
    Q_PROPERTY(bool scanning READ scanning NOTIFY scanningChanged)
    Q_PROPERTY(bool connecting READ connecting NOTIFY connectingChanged)
    Q_PROPERTY(QVariantList wifiNetworks READ wifiNetworks NOTIFY wifiNetworksChanged)

    Q_PROPERTY(bool batteryPresent READ batteryPresent NOTIFY batteryChanged)
    Q_PROPERTY(int batteryPercent READ batteryPercent NOTIFY batteryChanged)
    Q_PROPERTY(QString batteryStatus READ batteryStatus NOTIFY batteryChanged)
    Q_PROPERTY(QString batteryTime READ batteryTime NOTIFY batteryChanged)
    Q_PROPERTY(bool charging READ charging NOTIFY batteryChanged)
    Q_PROPERTY(bool onAc READ onAc NOTIFY batteryChanged)
    Q_PROPERTY(int batteryHealth READ batteryHealth NOTIFY batteryChanged)

    Q_PROPERTY(QString userName READ userName CONSTANT)
    Q_PROPERTY(QString hostName READ hostName CONSTANT)

    Q_PROPERTY(bool powerProfileAvailable READ powerProfileAvailable NOTIFY powerProfilesChanged)
    Q_PROPERTY(QString powerProfile READ powerProfile NOTIFY powerProfileChanged)
    Q_PROPERTY(QVariantList powerProfiles READ powerProfiles NOTIFY powerProfilesChanged)

    Q_PROPERTY(QVariantList audioSinks READ audioSinks NOTIFY audioSinksChanged)
    Q_PROPERTY(QString audioSinkName READ audioSinkName NOTIFY audioSinkChanged)
    Q_PROPERTY(QString audioSinkDescription READ audioSinkDescription NOTIFY audioSinkChanged)

public:
    explicit SystemService(QObject *parent = nullptr);

    int volume() const { return m_volume; }
    bool muted() const { return m_muted; }
    QString audioBackend() const { return m_audioBackend; }

    bool wifiAvailable() const { return m_wifiAvailable; }
    bool wifiEnabled() const { return m_wifiEnabled; }
    bool wifiConnected() const { return m_wifiConnected; }
    QString wifiSsid() const { return m_wifiSsid; }
    int wifiSignal() const { return m_wifiSignal; }
    bool scanning() const { return m_scanning; }
    bool connecting() const { return m_connecting; }
    QVariantList wifiNetworks() const { return m_wifiNetworks; }

    bool batteryPresent() const { return m_batteryPresent; }
    int batteryPercent() const { return m_batteryPercent; }
    QString batteryStatus() const { return m_batteryStatus; }
    QString batteryTime() const { return m_batteryTime; }
    bool charging() const { return m_charging; }
    bool onAc() const { return m_onAc; }
    int batteryHealth() const { return m_batteryHealth; }

    QString userName() const;
    QString hostName() const;

    bool powerProfileAvailable() const { return m_powerProfileAvailable; }
    QString powerProfile() const { return m_powerProfile; }
    QVariantList powerProfiles() const { return m_powerProfiles; }
    QVariantList audioSinks() const { return m_audioSinks; }
    QString audioSinkName() const { return m_audioSinkName; }
    QString audioSinkDescription() const { return m_audioSinkDescription; }

    Q_INVOKABLE void refreshAll();
    Q_INVOKABLE void setUiActive(bool active);
    Q_INVOKABLE void refreshNetworks();
    Q_INVOKABLE void refreshPowerProfile();
    Q_INVOKABLE void setPowerProfile(const QString &profile);
    Q_INVOKABLE void refreshAudioSinks();
    Q_INVOKABLE void setAudioSink(const QString &sinkName);

    Q_INVOKABLE void setVolume(int percent);
    Q_INVOKABLE void adjustVolume(int delta);
    Q_INVOKABLE void toggleMute();

    Q_INVOKABLE void connectWifi(const QString &ssid, const QString &password);
    Q_INVOKABLE void disconnectWifi();
    Q_INVOKABLE void setWifiEnabled(bool enabled);

    Q_INVOKABLE bool powerAction(const QString &action);

Q_SIGNALS:
    void volumeChanged();
    void mutedChanged();
    void audioBackendChanged();
    void wifiChanged();
    void scanningChanged();
    void connectingChanged();
    void wifiNetworksChanged();
    void batteryChanged();
    void networkResult(bool ok, const QString &message);
    void powerResult(bool ok, const QString &message);
    void powerProfilesChanged();
    void powerProfileChanged();
    void audioSinksChanged();
    void audioSinkChanged();
    void powerProfileResult(bool ok, const QString &message);
    void audioResult(bool ok, const QString &message);

private:
    void pollAudio();
    void pollNetwork();
    void pollBattery();
    void applyVolume();
    void run(const QString &program,
             const QStringList &arguments,
             std::function<void(int, const QString &, const QString &)> callback);
    void parseDeviceStatus(const QString &output);
    void parseWifiList(const QString &output, bool replaceNetworks);
    void parseRadio(const QString &output);

    QTimer m_audioTimer;
    QTimer m_netTimer;
    QTimer m_batteryTimer;
    bool m_uiActive = false;
    bool m_uiInitialized = false;
    QTimer m_volumeApplyTimer;
    QProcess *m_audioProcess = nullptr;
    QProcess *m_netProcess = nullptr;
    bool m_netPollRunning = false;
    bool m_scanRunning = false;

    int m_volume = 0;
    bool m_muted = false;
    int m_pendingVolume = -1;
    QString m_audioBackend = QStringLiteral("PIPEWIRE");

    bool m_wifiAvailable = false;
    bool m_wifiEnabled = true;
    bool m_wifiConnected = false;
    QString m_wifiSsid;
    QString m_wifiIface;
    int m_wifiSignal = 0;
    bool m_scanning = false;
    bool m_connecting = false;
    QVariantList m_wifiNetworks;

    bool m_powerProfileAvailable = false;
    QString m_powerProfile;
    QVariantList m_powerProfiles;
    bool m_profileQueryRunning = false;

    QVariantList m_audioSinks;
    QString m_audioSinkName;
    QString m_audioSinkDescription;
    bool m_sinkQueryRunning = false;

    bool m_batteryPresent = false;
    int m_batteryPercent = 0;
    QString m_batteryStatus;
    QString m_batteryPath;
    QString m_batteryTime;
    bool m_charging = false;
    bool m_onAc = false;
    int m_batteryHealth = 0;
};
