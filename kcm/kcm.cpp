#include "kcm.h"
#include <QFileInfo>
#include <QDir>

KCMNetworkmanagement::KCMNetworkmanagement(QObject *parent, const KPluginMetaData &metaData)
    : KQuickConfigModule(parent, metaData)
{
    setButtons({});

    m_scriptPath = findScriptPath();

    m_pollTimer = new QTimer(this);
    m_pollTimer->setInterval(2000);
    connect(m_pollTimer, &QTimer::timeout, this, &KCMNetworkmanagement::refreshStatus);
    m_pollTimer->start();

    refreshStatus();
}

KCMNetworkmanagement::~KCMNetworkmanagement()
{
}

QString KCMNetworkmanagement::findScriptPath() const
{
    QString path = QStandardPaths::locate(QStandardPaths::GenericDataLocation,
        QStringLiteral("plasma/plasmoids/org.kde.plasma.networkmanagement/contents/scripts/backend.py"));
    if (!path.isEmpty() && QFileInfo::exists(path)) {
        return path;
    }
    const QString devPath = QDir::homePath() + QStringLiteral("/Projects/plasma-networkd/package/contents/scripts/backend.py");
    if (QFileInfo::exists(devPath)) {
        return devPath;
    }
    return QStringLiteral("/usr/share/plasma/plasmoids/org.kde.plasma.networkmanagement/contents/scripts/backend.py");
}

void KCMNetworkmanagement::runBackendAsync(const QStringList &args, std::function<void(const QByteArray &, int)> callback)
{
    if (m_scriptPath.isEmpty()) {
        m_scriptPath = findScriptPath();
    }

    QProcess *proc = new QProcess(this);
    QStringList cmdArgs;
    cmdArgs << m_scriptPath << args;

    connect(proc, &QProcess::finished, this, [proc, callback](int exitCode, QProcess::ExitStatus) {
        QByteArray out = proc->readAllStandardOutput();
        callback(out, exitCode);
        proc->deleteLater();
    });

    proc->start(QStringLiteral("python3"), cmdArgs);
}

void KCMNetworkmanagement::refreshStatus()
{
    runBackendAsync({QStringLiteral("status")}, [this](const QByteArray &out, int exitCode) {
        if (exitCode != 0) return;
        QJsonDocument doc = QJsonDocument::fromJson(out);
        if (!doc.isObject()) return;

        QJsonObject rootObj = doc.object();
        qint64 now = QDateTime::currentMSecsSinceEpoch();

        if (rootObj.contains(QLatin1String("links")) && rootObj[QLatin1String("links")].isArray()) {
            QJsonArray links = rootObj[QLatin1String("links")].toArray();
            QJsonArray updatedLinks;

            for (const QJsonValue &val : links) {
                QJsonObject l = val.toObject();
                QString name = l[QLatin1String("name")].toString();
                qint64 rx = l[QLatin1String("rx_bytes")].toVariant().toLongLong();
                qint64 tx = l[QLatin1String("tx_bytes")].toVariant().toLongLong();

                double rxSpeed = 0;
                double txSpeed = 0;

                if (m_trafficStats.contains(name)) {
                    const LinkTraffic &prev = m_trafficStats[name];
                    double dt = (now - prev.timestampMs) / 1000.0;
                    if (dt > 0.4 && rx >= prev.rxBytes && tx >= prev.txBytes) {
                        rxSpeed = (rx - prev.rxBytes) / dt;
                        txSpeed = (tx - prev.txBytes) / dt;
                    } else {
                        rxSpeed = prev.rxSpeed;
                        txSpeed = prev.txSpeed;
                    }
                }

                LinkTraffic stats;
                stats.rxBytes = rx;
                stats.txBytes = tx;
                stats.timestampMs = now;
                stats.rxSpeed = rxSpeed;
                stats.txSpeed = txSpeed;
                m_trafficStats[name] = stats;

                l[QLatin1String("rx_speed")] = rxSpeed;
                l[QLatin1String("tx_speed")] = txSpeed;
                updatedLinks.append(l);
            }
            rootObj[QLatin1String("links")] = updatedLinks;
        }

        m_backendData = rootObj;
        Q_EMIT backendDataChanged();
    });
}

void KCMNetworkmanagement::scanWifi()
{
    m_isScanning = true;
    Q_EMIT isScanningChanged();

    runBackendAsync({QStringLiteral("wifi_scan")}, [this](const QByteArray &out, int) {
        m_isScanning = false;
        Q_EMIT isScanningChanged();

        QJsonDocument doc = QJsonDocument::fromJson(out);
        if (doc.isObject()) {
            QJsonObject obj = doc.object();
            if (obj[QLatin1String("success")].toBool()) {
                m_wifiNetworks = obj[QLatin1String("networks")].toArray();
                Q_EMIT wifiNetworksChanged();
            } else {
                m_bannerMessage = obj[QLatin1String("error")].toString();
                m_bannerIsError = true;
                Q_EMIT bannerMessageChanged();
                Q_EMIT bannerIsErrorChanged();
            }
        }
    });
}

void KCMNetworkmanagement::connectWifi(const QString &ssid, const QString &password)
{
    m_bannerMessage = QStringLiteral("Connecting to ") + ssid + QStringLiteral("…");
    m_bannerIsError = false;
    Q_EMIT bannerMessageChanged();
    Q_EMIT bannerIsErrorChanged();

    runBackendAsync({QStringLiteral("wifi_connect"), ssid, password}, [this](const QByteArray &out, int) {
        QJsonDocument doc = QJsonDocument::fromJson(out);
        if (doc.isObject()) {
            QJsonObject obj = doc.object();
            m_bannerMessage = obj[QLatin1String("message")].toString(obj[QLatin1String("error")].toString());
            m_bannerIsError = !obj[QLatin1String("success")].toBool();
            Q_EMIT bannerMessageChanged();
            Q_EMIT bannerIsErrorChanged();
        }
        refreshStatus();
    });
}

void KCMNetworkmanagement::disconnectWifi()
{
    runBackendAsync({QStringLiteral("wifi_disconnect")}, [this](const QByteArray &, int) {
        refreshStatus();
    });
}

void KCMNetworkmanagement::executeLinkAction(const QString &action, const QString &linkName)
{
    runBackendAsync({QStringLiteral("link_action"), action, linkName}, [this](const QByteArray &, int) {
        refreshStatus();
    });
}

void KCMNetworkmanagement::flushDns()
{
    m_bannerMessage = QStringLiteral("Flushing DNS resolver cache…");
    m_bannerIsError = false;
    Q_EMIT bannerMessageChanged();
    Q_EMIT bannerIsErrorChanged();

    runBackendAsync({QStringLiteral("flush_dns")}, [this](const QByteArray &out, int) {
        QJsonDocument doc = QJsonDocument::fromJson(out);
        if (doc.isObject()) {
            QJsonObject obj = doc.object();
            m_bannerMessage = obj[QLatin1String("message")].toString(obj[QLatin1String("error")].toString());
            m_bannerIsError = !obj[QLatin1String("success")].toBool();
            Q_EMIT bannerMessageChanged();
            Q_EMIT bannerIsErrorChanged();
        }
    });
}

K_PLUGIN_CLASS_WITH_JSON(KCMNetworkmanagement, "kcm_networkmanagement.json")
#include "moc_kcm_h.cpp"
#include "moc_kcm_cpp.cpp"
