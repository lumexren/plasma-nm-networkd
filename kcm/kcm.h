#pragma once

#include <KQuickConfigModule>
#include <KPluginFactory>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonDocument>
#include <QProcess>
#include <QTimer>
#include <QStandardPaths>
#include <QDateTime>
#include <functional>

class KCMNetworkmanagement : public KQuickConfigModule
{
    Q_OBJECT
    Q_PROPERTY(QJsonObject backendData READ backendData NOTIFY backendDataChanged)
    Q_PROPERTY(QJsonArray wifiNetworks READ wifiNetworks NOTIFY wifiNetworksChanged)
    Q_PROPERTY(bool isScanning READ isScanning NOTIFY isScanningChanged)
    Q_PROPERTY(QString bannerMessage READ bannerMessage NOTIFY bannerMessageChanged)
    Q_PROPERTY(bool bannerIsError READ bannerIsError NOTIFY bannerIsErrorChanged)

public:
    explicit KCMNetworkmanagement(QObject *parent, const KPluginMetaData &metaData);
    ~KCMNetworkmanagement() override;

    QJsonObject backendData() const { return m_backendData; }
    QJsonArray wifiNetworks() const { return m_wifiNetworks; }
    bool isScanning() const { return m_isScanning; }
    QString bannerMessage() const { return m_bannerMessage; }
    bool bannerIsError() const { return m_bannerIsError; }

    Q_INVOKABLE void refreshStatus();
    Q_INVOKABLE void scanWifi();
    Q_INVOKABLE void connectWifi(const QString &ssid, const QString &password);
    Q_INVOKABLE void disconnectWifi();
    Q_INVOKABLE void executeLinkAction(const QString &action, const QString &linkName);
    Q_INVOKABLE void flushDns();

signals:
    void backendDataChanged();
    void wifiNetworksChanged();
    void isScanningChanged();
    void bannerMessageChanged();
    void bannerIsErrorChanged();

private:
    void runBackendAsync(const QStringList &args, std::function<void(const QByteArray &stdoutData, int exitCode)> callback);
    QString findScriptPath() const;

    QString m_scriptPath;
    QJsonObject m_backendData;
    QJsonArray m_wifiNetworks;
    bool m_isScanning = false;
    QString m_bannerMessage;
    bool m_bannerIsError = false;
    QTimer *m_pollTimer;

    struct LinkTraffic {
        qint64 rxBytes = 0;
        qint64 txBytes = 0;
        qint64 timestampMs = 0;
        double rxSpeed = 0;
        double txSpeed = 0;
    };
    QHash<QString, LinkTraffic> m_trafficStats;
};
