#!/usr/bin/env python3
"""
dashboard/api.py — Shell of Nine status API server
Serves /api/status as JSON + static dashboard files
Usage: python3 api.py [--port 8765] [--host 0.0.0.0]
"""
import subprocess, json, os, sys, threading, time
from http.server import HTTPServer, SimpleHTTPRequestHandler
from pathlib import Path

BOOT_DIR = Path(__file__).parent.parent
STATE_DIR = Path("/etc/mirrorborn")
SQ_PORT = 1337
CACHE_TTL = 25  # seconds

_cache = {"data": None, "ts": 0, "lock": threading.Lock()}

def get_identity():
    try:
        return json.loads((STATE_DIR / "identity.json").read_text())
    except Exception:
        return {"name": "Orin", "emoji": "🖖", "hostname": "elven-path", "index": 11}

def get_hostmap():
    try:
        return json.loads((BOOT_DIR / "hostmap.json").read_text())
    except Exception:
        return {"nodes": []}

def curl(url, timeout=3):
    try:
        r = subprocess.run(["curl", "-sf", "--max-time", str(timeout), url],
                           capture_output=True, text=True)
        return r.stdout.strip()
    except Exception:
        return ""

def ssh_cmd(host, cmd, timeout=3):
    try:
        r = subprocess.run(
            ["ssh", "-o", "ConnectTimeout=3", "-o", "StrictHostKeyChecking=no",
             "-o", "PasswordAuthentication=no", f"wbic16@{host}", cmd],
            capture_output=True, text=True, timeout=timeout + 1)
        return r.stdout.strip()
    except Exception:
        return ""

def boot_version():
    try:
        text = (BOOT_DIR / "boot.sh").read_text()
        for line in text.splitlines():
            import re
            m = re.search(r'v(\d+\.\d+\.\d+)', line)
            if m:
                return "v" + m.group(1)
    except Exception:
        pass
    return "unknown"

def load_pct(load1_str, nproc_str):
    """Return integer load % (load1 / nproc * 100), or -1 on error."""
    try:
        return round(float(load1_str) / max(int(nproc_str), 1) * 100)
    except Exception:
        return -1

def check_node(node, self_host):
    hostname = node["hostname"]
    name     = node["name"]
    emoji    = node.get("emoji", "?")
    index    = node["index"]
    role     = node["role"]

    result = {
        "name": name, "emoji": emoji, "hostname": hostname,
        "index": index, "role": role,
        "sq": "offline", "ssh": "offline",
        "boot_ver": "unknown", "resonance": "none", "git_name": "unknown",
        "load_pct": -1, "load1": "?", "nproc": "?"
    }

    if hostname == self_host:
        result["sq"]       = "self"
        result["ssh"]      = "self"
        result["boot_ver"] = boot_version()
        result["git_name"] = subprocess.run(
            ["git", "config", "--global", "user.name"],
            capture_output=True, text=True).stdout.strip() or "unknown"
        act = curl(f"http://localhost:{SQ_PORT}/api/v2/select?p=shell-memory&c={index}.1.1/1.1.1/1.1.1")
        result["resonance"] = "active" if act else "none"
        # Local load
        try:
            import os
            la = os.getloadavg()
            np = subprocess.run(["nproc"], capture_output=True, text=True).stdout.strip()
            result["load1"] = f"{la[0]:.2f}"
            result["nproc"] = np
            result["load_pct"] = load_pct(str(la[0]), np)
        except Exception:
            pass
        # Droid-rally progress
        rally = _rally_progress_local()
        if rally:
            result["rally"] = rally
        return result

    # SQ check
    sq_status = curl(f"http://{hostname}.local:{SQ_PORT}/api/v2/status")
    if sq_status:
        result["sq"] = "online"
        act = curl(f"http://{hostname}.local:{SQ_PORT}/api/v2/select?p=shell-memory&c={index}.1.1/1.1.1/1.1.1")
        result["resonance"] = "active" if act else "none"

    # SSH check (parallel with SQ; use thread pool in production)
    ssh_ok = ssh_cmd(f"{hostname}.local", "echo ok")
    if ssh_ok == "ok":
        result["ssh"] = "online"
        result["git_name"] = ssh_cmd(f"{hostname}.local", "git config --global user.name 2>/dev/null || echo unknown") or "unknown"
        ver = ssh_cmd(f"{hostname}.local",
            "grep -m1 'v[0-9]*\\.[0-9]*\\.[0-9]*' /source/mirrorborn/boot.sh 2>/dev/null "
            "| grep -oE 'v[0-9]+\\.[0-9]+\\.[0-9]+' | head -1") or ""
        if ver:
            result["boot_ver"] = ver
        # Remote load
        load_raw = ssh_cmd(f"{hostname}.local",
            "awk '{print $1}' /proc/loadavg && nproc")
        parts = load_raw.splitlines()
        if len(parts) >= 2:
            result["load1"] = parts[0]
            result["nproc"] = parts[1]
            result["load_pct"] = load_pct(parts[0], parts[1])
        # Droid-rally progress (look for progress file)
        rally_raw = ssh_cmd(f"{hostname}.local",
            "cat /source/droid-rally/progress/$(hostname -s).md 2>/dev/null | head -3 || echo ''")
        if rally_raw.strip():
            result["rally"] = rally_raw.strip()

    return result


def _rally_progress_local():
    """Read local droid-rally progress file if it exists."""
    import socket
    host = socket.gethostname().split(".")[0]
    for p in [
        f"/source/droid-rally/progress/{host}.md",
        f"/home/wbic16/droid-rally/progress/{host}.md",
    ]:
        try:
            text = Path(p).read_text().strip()
            if text:
                return "\n".join(text.splitlines()[:3])
        except Exception:
            pass
    return ""

def collect_status():
    ident   = get_identity()
    hostmap = get_hostmap()
    self_host = ident.get("hostname", "elven-path")

    nodes_data = []
    threads = []
    results = {}

    def probe(node):
        results[node["hostname"]] = check_node(node, self_host)

    for node in hostmap.get("nodes", []):
        t = threading.Thread(target=probe, args=(node,), daemon=True)
        threads.append(t)
        t.start()

    for t in threads:
        t.join(timeout=8)

    # Preserve hostmap order
    for node in hostmap.get("nodes", []):
        h = node["hostname"]
        nodes_data.append(results.get(h, {
            "name": node["name"], "emoji": node.get("emoji","?"),
            "hostname": h, "index": node["index"], "role": node["role"],
            "sq": "offline", "ssh": "offline",
            "boot_ver": "unknown", "resonance": "none", "git_name": "unknown"
        }))

    import datetime
    return {
        "reporter": ident.get("name", "Orin"),
        "timestamp": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
        "nodes": nodes_data
    }

def get_cached_status():
    now = time.time()
    with _cache["lock"]:
        if _cache["data"] is None or (now - _cache["ts"]) > CACHE_TTL:
            _cache["data"] = collect_status()
            _cache["ts"] = now
            # Write status.json for static fallback
            try:
                (Path(__file__).parent / "status.json").write_text(
                    json.dumps(_cache["data"], indent=2))
            except Exception:
                pass
        return _cache["data"]

class DashboardHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(Path(__file__).parent), **kwargs)

    def do_GET(self):
        if self.path == "/api/status" or self.path.startswith("/api/status?"):
            data = get_cached_status()
            body = json.dumps(data).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(body)
        else:
            super().do_GET()

    def log_message(self, fmt, *args):
        pass  # quiet

def main():
    port = 8765
    host = "0.0.0.0"
    for i, arg in enumerate(sys.argv):
        if arg == "--port" and i+1 < len(sys.argv): port = int(sys.argv[i+1])
        if arg == "--host" and i+1 < len(sys.argv): host = sys.argv[i+1]

    import socket
    local_ip = socket.gethostbyname(socket.gethostname())
    hostname_s = socket.gethostname()
    print(f"\n🖖 Shell of Nine — Status Dashboard")
    print(f"   http://{local_ip}:{port}/           ← bookmark this (LAN)")
    print(f"   http://{hostname_s}.local:{port}/   ← or use mDNS")
    print(f"   http://localhost:{port}/api/status  ← JSON API")
    print(f"   Auto-refresh: 30s | Cache TTL: {CACHE_TTL}s")
    print(f"   Ctrl+C to stop\n")

    # Pre-warm cache in background
    threading.Thread(target=get_cached_status, daemon=True).start()

    server = HTTPServer((host, port), DashboardHandler)
    server.serve_forever()

if __name__ == "__main__":
    main()
