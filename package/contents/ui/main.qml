import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground

    compactRepresentation: CompactRepresentation {
        plasmoidItem: root
    }

    fullRepresentation: FullRepresentation {
        plasmoidItem: root
    }

    property var backendData: ({
        online: false,
        active_link: "",
        systemd_networkd: { active: false, operational_state: "unknown" },
        links: [],
        wifi: { available: false, interfaces: [] }
    })
    property var trafficStats: ({})

    readonly property string calculatedIcon: {
        if (!backendData.online) {
            return "network-offline";
        }
        let activeObj = null;
        const links = backendData.links || [];
        for (let i = 0; i < links.length; i++) {
            if (links[i].name === backendData.active_link) {
                activeObj = links[i];
                break;
            }
        }
        if (activeObj && activeObj.type === "wlan") {
            const wifi = backendData.wifi;
            const sig = (wifi && wifi.connected) ? wifi.connected.signal : 60;
            if (sig >= 80) return "network-wireless-connected-100";
            if (sig >= 60) return "network-wireless-connected-75";
            if (sig >= 40) return "network-wireless-connected-50";
            return "network-wireless-connected-25";
        } else if (activeObj && (activeObj.type === "wireguard" || activeObj.type === "vpn")) {
            return "network-vpn";
        } else {
            return "network-wired-activated";
        }
    }

    Plasmoid.icon: calculatedIcon

    toolTipMainText: backendData.online ? i18n("%1 Connected", (backendData.active_link || i18n("Network"))) : i18n("No network connection")
    toolTipSubText: {
        if (!backendData.online) return i18n("systemd-networkd is running, but there is no internet access.");
        let txt = "";
        const links = backendData.links || [];
        for (let i = 0; i < links.length; i++) {
            if (links[i].name === backendData.active_link) {
                if (links[i].ipv4 && links[i].ipv4.length > 0) {
                    txt += i18n("IP: %1", links[i].ipv4[0]) + "\n";
                }
                if (links[i].gateway) {
                    txt += i18n("Gateway: %1", links[i].gateway);
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
                    const parsed = JSON.parse(stdout);
                    const now = Date.now();
                    const links = parsed.links || [];
                    for (let i = 0; i < links.length; i++) {
                        const l = links[i];
                        const prev = root.trafficStats[l.name];
                        if (prev && prev.timestamp && now > prev.timestamp && l.rx_bytes >= prev.rx_bytes && l.tx_bytes >= prev.tx_bytes) {
                            const dt = (now - prev.timestamp) / 1000.0;
                            if (dt > 0.4) {
                                l.rx_speed = Math.round((l.rx_bytes - prev.rx_bytes) / dt);
                                l.tx_speed = Math.round((l.tx_bytes - prev.tx_bytes) / dt);
                            } else {
                                l.rx_speed = prev.rx_speed || 0;
                                l.tx_speed = prev.tx_speed || 0;
                            }
                        } else {
                            l.rx_speed = 0;
                            l.tx_speed = 0;
                        }
                        root.trafficStats[l.name] = {
                            rx_bytes: l.rx_bytes,
                            tx_bytes: l.tx_bytes,
                            timestamp: now,
                            rx_speed: l.rx_speed,
                            tx_speed: l.tx_speed
                        };
                    }
                    root.backendData = parsed;
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
                        root.showBanner(i18n("Wi-Fi scan error: %1", res.error), true);
                    }
                } catch (e) {
                    root.showBanner(i18n("Failed to parse Wi-Fi scan output"), true);
                }
                return;
            }

            // Handle other actions
            try {
                const res = JSON.parse(stdout);
                if (res.success) {
                    root.showBanner(res.message || res.output || i18n("Operation completed successfully"), false);
                } else {
                    root.showBanner(res.error || stderr || i18n("Operation failed"), true);
                }
            } catch (e) {
                if (exitCode === 0) {
                    root.showBanner(stdout || i18n("Operation completed"), false);
                } else {
                    root.showBanner(stderr || i18n("An error occurred"), true);
                }
            }

            // Refresh status immediately and shortly after to catch DHCP updates
            root.refreshStatus();
            refreshDelayTimer.restart();
        }
    }

    onExpandedChanged: () => {
        if (root.expanded) {
            root.refreshStatus();
        }
    }

    Timer {
        id: pollTimer
        interval: root.expanded ? 2000 : 12000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshStatus()
    }

    Timer {
        id: refreshDelayTimer
        interval: 1200
        running: false
        repeat: false
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
        showBanner(i18n("Connecting to '%1'…", ssid), false);
        const passEscaped = password ? ("'" + password.replace(/'/g, "'\\''") + "'") : "''";
        const ssidEscaped = "'" + ssid.replace(/'/g, "'\\''") + "'";
        runBackendCmd("wifi_connect " + ssidEscaped + " " + passEscaped);
    }

    function disconnectWifi() {
        showBanner(i18n("Disconnecting Wi-Fi…"), false);
        runBackendCmd("wifi_disconnect");
    }

    function executeLinkAction(action, linkName) {
        showBanner(i18n("Applying %1 on %2…", action, linkName), false);
        runBackendCmd("link_action " + action + " " + linkName);
    }

    function executeServiceAction(action) {
        showBanner(i18n("Running systemd-networkd %1…", action), false);
        runBackendCmd("service_action " + action);
    }

    function flushDns() {
        showBanner(i18n("Flushing DNS resolver cache…"), false);
        runBackendCmd("flush_dns");
    }

    function openSettings() {
        runBackendCmd("open_settings");
    }

    Component.onCompleted: {
        Plasmoid.status = PlasmaCore.Types.ActiveStatus;
        refreshStatus();
    }
}
