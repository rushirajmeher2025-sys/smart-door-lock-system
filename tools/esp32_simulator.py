#!/usr/bin/env python3
"""Stand-in for the ESP32 lock, for testing the LocKify app without hardware.

It speaks to Firebase exactly like firmware/smart_lock/cloud.cpp does (same
REST paths, bodies and checks), against the local emulator by default:

    cd firebase && firebase emulators:start --project demo-lockify
    python3 tools/esp32_simulator.py --email lock@lockify.app --password secret123

Control the "hardware" from another terminal while it runs:

    curl localhost:8099/door/open     curl localhost:8099/door/close
    curl localhost:8099/pin           (correct PIN on the keypad: unlock + stop alarm)
    curl localhost:8099/offline       curl localhost:8099/online
    curl localhost:8099/state
"""

import argparse
import json
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer

DEVICE_ID = "esp32_lock_01"          # DEVICE_ID in config.h
FIRMWARE_VERSION = "3.0"
HEARTBEAT_INTERVAL = 10.0            # HEARTBEAT_INTERVAL_MS
COMMAND_POLL = 1.0                   # COMMAND_POLL_MS
COMMAND_MAX_AGE_MS = 15000           # COMMAND_MAX_AGE_MS
APP_CAN_CLEAR_ALARM = False
BURGLAR_GRACE_S = 2.0
SERVER_TS = {".sv": "timestamp"}

lock = threading.Lock()
hw = {
    "isLocked": True, "doorClosed": True, "burglarAlarmActive": False,
    "isLockout": False, "lastMethod": "keypad", "lockedAt": time.time(),
}
dirty = True
offline = False
events = []          # queued like the firmware's eventQueue
results = []         # queued like the firmware's resultQueue


def log(msg):
    print(time.strftime("%H:%M:%S"), msg, flush=True)


def push_event(type_, method):
    events.append({"type": type_, "method": method})


# ---------------- Firebase REST ----------------

class Cloud:
    def __init__(self, args):
        self.args = args
        self.token = ""
        self.uid = ""
        self.offset_ms = None
        self.owner = ""
        self.members = {}
        self.handled = []
        self.last_processed = ""

    def _url(self, path, query=""):
        base = self.args.db.rstrip("/")
        ns = f"&ns={self.args.ns}" if self.args.ns else ""
        return f"{base}{path}.json?auth={self.token}{ns}{query}"

    def request(self, method, path, body=None, query=""):
        data = None if body is None else json.dumps(body).encode()
        req = urllib.request.Request(self._url(path, query), data=data, method=method,
                                     headers={"Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=8) as r:
                return r.status, json.loads(r.read() or b"null")
        except urllib.error.HTTPError as e:
            return e.code, e.read().decode(errors="replace")
        except OSError as e:
            return -1, str(e)

    def sign_in(self):
        url = f"{self.args.auth}/v1/accounts:signInWithPassword?key={self.args.api_key}"
        body = {"email": self.args.email, "password": self.args.password, "returnSecureToken": True}
        req = urllib.request.Request(url, data=json.dumps(body).encode(), method="POST",
                                     headers={"Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=8) as r:
                res = json.loads(r.read())
        except urllib.error.HTTPError as e:
            log(f"[CLOUD] Sign-in failed: {e.read().decode(errors='replace')[:200]}")
            return False
        self.token, self.uid = res["idToken"], res["localId"]
        log(f"[CLOUD] Signed in to Firebase (uid {self.uid})")
        return True

    def refresh_access(self):
        code, meta = self.request("GET", f"/devices/{DEVICE_ID}/metadata")
        if code in (401, 403) or (code == 200 and meta is None):
            log(f"[CLOUD] No access yet. Link this lock in the app. This lock's UID: {self.uid}")
            return -1
        if code != 200:
            return 0
        self.owner = meta.get("ownerUid", "")
        self.members = meta.get("authorizedUsers") or {}
        if self.uid not in (self.owner, meta.get("deviceUid", "")):
            log(f"[CLOUD] Not linked. Add UID {self.uid} in the app.")
            return -1
        return 1

    def now(self):
        """Firebase server time, learned from status writes (like serverOffsetMs)."""
        if self.offset_ms is None:
            return int(time.time() * 1000)
        return int(time.monotonic() * 1000) + self.offset_ms

    def write_status(self, changed):
        with lock:
            s = dict(hw)
        doc = {k: s[k] for k in ("isLocked", "doorClosed", "burglarAlarmActive", "isLockout", "lastMethod")}
        doc.update({"isOnline": True, "firmwareVersion": FIRMWARE_VERSION, "lastHeartbeat": SERVER_TS})
        if changed:
            doc["lastUpdated"] = SERVER_TS
        if self.last_processed:
            doc["lastProcessedCommandId"] = self.last_processed
        sent = time.monotonic()
        code, res = self.request("PATCH", f"/devices/{DEVICE_ID}/status", doc)
        if code == 200 and isinstance(res, dict) and isinstance(res.get("lastHeartbeat"), int):
            mid = (sent + time.monotonic()) / 2
            self.offset_ms = res["lastHeartbeat"] - int(mid * 1000)
        return code == 200

    def set_command(self, cid, status, reason=None):
        doc = {"status": status}
        if status != "PROCESSING":
            doc["executedAt"] = SERVER_TS
        if reason:
            doc["failureReason"] = reason
        return self.request("PATCH", f"/devices/{DEVICE_ID}/commands/{cid}", doc)[0] == 200

    def reject(self, cid, reason):
        log(f"[CLOUD] Rejected command {cid}: {reason}")
        if self.set_command(cid, "REJECTED", reason):
            self.handled.append(cid)
            push_event(f"rej_{reason}", "app")

    def poll_commands(self):
        code, cmds = self.request("GET", f"/devices/{DEVICE_ID}/commands", query="&orderBy=%22%24key%22&limitToLast=5")
        if code != 200 or not isinstance(cmds, dict):
            return
        now = self.now()
        for cid in sorted(cmds):
            c = cmds[cid]
            if not isinstance(c, dict) or c.get("status") != "PENDING" or cid in self.handled:
                continue
            action = c.get("action")
            if action not in ("LOCK", "UNLOCK", "CLEAR_ALARM", "PING") or c.get("commandId") != cid \
                    or not isinstance(c.get("requestedAt"), int):
                self.reject(cid, "MALFORMED")
                continue
            requester = c.get("requestedBy", "")
            allowed = lambda: requester == self.owner or self.members.get(requester) is True
            if not allowed():
                self.refresh_access()          # may have just been given access
                if not allowed():
                    self.reject(cid, "UNAUTHORIZED")
                    continue
            age = now - c["requestedAt"]
            if age > COMMAND_MAX_AGE_MS or age < -5000:
                self.reject(cid, "EXPIRED")
                continue
            if not self.set_command(cid, "PROCESSING"):
                continue
            self.handled.append(cid)
            log(f"[CLOUD] Command {cid}: {action}")
            handle_remote_command(cid, action)


# ---------------- "Hardware" (mirrors smart_lock.ino) ----------------

def unlock_door(method):
    global dirty
    with lock:
        if hw["burglarAlarmActive"]:
            hw["burglarAlarmActive"] = False
            push_event("alarm_cleared", method)
        hw.update(isLocked=False, lastMethod=method)
        dirty = True
    push_event("unlock", method)


def lock_door(method):
    global dirty
    with lock:
        if hw["burglarAlarmActive"] or not hw["doorClosed"]:
            return False
        hw.update(isLocked=True, lastMethod=method, lockedAt=time.time())
        dirty = True
    push_event("lock", method)
    return True


def handle_remote_command(cid, action):
    if action == "UNLOCK":
        if hw["burglarAlarmActive"] and not APP_CAN_CLEAR_ALARM:
            results.append((cid, False, "ALARM_PIN_REQUIRED"))
            return
        unlock_door("app")
        results.append((cid, not hw["isLocked"], "" if not hw["isLocked"] else "UNLOCK_FAILED"))
    elif action == "LOCK":
        ok = lock_door("app")
        reason = "" if ok else ("ALARM_ACTIVE" if hw["burglarAlarmActive"] else "BLOCKED_DOOR_OPEN")
        results.append((cid, ok, reason))
    elif action == "CLEAR_ALARM":
        results.append((cid, False, "ALARM_PIN_REQUIRED"))
    else:
        results.append((cid, True, ""))


def set_door(closed):
    global dirty
    with lock:
        if hw["doorClosed"] == closed:
            return
        hw["doorClosed"] = closed
        dirty = True
        breakin = (not closed and hw["isLocked"] and time.time() - hw["lockedAt"] > BURGLAR_GRACE_S
                   and not hw["burglarAlarmActive"])
        if breakin:
            hw["burglarAlarmActive"] = True
    push_event("door_closed" if closed else "door_opened", "sensor")
    if breakin:
        push_event("burglar_alarm", "sensor")


# ---------------- Main loop (mirrors cloudTask) ----------------

def cloud_loop(cloud):
    global dirty
    while not cloud.sign_in():
        time.sleep(5)
    while cloud.refresh_access() != 1:
        time.sleep(5)
    online, ever_online, last_status, last_poll, last_access = False, False, 0.0, 0.0, time.time()
    while True:
        if offline:
            online = False
            time.sleep(0.5)
            continue
        if time.time() - last_access > 60:
            cloud.refresh_access()
            last_access = time.time()
        with lock:
            changed = dirty
            dirty = False
        if changed or time.time() - last_status >= HEARTBEAT_INTERVAL:
            if cloud.write_status(changed or not online):
                last_status = time.time()
                if not online:
                    online = True
                    log("[CLOUD] Online, reporting status")
                    push_event("lock_reconnected" if ever_online else "lock_online", "system")
                    ever_online = True
            elif changed:
                with lock:
                    dirty = True
        while results:
            cid, ok, reason = results[0]
            if not cloud.set_command(cid, "EXECUTED" if ok else "REJECTED", None if ok else reason):
                break
            results.pop(0)
            cloud.last_processed = cid
            if not ok:
                push_event(f"rej_{reason}", "app")
            with lock:
                dirty = True
        while events:
            e = events[0]
            body = {"type": e["type"], "title": e["type"], "method": e["method"], "severity": "normal",
                    "gsmAlertSent": False, "timestamp": SERVER_TS}
            body.update(describe(e["type"], e["method"]))
            if cloud.request("POST", f"/devices/{DEVICE_ID}/events", body)[0] != 200:
                break
            events.pop(0)
        if cloud.offset_ms is not None and time.time() - last_poll >= COMMAND_POLL:
            last_poll = time.time()
            cloud.poll_commands()
        time.sleep(0.05)


REASONS = {  # reasonText() in cloud.cpp
    "BLOCKED_DOOR_OPEN": "The door is open, so it was not locked",
    "ALARM_PIN_REQUIRED": "The alarm is on. Only the keypad PIN can stop it",
    "ALARM_ACTIVE": "The alarm is on. Enter the PIN on the keypad first",
    "EXPIRED": "The request arrived too late and was ignored",
    "UNAUTHORIZED": "The account is not allowed to control this lock",
    "MALFORMED": "The request was invalid",
}

METHOD_LABELS = {"keypad": "Keypad", "button": "Inside button", "app": "LocKify app",
                 "auto": "Auto-lock", "sensor": "Door sensor"}


def describe(type_, method):
    """Same titles/descriptions/severities as describeEvent() in cloud.cpp."""
    label = METHOD_LABELS.get(method, "Lock")
    table = {
        "unlock": ("Door unlocked", {"keypad": "Unlocked with the keypad PIN", "button": "Unlocked from the inside button",
                                     "app": "Unlocked remotely from the app"}.get(method, "Unlocked"), "normal"),
        "lock": ("Door locked", {"auto": "Locked automatically 5 s after the door closed", "keypad": "Locked with the A key",
                                 "button": "Locked from the inside button", "app": "Locked remotely from the app"}.get(method, "Locked"), "normal"),
        "door_opened": ("Door opened", "The door sensor reported the door open", "normal"),
        "door_closed": ("Door closed", "The door sensor reported the door closed", "normal"),
        "burglar_alarm": ("Break-in alarm", "Door opened while locked. Siren on until the PIN is entered", "alarm"),
        "alarm_cleared": ("Alarm stopped", f"Alarm cleared via {label}", "normal"),
        "lock_online": ("Lock online", "Connected to Wi-Fi and the cloud", "normal"),
        "lock_reconnected": ("Lock back online", "Reconnected after losing the connection", "warning"),
    }
    if type_.startswith("rej_"):
        return {"title": "Remote request rejected", "description": REASONS.get(type_[4:], type_[4:]),
                "severity": "warning", "method": label}
    title, desc, sev = table.get(type_, ("Lock event", type_, "normal"))
    return {"title": title, "description": desc, "severity": sev, "method": label}


class Control(BaseHTTPRequestHandler):
    def do_GET(self):
        global offline
        path = self.path.rstrip("/")
        if path == "/door/open":
            set_door(False)
        elif path == "/door/close":
            set_door(True)
        elif path == "/pin":
            unlock_door("keypad")
        elif path == "/offline":
            offline = True
        elif path == "/online":
            offline = False
        elif path != "/state":
            self.send_response(404)
            self.end_headers()
            return
        with lock:
            body = json.dumps({**hw, "offline": offline}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--email", required=True, help="the lock's Firebase account")
    ap.add_argument("--password", required=True)
    ap.add_argument("--db", default="http://127.0.0.1:9000", help="database URL (default: emulator)")
    ap.add_argument("--ns", default="demo-lockify-default-rtdb", help="emulator namespace; '' for real Firebase")
    ap.add_argument("--auth", default="http://127.0.0.1:9099/identitytoolkit.googleapis.com",
                    help="auth endpoint (default: emulator)")
    ap.add_argument("--api-key", default="demo-api-key")
    ap.add_argument("--port", type=int, default=8099, help="control port")
    args = ap.parse_args()

    server = HTTPServer(("127.0.0.1", args.port), Control)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    log(f"Simulated lock {DEVICE_ID}. Control it at http://127.0.0.1:{args.port}/ (door/open, door/close, pin, offline, online)")
    cloud_loop(Cloud(args))


if __name__ == "__main__":
    main()
