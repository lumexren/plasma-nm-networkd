#!/usr/bin/env python3
"""
plasma-networkd backend helper
Provides JSON status and network actions for systemd-networkd and wireless tools (iwd / wpa_supplicant).
"""

import sys
import json
import subprocess
import shutil
import os
import re
import time

def run_cmd(cmd_list, timeout=8):
    try:
        res = subprocess.run(cmd_list, capture_output=True, text=True, timeout=timeout)
        return res.returncode, res.stdout.strip(), res.stderr.strip()
    except Exception as e:
        return -1, "", str(e)

def get_systemd_networkd_status():
    code, out, _ = run_cmd(["systemctl", "is-active", "systemd-networkd"])
    is_active = (code == 0 and out.strip() == "active")
    
    code_en, out_en, _ = run_cmd(["systemctl", "is-enabled", "systemd-networkd"])
    is_enabled = (out_en.strip() == "enabled")

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

    return {
        "active": is_active,
        "enabled": is_enabled,
        "operational_state": overall_state
    }

def get_links():
    links = []
    
    # 1. systemd-networkd json
    networkd_links = {}
    code_nc, out_nc, _ = run_cmd(["networkctl", "status", "--json=short"])
    if code_nc == 0:
        try:
            nc_data = json.loads(out_nc)
            entries = nc_data if isinstance(nc_data, list) else nc_data.get("Interfaces", [])
            for item in entries:
                ifname = item.get("Name")
                if ifname:
                    networkd_links[ifname] = item
        except Exception:
            pass

    # 2. ip -j addr
    code_ip, out_ip, _ = run_cmd(["ip", "-j", "addr"])
    ip_links = []
    if code_ip == 0:
        try:
            ip_links = json.loads(out_ip)
        except Exception:
            ip_links = []

    # 3. Default gateways
    default_gateways = {}
    code_rt, out_rt, _ = run_cmd(["ip", "-j", "route"])
    if code_rt == 0:
        try:
            routes = json.loads(out_rt)
            for r in routes:
                if r.get("dst") == "default" and "dev" in r:
                    default_gateways[r["dev"]] = r.get("gateway", "")
        except Exception:
            pass

    # 4. DNS servers via resolvectl
    link_dns = {}
    code_res, out_res, _ = run_cmd(["resolvectl", "status", "--json=short"])
    if code_res == 0:
        try:
            res_data = json.loads(out_res)
            for item in res_data:
                if "ifname" in item:
                    dns_list = []
                    for s in item.get("servers", []):
                        if "addressString" in s:
                            dns_list.append(s["addressString"])
                    link_dns[item["ifname"]] = dns_list
        except Exception:
            pass

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

        ipv4_addrs = []
        ipv6_addrs = []
        for a in iface.get("addr_info", []):
            fam = a.get("family")
            local_ip = a.get("local")
            prefix = a.get("prefixlen")
            if fam == "inet" and local_ip:
                ipv4_addrs.append(f"{local_ip}/{prefix}")
            elif fam == "inet6" and local_ip and not local_ip.startswith("fe80"):
                ipv6_addrs.append(f"{local_ip}/{prefix}")

        nc_info = networkd_links.get(name, {})
        net_op_state = nc_info.get("OperationalState", operstate)
        net_admin_state = nc_info.get("AdministrativeState", "unmanaged")
        net_setup_state = nc_info.get("SetupState", "")

        status_label = net_op_state
        if not is_up:
            status_label = "down"
        elif not is_carrier:
            status_label = "no-carrier"
        elif net_op_state in ("routable", "configured") or (is_up and is_carrier and ipv4_addrs):
            status_label = "routable"

        links.append({
            "name": name,
            "type": link_type,
            "up": is_up,
            "carrier": is_carrier,
            "state": status_label,
            "admin_state": net_admin_state,
            "setup_state": net_setup_state,
            "mac": mac,
            "mtu": mtu,
            "ipv4": ipv4_addrs,
            "ipv6": ipv6_addrs,
            "gateway": default_gateways.get(name, ""),
            "dns": link_dns.get(name, [])
        })

    return links

def get_wifi_info():
    wifi_ifaces = []
    try:
        for entry in os.listdir("/sys/class/net"):
            if os.path.exists(f"/sys/class/net/{entry}/wireless") or os.path.exists(f"/sys/class/net/{entry}/phy80211"):
                wifi_ifaces.append(entry)
    except Exception:
        pass

    if not wifi_ifaces:
        return {"available": False, "interfaces": []}

    primary_iface = wifi_ifaces[0]
    has_iwd = shutil.which("iwctl") is not None
    has_wpa = shutil.which("wpa_cli") is not None

    backend_type = "iwd" if has_iwd else ("wpa_supplicant" if has_wpa else "none")
    connected_ssid = None
    connected_signal = 0
    connected_bssid = ""

    # Check iwd first
    if has_iwd:
        code, out, _ = run_cmd(["iwctl", "station", primary_iface, "show"])
        if code == 0:
            for line in out.splitlines():
                line = line.strip()
                if line.startswith("Connected network"):
                    parts = line.split(maxsplit=2)
                    if len(parts) >= 3:
                        connected_ssid = parts[2].strip()

    # Check wpa_cli if not found
    if not connected_ssid and has_wpa:
        code, out, _ = run_cmd(["wpa_cli", "-i", primary_iface, "status"])
        if code == 0:
            for line in out.splitlines():
                if line.startswith("ssid="):
                    connected_ssid = line.split("=", 1)[1].strip()
                elif line.startswith("bssid="):
                    connected_bssid = line.split("=", 1)[1].strip()

    # Fallback to iw link
    if not connected_ssid and shutil.which("iw"):
        code, out, _ = run_cmd(["iw", "dev", primary_iface, "link"])
        if code == 0 and "Not connected." not in out:
            for line in out.splitlines():
                line = line.strip()
                if line.startswith("SSID:"):
                    connected_ssid = line.split(":", 1)[1].strip()
                elif line.startswith("signal:"):
                    m = re.search(r"(-?\d+)\s*dBm", line)
                    if m:
                        try:
                            dbm = int(m.group(1))
                            connected_signal = max(0, min(100, 2 * (dbm + 100)))
                        except Exception:
                            pass

    return {
        "available": True,
        "interfaces": wifi_ifaces,
        "primary_interface": primary_iface,
        "backend": backend_type,
        "connected": {
            "ssid": connected_ssid,
            "bssid": connected_bssid,
            "signal": connected_signal
        } if connected_ssid else None
    }

def wifi_scan(iface=None):
    wifi = get_wifi_info()
    if not wifi["available"]:
        return {"success": False, "error": "No wireless interface found", "networks": []}

    target_iface = iface or wifi["primary_interface"]
    
    # Ensure interface is up before scanning
    run_cmd(["ip", "link", "set", target_iface, "up"])
    time.sleep(0.3)

    networks = []

    # 1. Try iwctl
    if shutil.which("iwctl"):
        run_cmd(["iwctl", "station", target_iface, "scan"], timeout=8)
        code, out, _ = run_cmd(["iwctl", "station", target_iface, "get-networks"], timeout=6)
        if code == 0:
            for line in out.splitlines():
                clean = re.sub(r'\x1b\[[0-9;]*m', '', line).strip()
                if not clean or "Network name" in clean or "---" in clean:
                    continue
                is_connected = clean.startswith(">") or clean.startswith("*")
                if is_connected:
                    clean = clean[1:].strip()

                parts = re.split(r'\s{2,}', clean)
                if parts:
                    name = parts[0].strip()
                    sec = parts[1].strip() if len(parts) > 1 else "open"
                    sig_str = parts[2].strip() if len(parts) > 2 else "****"
                    stars = sig_str.count("*")
                    pct = int((stars / 5.0) * 100) if stars > 0 else 60

                    networks.append({
                        "ssid": name,
                        "security": sec.lower(),
                        "signal": pct,
                        "connected": is_connected or (wifi.get("connected") and wifi["connected"].get("ssid") == name)
                    })

    # 2. Fallback to iw scan
    if not networks and shutil.which("iw"):
        run_cmd(["iw", "dev", target_iface, "scan"], timeout=6)
        code, out, _ = run_cmd(["iw", "dev", target_iface, "scan", "dump"], timeout=4)
        current_ssid = None
        current_signal = 50
        current_sec = "open"
        seen = set()

        for line in out.splitlines():
            line = line.strip()
            if line.startswith("BSS "):
                if current_ssid and current_ssid not in seen:
                    seen.add(current_ssid)
                    networks.append({
                        "ssid": current_ssid,
                        "security": current_sec,
                        "signal": current_signal,
                        "connected": bool(wifi.get("connected") and wifi["connected"].get("ssid") == current_ssid)
                    })
                current_ssid = None
                current_sec = "open"
            elif line.startswith("SSID:"):
                current_ssid = line.split(":", 1)[1].strip()
            elif line.startswith("signal:"):
                m = re.search(r"(-?\d+)\.\d+\s*dBm", line)
                if m:
                    dbm = int(m.group(1))
                    current_signal = max(0, min(100, 2 * (dbm + 100)))
            elif "RSN" in line or "WPA" in line:
                current_sec = "wpa2/wpa3"

        if current_ssid and current_ssid not in seen:
            networks.append({
                "ssid": current_ssid,
                "security": current_sec,
                "signal": current_signal,
                "connected": bool(wifi.get("connected") and wifi["connected"].get("ssid") == current_ssid)
            })

    networks.sort(key=lambda x: (not x["connected"], -x["signal"]))
    return {"success": True, "interface": target_iface, "networks": networks}

def wifi_connect(ssid, passphrase=None, iface=None):
    wifi = get_wifi_info()
    if not wifi["available"]:
        return {"success": False, "error": "No wireless interface"}

    target_iface = iface or wifi["primary_interface"]

    # Ensure link is up
    run_cmd(["ip", "link", "set", target_iface, "up"])
    time.sleep(0.3)

    # 1. Try iwctl
    if shutil.which("iwctl"):
        cmd = ["iwctl", "station", target_iface, "connect", ssid]
        if passphrase:
            cmd.extend(["-P", passphrase])
        code, out, err = run_cmd(cmd, timeout=15)
        if code == 0:
            # Trigger networkd to get DHCP lease
            run_cmd(["networkctl", "reconfigure", target_iface])
            run_cmd(["networkctl", "renew", target_iface])
            return {"success": True, "message": f"Connected to {ssid}"}

    # 2. Try wpa_cli
    if shutil.which("wpa_cli"):
        code_add, net_id, _ = run_cmd(["wpa_cli", "-i", target_iface, "add_network"])
        if code_add == 0 and net_id.isdigit():
            run_cmd(["wpa_cli", "-i", target_iface, "set_network", net_id, "ssid", f'"{ssid}"'])
            if passphrase:
                run_cmd(["wpa_cli", "-i", target_iface, "set_network", net_id, "psk", f'"{passphrase}"'])
            else:
                run_cmd(["wpa_cli", "-i", target_iface, "set_network", net_id, "key_mgmt", "NONE"])
            run_cmd(["wpa_cli", "-i", target_iface, "enable_network", net_id])
            run_cmd(["wpa_cli", "-i", target_iface, "select_network", net_id])
            time.sleep(1)
            run_cmd(["networkctl", "reconfigure", target_iface])
            run_cmd(["networkctl", "renew", target_iface])
            return {"success": True, "message": f"Connected to {ssid}"}

    return {"success": False, "error": "Failed to connect to Wi-Fi"}

def wifi_disconnect(iface=None):
    wifi = get_wifi_info()
    if not wifi["available"]:
        return {"success": False, "error": "No wireless interface"}
    target_iface = iface or wifi["primary_interface"]

    if shutil.which("iwctl"):
        code, out, err = run_cmd(["iwctl", "station", target_iface, "disconnect"])
        return {"success": (code == 0), "message": "Disconnected" if code == 0 else err}

    if shutil.which("wpa_cli"):
        code, out, err = run_cmd(["wpa_cli", "-i", target_iface, "disconnect"])
        return {"success": (code == 0), "message": "Disconnected" if code == 0 else err}

    return {"success": False, "error": "No wireless tool available"}

def link_action(action, link_name):
    # Support: connect, disconnect, reconfigure, renew, up, down
    if action in ("connect", "up"):
        # Bring link up + trigger networkd to reconfigure and acquire DHCP
        run_cmd(["ip", "link", "set", link_name, "up"])
        run_cmd(["networkctl", "up", link_name])
        time.sleep(0.3)
        code, out, err = run_cmd(["networkctl", "reconfigure", link_name])
        if code != 0:
            run_cmd(["networkctl", "renew", link_name])
        return {"success": True, "action": action, "link": link_name, "message": f"{link_name} connected"}
    
    elif action in ("disconnect", "down"):
        # Put interface down cleanly
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

def service_action(action):
    if action in ("start", "stop", "restart", "reload"):
        code, out, err = run_cmd(["systemctl", action, "systemd-networkd"])
        return {"success": (code == 0), "action": action, "output": out if code == 0 else err}
    return {"success": False, "error": "Invalid service action"}

def flush_dns():
    code, out, err = run_cmd(["resolvectl", "flush-caches"])
    return {"success": (code == 0), "output": out if code == 0 else err}

def get_full_status():
    networkd = get_systemd_networkd_status()
    links = get_links()
    wifi = get_wifi_info()

    is_online = False
    connected_link = None
    for l in links:
        if l["state"] in ("routable", "connected") and l["ipv4"]:
            is_online = True
            if not connected_link:
                connected_link = l["name"]

    return {
        "online": is_online,
        "active_link": connected_link,
        "systemd_networkd": networkd,
        "links": links,
        "wifi": wifi
    }

def main():
    if len(sys.argv) < 2 or sys.argv[1] in ("status", "get_status"):
        data = get_full_status()
        print(json.dumps(data, indent=2))
        return

    cmd = sys.argv[1]

    if cmd == "wifi_scan":
        iface = sys.argv[2] if len(sys.argv) > 2 else None
        print(json.dumps(wifi_scan(iface)))
    elif cmd == "wifi_connect":
        if len(sys.argv) < 3:
            print(json.dumps({"success": False, "error": "SSID required"}))
            return
        ssid = sys.argv[2]
        passphrase = sys.argv[3] if len(sys.argv) > 3 and sys.argv[3] != "" else None
        iface = sys.argv[4] if len(sys.argv) > 4 else None
        print(json.dumps(wifi_connect(ssid, passphrase, iface)))
    elif cmd == "wifi_disconnect":
        iface = sys.argv[2] if len(sys.argv) > 2 else None
        print(json.dumps(wifi_disconnect(iface)))
    elif cmd == "link_action":
        if len(sys.argv) < 4:
            print(json.dumps({"success": False, "error": "Action and link required"}))
            return
        action = sys.argv[2]
        link_name = sys.argv[3]
        print(json.dumps(link_action(action, link_name)))
    elif cmd == "service_action":
        if len(sys.argv) < 3:
            print(json.dumps({"success": False, "error": "Action required"}))
            return
        print(json.dumps(service_action(sys.argv[2])))
    elif cmd == "flush_dns":
        print(json.dumps(flush_dns()))
    else:
        print(json.dumps({"error": f"Unknown command {cmd}"}))

if __name__ == "__main__":
    main()
