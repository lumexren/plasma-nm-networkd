import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    preferredRepresentation: compactRepresentation
    compactRepresentation: CompactRepresentation {
        rootItem: root
    }
    fullRepresentation: FullRepresentation {
        rootItem: root
    }

    property var backendData: ({
        online: false,
        active_link: "",
        systemd_networkd: { active: false, operational_state: "unknown" },
        links: [],
        wifi: { available: false, interfaces: [] }
    })

    toolTipMainText: backendData.online ? ((backendData.active_link || "Ağ") + " Bağlı") : "Ağ Bağlantısı Yok"
    toolTipSubText: {
        if (!backendData.online) return "systemd-networkd çalışıyor, ancak internet erişimi yok.";
        let txt = "";
        const links = backendData.links || [];
        for (let i = 0; i < links.length; i++) {
            if (links[i].name === backendData.active_link) {
                if (links[i].ipv4 && links[i].ipv4.length > 0) {
                    txt += "IP: " + links[i].ipv4[0] + "\n";
                }
                if (links[i].gateway) {
                    txt += "Ağ Geçidi: " + links[i].gateway;
                }
                break;
            }
        }
        return txt;
    }

    property var wifiNetworks: []
    property bool isScanningWifi: false
    property string actionMessage: ""
    property bool actionIsError: false

    readonly property string backendScriptPath: {
        const u = Qt.resolvedUrl("../scripts/backend.py").toString();
        return u.replace(/^file:\/\//, "");
    }

    // Command runner DataSource
    Plasma5Support.DataSource {
        id: execSource
        engine: "executable"
        connectedSources: []

        onNewData: (sourceName, data) => {
            const exitCode = data["exit code"];
            const stdout = data["stdout"] || "";
            const stderr = data["stderr"] || "";

            // Disconnect source after receiving single execution data
            disconnectSource(sourceName);

            // Handle periodic status check
            if (sourceName.indexOf("status") !== -1) {
                try {
                    root.backendData = JSON.parse(stdout);
                } catch (e) {
                    console.warn("plasma-networkd JSON parse error:", e);
                }
                return;
            }

            // Handle Wi-Fi scan
            if (sourceName.indexOf("wifi_scan") !== -1) {
                root.isScanningWifi = false;
                try {
                    const res = JSON.parse(stdout);
                    if (res.success && res.networks) {
                        root.wifiNetworks = res.networks;
                    } else if (res.error) {
                        root.showBanner("Wi-Fi tarama hatası: " + res.error, true);
                    }
                } catch (e) {
                    root.showBanner("Wi-Fi sonucu okunamadı", true);
                }
                return;
            }

            // Handle other actions
            try {
                const res = JSON.parse(stdout);
                if (res.success) {
                    root.showBanner(res.message || res.output || "İşlem başarıyla tamamlandı", false);
                } else {
                    root.showBanner(res.error || stderr || "İşlem başarısız oldu", true);
                }
            } catch (e) {
                if (exitCode === 0) {
                    root.showBanner(stdout || "İşlem tamamlandı", false);
                } else {
                    root.showBanner(stderr || "Hata oluştu", true);
                }
            }

            // Refresh status after an action
            root.refreshStatus();
        }
    }

    Timer {
        id: pollTimer
        interval: 3500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshStatus()
    }

    function showBanner(msg, isErr) {
        root.actionMessage = msg;
        root.actionIsError = isErr;
    }

    function runBackendCmd(args) {
        const cmd = "python3 " + root.backendScriptPath + " " + args;
        execSource.connectSource(cmd);
    }

    function refreshStatus() {
        runBackendCmd("status");
    }

    function scanWifi() {
        root.isScanningWifi = true;
        runBackendCmd("wifi_scan");
    }

    function connectWifi(ssid, password) {
        showBanner("'" + ssid + "' ağına bağlanılıyor...", false);
        const passEscaped = password ? ("'" + password.replace(/'/g, "'\\''") + "'") : "''";
        const ssidEscaped = "'" + ssid.replace(/'/g, "'\\''") + "'";
        runBackendCmd("wifi_connect " + ssidEscaped + " " + passEscaped);
    }

    function disconnectWifi() {
        showBanner("Wi-Fi bağlantısı kesiliyor...", false);
        runBackendCmd("wifi_disconnect");
    }

    function executeLinkAction(action, linkName) {
        showBanner(linkName + " üzerinde " + action + " işlemi yapılıyor...", false);
        runBackendCmd("link_action " + action + " " + linkName);
    }

    function executeServiceAction(action) {
        showBanner("systemd-networkd " + action + " çalıştırılıyor...", false);
        runBackendCmd("service_action " + action);
    }

    function flushDns() {
        showBanner("DNS önbelleği temizleniyor...", false);
        runBackendCmd("flush_dns");
    }

    Component.onCompleted: {
        refreshStatus();
    }
}
