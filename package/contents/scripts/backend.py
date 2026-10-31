#!/usr/bin/env python3
"""
Universal plasma-networkd backend helper
Supports both systemd-networkd and NetworkManager as drop-in backends.
Auto-detects running network manager daemon and provides unified JSON API.
"""

import sys
import json
import subprocess
import shutil
import os
import re
import time

def run_cmd(cmd_list, timeout=10):
    try:
        res = subprocess.run(cmd_list, capture_output=True, text=True, timeout=timeout)
        return res.returncode, res.stdout.strip(), res.stderr.strip()
    except Exception as e:
        return -1, "", str(e)

def get_link_traffic(name):
    rx = 0
    tx = 0
    try:
        rx_path = f"/sys/class/net/{name}/statistics/rx_bytes"
        tx_path = f"/sys/class/net/{name}/statistics/tx_bytes"
        if os.path.exists(rx_path):
            with open(rx_path, "r") as f:
                rx = int(f.read().strip())
        if os.path.exists(tx_path):
            with open(tx_path, "r") as f:
                tx = int(f.read().strip())
    except Exception:
        pass
    return rx, tx

def detect_backend():
    # 1. Check NetworkManager
    code_nm, out_nm, _ = run_cmd(["systemctl", "is-active", "NetworkManager"])
    if code_nm == 0 and out_nm.strip() == "active":
        return "NetworkManager"

    # 2. Check systemd-networkd
    code_netd, out_netd, _ = run_cmd(["systemctl", "is-active", "systemd-networkd"])
    if code_netd == 0 and out_netd.strip() == "active":
        return "systemd-networkd"

    # 3. Fallback checks via CLI tools
    if shutil.which("nmcli"):
        code_nmcli, _, _ = run_cmd(["nmcli", "general", "status"])
        if code_nmcli == 0:
            return "NetworkManager"

    return "systemd-networkd"

# ==========================================
# NetworkManager Driver
# ==========================================

def nm_get_status():
    code_gen, out_gen, _ = run_cmd(["nmcli", "-t", "-f", "STATE,CONNECTIVITY,WIFI", "general"])
    is_online = False
    wifi_hw_enabled = True

    if code_gen == 0 and out_gen:
        parts = out_gen.split(":")
        state = parts[0] if len(parts) > 0 else ""
        wifi_state = parts[2] if len(parts) > 2 else "enabled"
        is_online = (state in ("connected", "connected (global)", "connected (site only)"))
        wifi_hw_enabled = (wifi_state.lower() == "enabled")

    code_dev, out_dev, _ = run_cmd(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"])
    links = []
    active_link = None
    wifi_iface = None
    has_wifi_hardware = False

    if code_dev == 0 and out_dev:
        for line in out_dev.splitlines():
            parts = line.split(":")
            if len(parts) < 3:
                continue
            dev, dev_type, dev_state = parts[0], parts[1], parts[2]
            conn_name = parts[3] if len(parts) > 3 else ""

            if dev == "lo":
                continue

            link_type = "ether"
            if dev_type in ("wifi", "wlan"):
                link_type = "wlan"
                has_wifi_hardware = True
                if not wifi_iface:
                    wifi_iface = dev
            elif dev_type in ("wireguard", "vpn"):
                link_type = "wireguard"
            elif dev_type in ("bridge", "bridge-slave", "tun", "tap"):
                link_type = "bridge"

            is_connected = (dev_state == "connected")
            if is_connected and not active_link:
                active_link = dev

            ipv4_list = []
            ipv6_list = []
            gateway = ""
            dns_list = []
            mac = ""
            mtu = 1500

            code_show, out_show, _ = run_cmd(["nmcli", "-t", "-f", "IP4,IP6,GENERAL", "device", "show", dev])
            if code_show == 0 and out_show:
                for s_line in out_show.splitlines():
                    if s_line.startswith("IP4.ADDRESS"):
                        ip_val = s_line.partition(":")[2].strip()
                        if ip_val: ipv4_list.append(ip_val)
                    elif s_line.startswith("IP4.GATEWAY"):
                        gateway = s_line.partition(":")[2].strip()
                    elif s_line.startswith("IP4.DNS"):
                        dns_val = s_line.partition(":")[2].strip()
                        if dns_val: dns_list.append(dns_val)
                    elif s_line.startswith("IP6.ADDRESS"):
                        ip6_val = s_line.partition(":")[2].strip()
                        if ip6_val and not ip6_val.startswith("fe80"): ipv6_list.append(ip6_val)
                    elif s_line.startswith("GENERAL.HWADDR"):
                        mac = s_line.partition(":")[2].strip()
                    elif s_line.startswith("GENERAL.MTU"):
                        try: mtu = int(s_line.partition(":")[2].strip())
                        except: pass

            rx_b, tx_b = get_link_traffic(dev)

            links.append({
                "name": dev,
                "type": link_type,
                "up": is_connected or dev_state in ("connecting", "using"),
                "carrier": is_connected,
                "state": "routable" if is_connected else ("down" if dev_state in ("disconnected", "unavailable") else dev_state),
                "connection_name": conn_name,
                "mac": mac,
                "mtu": mtu,
                "rx_bytes": rx_b,
                "tx_bytes": tx_b,
                "ipv4": ipv4_list,
                "ipv6": ipv6_list,
                "gateway": gateway,
                "dns": dns_list
            })

    wifi_usable = has_wifi_hardware and wifi_hw_enabled
    if wifi_usable:
        code_rf, out_rf, _ = run_cmd(["rfkill", "list", "wifi"])
        if "Soft blocked: yes" in out_rf or "Hard blocked: yes" in out_rf:
            wifi_usable = False

    connected_wifi_ssid = None
    connected_wifi_sig = 0

    if wifi_usable and wifi_iface:
        code_wconn, out_wconn, _ = run_cmd(["nmcli", "-t", "-f", "SSID,SIGNAL,IN-USE", "device", "wifi", "list"])
        if code_wconn == 0 and out_wconn:
            for line in out_wconn.splitlines():
                w_parts = line.split(":")
                if len(w_parts) >= 3 and w_parts[2].strip() == "*":
                    connected_wifi_ssid = w_parts[0].strip()
                    try: connected_wifi_sig = int(w_parts[1].strip())
                    except: connected_wifi_sig = 75

    return {
        "backend": "NetworkManager",
        "online": is_online,
        "active_link": active_link,
        "systemd_networkd": { "active": False, "operational_state": "NetworkManager" },
        "links": links,
        "wifi": {
            "available": wifi_usable,
            "interfaces": [wifi_iface] if wifi_iface else [],
            "primary_interface": wifi_iface,
            "backend": "NetworkManager",
            "connected": {
                "ssid": connected_wifi_ssid,
                "signal": connected_wifi_sig
            } if connected_wifi_ssid else None
        }
    }

def nm_wifi_scan(iface=None):
    code_scan, out_scan, _ = run_cmd(["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY,IN-USE", "device", "wifi", "list", "--rescan", "auto"])
    if code_scan != 0:
        return {"success": False, "error": "Failed to scan wifi via nmcli", "networks": []}

    networks = []
    seen = set()

    for line in out_scan.splitlines():
        parts = line.split(":")
        if len(parts) >= 4:
            ssid = parts[0].strip()
            if not ssid or ssid in seen:
                continue
            seen.add(ssid)
            
            sig_val = 50
            try: sig_val = int(parts[1].strip())
            except: pass

            sec = parts[2].strip() or "open"
            is_in_use = (parts[3].strip() == "*")

            networks.append({
                "ssid": ssid,
                "security": sec.lower(),
                "signal": sig_val,
                "connected": is_in_use
            })

    networks.sort(key=lambda x: (not x["connected"], -x["signal"]))
    return {"success": True, "networks": networks}

def nm_wifi_connect(ssid, passphrase=None):
    cmd = ["nmcli", "device", "wifi", "connect", ssid]
    if passphrase:
        cmd.extend(["password", passphrase])
    code, out, err = run_cmd(cmd, timeout=20)
    return {
        "success": (code == 0),
        "message": out if code == 0 else err,
        "error": err if code != 0 else None
    }

def nm_wifi_disconnect():
    status = nm_get_status()
    wlan = status.get("wifi", {}).get("primary_interface")
    if wlan:
        code, out, err = run_cmd(["nmcli", "device", "disconnect", wlan])
        return {"success": (code == 0), "message": out if code == 0 else err}
    return {"success": False, "error": "No wireless device to disconnect"}

def nm_link_action(action, link_name):
    if action in ("connect", "up"):
        code, out, err = run_cmd(["nmcli", "device", "connect", link_name])
        return {"success": (code == 0), "action": action, "link": link_name, "message": out if code == 0 else err}
    elif action in ("disconnect", "down"):
        code, out, err = run_cmd(["nmcli", "device", "disconnect", link_name])
        return {"success": (code == 0), "action": action, "link": link_name, "message": out if code == 0 else err}
    elif action in ("reconfigure", "renew"):
        code, out, err = run_cmd(["nmcli", "device", "reapply", link_name])
        return {"success": (code == 0), "action": action, "link": link_name, "output": out if code == 0 else err}
    return {"success": False, "error": f"Unknown action {action}"}

# ==========================================
# systemd-networkd Driver
# ==========================================

def netd_get_status():
    code_active, out_active, _ = run_cmd(["systemctl", "is-active", "systemd-networkd"])
    is_active = (code_active == 0 and out_active.strip() == "active")

    overall_state = "unknown"
    if is_active:
        code_nc, out_nc, _ = run_cmd(["networkctl", "--json=short"])
        if code_nc == 0:
            try:
                data = json.loads(out_nc)
                if isinstance(data, dict):
                    overall_state = data.get("OperationalState", "routable")
            except Exception:
                pass

    networkd_links = {}
    code_nc, out_nc, _ = run_cmd(["networkctl", "status", "--json=short"])
    if code_nc == 0:
        try:
            nc_data = json.loads(out_nc)
            entries = nc_data if isinstance(nc_data, list) else nc_data.get("Interfaces", [])
            for item in entries:
                ifname = item.get("Name")
                if ifname: networkd_links[ifname] = item
        except Exception:
            pass

    code_ip, out_ip, _ = run_cmd(["ip", "-j", "addr"])
    ip_links = json.loads(out_ip) if code_ip == 0 else []

    default_gateways = {}
    code_rt, out_rt, _ = run_cmd(["ip", "-j", "route"])
    if code_rt == 0:
        try:
            for r in json.loads(out_rt):
                if r.get("dst") == "default" and "dev" in r:
                    default_gateways[r["dev"]] = r.get("gateway", "")
        except Exception:
            pass

    link_dns = {}
    code_res, out_res, _ = run_cmd(["resolvectl", "status", "--json=short"])
    if code_res == 0:
        try:
            for item in json.loads(out_res):
                if "ifname" in item:
                    dns_list = [s["addressString"] for s in item.get("servers", []) if "addressString" in s]
                    link_dns[item["ifname"]] = dns_list
        except Exception:
            pass

    links = []
    for iface in ip_links:
        name = iface.get("ifname", "")
        if not name or name == "lo":
            continue

        flags = iface.get("flags", [])
        is_up = "UP" in flags
        is_carrier = "LOWER_UP" in flags
        operstate = iface.get("operstate", "UNKNOWN").lower()
        mac = iface.get("address", "")
        mtu = iface.get("mtu", 1500)

        link_type = "ether"
        if os.path.exists(f"/sys/class/net/{name}/wireless") or os.path.exists(f"/sys/class/net/{name}/phy80211"):
            link_type = "wlan"
        elif name.startswith("wg") or iface.get("link_type") == "wireguard":
            link_type = "wireguard"
        elif name.startswith("virbr") or name.startswith("br") or name.startswith("docker"):
            link_type = "bridge"

        ipv4_addrs = [a["local"] + "/" + str(a["prefixlen"]) for a in iface.get("addr_info", []) if a.get("family") == "inet" and a.get("local")]
        ipv6_addrs = [a["local"] + "/" + str(a["prefixlen"]) for a in iface.get("addr_info", []) if a.get("family") == "inet6" and a.get("local") and not a["local"].startswith("fe80")]

        nc_info = networkd_links.get(name, {})
        net_op_state = nc_info.get("OperationalState", operstate)

        status_label = net_op_state
        if not is_up: status_label = "down"
        elif not is_carrier: status_label = "no-carrier"
        elif net_op_state in ("routable", "configured") or (is_up and is_carrier and ipv4_addrs):
            status_label = "routable"

        rx_b, tx_b = get_link_traffic(name)

        links.append({
            "name": name,
            "type": link_type,
            "up": is_up,
            "carrier": is_carrier,
            "state": status_label,
            "mac": mac,
            "mtu": mtu,
            "rx_bytes": rx_b,
            "tx_bytes": tx_b,
            "ipv4": ipv4_addrs,
            "ipv6": ipv6_addrs,
            "gateway": default_gateways.get(name, ""),
            "dns": link_dns.get(name, [])
        })

    # Wi-Fi usability check
    wifi_ifaces = []
    try:
        for entry in os.listdir("/sys/class/net"):
            if os.path.exists(f"/sys/class/net/{entry}/wireless") or os.path.exists(f"/sys/class/net/{entry}/phy80211"):
                wifi_ifaces.append(entry)
    except Exception:
        pass

    primary_wlan = wifi_ifaces[0] if wifi_ifaces else None
    wifi_usable = False
    connected_ssid = None
    connected_sig = 0
    backend_w = "none"

    if primary_wlan:
        code_rf, out_rf, _ = run_cmd(["rfkill", "list", "wifi"])
        if "Soft blocked: yes" not in out_rf and "Hard blocked: yes" not in out_rf:
            if shutil.which("iwctl"):
                code_iwd, out_iwd, _ = run_cmd(["iwctl", "station", primary_wlan, "show"])
                if code_iwd == 0:
                    backend_w = "iwd"
                    wifi_usable = True
                    for line in out_iwd.splitlines():
                        if "Connected network" in line:
                            parts = line.strip().split(maxsplit=2)
                            if len(parts) >= 3: connected_ssid = parts[2].strip()

            if not wifi_usable and shutil.which("wpa_cli"):
                code_wpa, out_wpa, _ = run_cmd(["wpa_cli", "-i", primary_wlan, "ping"])
                if code_wpa == 0 and "PONG" in out_wpa:
                    backend_w = "wpa_supplicant"
                    wifi_usable = True
                    code_st, out_st, _ = run_cmd(["wpa_cli", "-i", primary_wlan, "status"])
                    for line in out_st.splitlines():
                        if line.startswith("ssid="):
                            connected_ssid = line.split("=", 1)[1].strip()

    is_online = any(l["state"] in ("routable", "connected") and l["ipv4"] for l in links)
    active_l = next((l["name"] for l in links if l["state"] in ("routable", "connected") and l["ipv4"]), None)

    return {
        "backend": "systemd-networkd",
        "online": is_online,
        "active_link": active_l,
        "systemd_networkd": { "active": is_active, "operational_state": overall_state },
        "links": links,
        "wifi": {
            "available": wifi_usable,
            "interfaces": wifi_ifaces,
            "primary_interface": primary_wlan,
            "backend": backend_w,
            "connected": { "ssid": connected_ssid, "signal": connected_sig } if connected_ssid else None
        }
    }

def netd_wifi_scan(iface=None):
    wifi_info = netd_get_status()["wifi"]
    if not wifi_info["available"]:
        return {"success": False, "error": "Wireless is disabled or unavailable", "networks": []}

    target = iface or wifi_info["primary_interface"]
    run_cmd(["ip", "link", "set", target, "up"])
    time.sleep(0.3)

    networks = []
    if shutil.which("iwctl") and wifi_info.get("backend") == "iwd":
        run_cmd(["iwctl", "station", target, "scan"], timeout=8)
        code, out, _ = run_cmd(["iwctl", "station", target, "get-networks"], timeout=6)
        if code == 0:
            for line in out.splitlines():
                clean = re.sub(r'\x1b\[[0-9;]*m', '', line).strip()
                if not clean or "Network name" in clean or "---" in clean: continue
                is_conn = clean.startswith(">") or clean.startswith("*")
                if is_conn: clean = clean[1:].strip()
                parts = re.split(r'\s{2,}', clean)
                if parts:
                    name = parts[0].strip()
                    sec = parts[1].strip() if len(parts) > 1 else "open"
                    stars = parts[2].count("*") if len(parts) > 2 else 3
                    networks.append({
                        "ssid": name,
                        "security": sec.lower(),
                        "signal": int((stars / 5.0) * 100),
                        "connected": is_conn
                    })

    networks.sort(key=lambda x: (not x["connected"], -x["signal"]))
    return {"success": True, "networks": networks}

def netd_wifi_connect(ssid, passphrase=None, iface=None):
    wifi_info = netd_get_status()["wifi"]
    target = iface or wifi_info.get("primary_interface")
    if not target: return {"success": False, "error": "No wireless device"}

    run_cmd(["ip", "link", "set", target, "up"])
    time.sleep(0.3)

    if shutil.which("iwctl"):
        cmd = ["iwctl", "station", target, "connect", ssid]
        if passphrase: cmd.extend(["-P", passphrase])
        code, out, err = run_cmd(cmd, timeout=15)
        if code == 0:
            run_cmd(["networkctl", "reconfigure", target])
            run_cmd(["networkctl", "renew", target])
            return {"success": True, "message": f"Connected to {ssid}"}

    return {"success": False, "error": "Wi-Fi connection failed"}

def netd_wifi_disconnect(iface=None):
    wifi_info = netd_get_status()["wifi"]
    target = iface or wifi_info.get("primary_interface")
    if shutil.which("iwctl"):
        code, out, err = run_cmd(["iwctl", "station", target, "disconnect"])
        return {"success": (code == 0), "message": "Disconnected" if code == 0 else err}
    return {"success": False, "error": "No wireless tool available"}

def netd_link_action(action, link_name):
    if action in ("connect", "up"):
        run_cmd(["ip", "link", "set", link_name, "up"])
        run_cmd(["networkctl", "up", link_name])
        time.sleep(0.3)
        code, out, err = run_cmd(["networkctl", "reconfigure", link_name])
        if code != 0: run_cmd(["networkctl", "renew", link_name])
        return {"success": True, "action": action, "link": link_name, "message": f"{link_name} connected"}
    elif action in ("disconnect", "down"):
        run_cmd(["networkctl", "down", link_name])
        run_cmd(["ip", "link", "set", link_name, "down"])
        return {"success": True, "action": action, "link": link_name, "message": f"{link_name} disconnected"}
    elif action == "reconfigure":
        code, out, err = run_cmd(["networkctl", "reconfigure", link_name])
        return {"success": (code == 0), "action": action, "link": link_name, "output": out if code == 0 else err}
    elif action == "renew":
        code, out, err = run_cmd(["networkctl", "renew", link_name])
        return {"success": (code == 0), "action": action, "link": link_name, "output": out if code == 0 else err}
    return {"success": False, "error": f"Unknown action {action}"}

# ==========================================
# Dispatcher / Main Entry
# ==========================================

def open_settings():
    if shutil.which("kcmshell6"):
        subprocess.Popen(["kcmshell6", "kcm_network"])
        return {"success": True}
    elif shutil.which("systemsettings"):
        subprocess.Popen(["systemsettings", "kcm_network"])
        return {"success": True}
    return {"success": False, "error": "Settings app not found"}

def main():
    backend = detect_backend()

    if len(sys.argv) < 2 or sys.argv[1] in ("status", "get_status"):
        data = nm_get_status() if backend == "NetworkManager" else netd_get_status()
        print(json.dumps(data, indent=2))
        return

    cmd = sys.argv[1]

    if cmd == "wifi_scan":
        res = nm_wifi_scan() if backend == "NetworkManager" else netd_wifi_scan()
        print(json.dumps(res))
    elif cmd == "wifi_connect":
        if len(sys.argv) < 3:
            print(json.dumps({"success": False, "error": "SSID required"}))
            return
        ssid = sys.argv[2]
        passphrase = sys.argv[3] if len(sys.argv) > 3 and sys.argv[3] != "" else None
        res = nm_wifi_connect(ssid, passphrase) if backend == "NetworkManager" else netd_wifi_connect(ssid, passphrase)
        print(json.dumps(res))
    elif cmd == "wifi_disconnect":
        res = nm_wifi_disconnect() if backend == "NetworkManager" else netd_wifi_disconnect()
        print(json.dumps(res))
    elif cmd == "link_action":
        if len(sys.argv) < 4:
            print(json.dumps({"success": False, "error": "Action and link required"}))
            return
        action = sys.argv[2]
        link_name = sys.argv[3]
        res = nm_link_action(action, link_name) if backend == "NetworkManager" else netd_link_action(action, link_name)
        print(json.dumps(res))
    elif cmd == "open_settings":
        print(json.dumps(open_settings()))
    elif cmd == "flush_dns":
        code, out, err = run_cmd(["resolvectl", "flush-caches"])
        if code != 0:
            code, out, err = run_cmd(["systemd-resolve", "--flush-caches"])
        print(json.dumps({"success": (code == 0), "output": out if code == 0 else err}))
    else:
        print(json.dumps({"error": f"Unknown command {cmd}"}))

if __name__ == "__main__":
    main()
