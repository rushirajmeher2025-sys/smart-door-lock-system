#!/usr/bin/env python3
"""
LocKify Localhost Web App & ESP32 Hardware Bridge
Runs on http://localhost:8080.
Connects directly to the ESP32 circuit over USB Serial (/dev/cu.usbserial-0001).
Provides real-time telemetry, interactive lock controls, virtual keypad, and pin diagnostics.
"""

import http.server
import socketserver
import json
import threading
import time
import serial
import subprocess
import os
import sys

PORT = 8080
SERIAL_PORT = "/dev/cu.usbserial-0001"
SERIAL_BAUD = 115200

# Global circuit state
state = {
    "connected": False,
    "port": SERIAL_PORT,
    "isLocked": True,
    "doorClosed": True,
    "alarmActive": False,
    "servoAngle": 0,
    "lastEvent": "System initialized",
    "lastMethod": "startup",
    "uptime": "0s",
    "stuckKeyAlert": None,
    "events": [],
    "recentKeys": []
}

clients = []
ser_lock = threading.Lock()
ser_conn = None

def broadcast_event(event_type, data):
    payload = json.dumps({"type": event_type, "data": data})
    msg = f"data: {payload}\n\n".encode("utf-8")
    for client in list(clients):
        try:
            client.wfile.write(msg)
            client.wfile.flush()
        except Exception:
            if client in clients:
                clients.remove(client)

def log_circuit_event(text):
    timestamp = time.strftime("%H:%M:%S")
    entry = {"time": timestamp, "text": text}
    state["events"].append(entry)
    if len(state["events"]) > 50:
        state["events"].pop(0)
    broadcast_event("event_log", entry)

def serial_worker():
    global ser_conn
    repeat_key_count = 0
    last_raw_key = None
    last_print_time = 0

    while True:
        try:
            if not ser_conn or not ser_conn.is_open:
                try:
                    ser_conn = serial.Serial(SERIAL_PORT, SERIAL_BAUD, timeout=0.1)
                    state["connected"] = True
                    log_circuit_event(f"Connected to ESP32 on {SERIAL_PORT}")
                    broadcast_event("status", state)
                except Exception as e:
                    state["connected"] = False
                    time.sleep(2)
                    continue

            line = ser_conn.readline()
            if not line:
                time.sleep(0.01)
                continue

            text = line.decode("utf-8", errors="replace").strip()
            if not text:
                continue

            # Check for high-frequency stuck key floods
            if text.startswith("[KEY] ") or text.startswith("[EVENT] status"):
                if text == last_raw_key:
                    repeat_key_count += 1
                    if repeat_key_count == 30:
                        if "[KEY] #" in text:
                            state["stuckKeyAlert"] = "Key '#' is shorted or held (GPIO 27 [Row 4] <-> GPIO 33 [Col 3])"
                        elif "status" in text or "[KEY] D" in text:
                            state["stuckKeyAlert"] = "Key 'D' is shorted or held (GPIO 27 [Row 4] <-> GPIO 32 [Col 4])"
                        else:
                            state["stuckKeyAlert"] = f"Keypad repeat flood detected: {text}"
                        broadcast_event("alert", state["stuckKeyAlert"])
                    continue
                else:
                    last_raw_key = text
                    repeat_key_count = 1

            # Parse smart lock firmware output
            if "[SERVO]" in text:
                if "90 deg" in text:
                    state["servoAngle"] = 90
                    state["isLocked"] = False
                elif "0 deg" in text:
                    state["servoAngle"] = 0
                    state["isLocked"] = True
                broadcast_event("status", state)

            elif "[LOCK] Door unlocked" in text or "UNLOCKED" in text:
                state["isLocked"] = False
                state["servoAngle"] = 90
                broadcast_event("status", state)

            elif "[LOCK] Door locked" in text:
                state["isLocked"] = True
                state["servoAngle"] = 0
                broadcast_event("status", state)

            elif "[DOOR] Opened" in text:
                state["doorClosed"] = False
                broadcast_event("status", state)

            elif "[DOOR] Closed" in text:
                state["doorClosed"] = True
                broadcast_event("status", state)

            elif "[ALARM] INTRUDER" in text or "[EVENT] burglar_alarm" in text:
                state["alarmActive"] = True
                broadcast_event("status", state)

            elif "[ALARM] Alarm cleared" in text or "[EVENT] alarm_cleared" in text:
                state["alarmActive"] = False
                broadcast_event("status", state)

            elif "[KEY]" in text:
                k = text.replace("[KEY]", "").strip()
                state["recentKeys"].append(k)
                if len(state["recentKeys"]) > 10:
                    state["recentKeys"].pop(0)
                broadcast_event("key", k)

            log_circuit_event(text)

        except Exception as e:
            state["connected"] = False
            broadcast_event("status", state)
            time.sleep(1)

def send_serial(cmd):
    global ser_conn
    if ser_conn and ser_conn.is_open:
        with ser_lock:
            ser_conn.write((cmd + "\n").encode("utf-8"))
            ser_conn.flush()
        log_circuit_event(f"Sent command: {cmd}")
        return True
    return False

HTML_PAGE = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>LocKify · Localhost Circuit Tester</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700;800&family=JetBrains+Mono:wght@400;500;600&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg-dark: #0B0F19;
      --bg-card: rgba(22, 31, 48, 0.75);
      --bg-surface: #131A2A;
      --border: rgba(255, 255, 255, 0.08);
      --border-accent: rgba(0, 229, 255, 0.25);
      --cyan: #00E5FF;
      --blue: #0070F3;
      --red: #FF3B30;
      --green: #00E676;
      --orange: #FF9500;
      --text: #F8FAFC;
      --text-muted: #94A3B8;
      --glass: backdrop-filter: blur(16px); -webkit-backdrop-filter: blur(16px);
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background: radial-gradient(circle at 50% 0%, #152238 0%, var(--bg-dark) 75%);
      color: var(--text);
      font-family: 'Outfit', sans-serif;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
    }
    header {
      padding: 1.25rem 2rem;
      display: flex;
      justify-content: space-between;
      align-items: center;
      border-bottom: 1px solid var(--border);
      background: rgba(11, 15, 25, 0.6);
      backdrop-filter: blur(12px);
      position: sticky; top: 0; z-index: 100;
    }
    .brand { display: flex; align-items: center; gap: 0.75rem; }
    .brand-icon {
      width: 36px; height: 36px;
      background: linear-gradient(135deg, var(--cyan), var(--blue));
      border-radius: 10px;
      display: flex; align-items: center; justify-content: center;
      font-weight: 800; font-size: 1.25rem; color: #fff;
      box-shadow: 0 0 20px rgba(0, 229, 255, 0.3);
    }
    .brand-title { font-size: 1.35rem; font-weight: 700; letter-spacing: -0.5px; }
    .brand-subtitle { font-size: 0.75rem; color: var(--cyan); letter-spacing: 1.5px; text-transform: uppercase; }
    .chip-badge {
      display: flex; align-items: center; gap: 0.5rem;
      background: var(--bg-surface); padding: 0.4rem 0.9rem;
      border-radius: 999px; border: 1px solid var(--border);
      font-family: 'JetBrains Mono', monospace; font-size: 0.8rem;
    }
    .dot { width: 8px; height: 8px; border-radius: 50%; background: var(--green); box-shadow: 0 0 10px var(--green); animation: pulse 2s infinite; }
    .dot.offline { background: var(--red); box-shadow: 0 0 10px var(--red); }
    @keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.4; } }

    main {
      flex: 1; max-width: 1200px; width: 100%; margin: 0 auto;
      padding: 2rem 1.5rem;
      display: grid; grid-template-columns: 1fr 1fr; gap: 2rem;
    }
    @media (max-width: 900px) { main { grid-template-columns: 1fr; } }

    .card {
      background: var(--bg-card);
      border: 1px solid var(--border);
      border-radius: 24px;
      padding: 1.75rem;
      backdrop-filter: blur(16px);
      box-shadow: 0 12px 30px rgba(0,0,0,0.3);
      display: flex; flex-direction: column; gap: 1.5rem;
    }
    .card-title {
      font-size: 1rem; font-weight: 600; text-transform: uppercase;
      letter-spacing: 1px; color: var(--text-muted);
      display: flex; justify-content: space-between; align-items: center;
    }

    /* Lock Visualizer */
    .lock-display {
      display: flex; flex-direction: column; align-items: center; justify-content: center;
      padding: 2.5rem 1rem; position: relative;
    }
    .lock-circle {
      width: 180px; height: 180px;
      border-radius: 50%;
      background: radial-gradient(circle, rgba(255,59,48,0.15) 0%, rgba(22,31,48,0) 70%);
      border: 2px solid var(--red);
      box-shadow: 0 0 40px rgba(255,59,48,0.3);
      display: flex; flex-direction: column; align-items: center; justify-content: center;
      transition: all 0.5s cubic-bezier(0.4, 0, 0.2, 1);
      cursor: pointer;
    }
    .lock-circle.unlocked {
      border-color: var(--cyan);
      background: radial-gradient(circle, rgba(0,229,255,0.15) 0%, rgba(22,31,48,0) 70%);
      box-shadow: 0 0 40px rgba(0,229,255,0.3);
    }
    .lock-icon { font-size: 3.5rem; transition: transform 0.3s ease; }
    .lock-state-text { font-size: 1.5rem; font-weight: 700; margin-top: 1rem; letter-spacing: -0.5px; }
    .servo-badge {
      margin-top: 0.5rem; font-size: 0.85rem; font-family: 'JetBrains Mono', monospace;
      color: var(--cyan); background: rgba(0,229,255,0.1); padding: 0.25rem 0.75rem; border-radius: 8px;
    }

    /* Status Grid */
    .telemetry-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 1rem; }
    .telem-box {
      background: var(--bg-surface); padding: 1rem; border-radius: 16px;
      border: 1px solid var(--border); text-align: center;
    }
    .telem-label { font-size: 0.75rem; color: var(--text-muted); text-transform: uppercase; margin-bottom: 0.35rem; }
    .telem-val { font-size: 1.1rem; font-weight: 700; }
    .val-closed { color: var(--green); }
    .val-open { color: var(--orange); }
    .val-alarm { color: var(--red); animation: blink 1s infinite; }
    @keyframes blink { 0%, 100% { opacity: 1; } 50% { opacity: 0.2; } }

    /* Actions */
    .btn-row { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
    button {
      padding: 0.9rem 1.25rem; border-radius: 14px; border: none;
      font-family: 'Outfit', sans-serif; font-size: 0.95rem; font-weight: 600;
      cursor: pointer; transition: all 0.2s ease;
      display: flex; align-items: center; justify-content: center; gap: 0.5rem;
    }
    .btn-unlock { background: linear-gradient(135deg, #00C6FF, #0072FF); color: #fff; box-shadow: 0 4px 20px rgba(0, 114, 255, 0.4); }
    .btn-unlock:hover { transform: translateY(-2px); box-shadow: 0 6px 25px rgba(0, 114, 255, 0.6); }
    .btn-lock { background: linear-gradient(135deg, #FF416C, #FF4B2B); color: #fff; box-shadow: 0 4px 20px rgba(255, 75, 43, 0.4); }
    .btn-lock:hover { transform: translateY(-2px); box-shadow: 0 6px 25px rgba(255, 75, 43, 0.6); }
    .btn-secondary { background: var(--bg-surface); color: var(--text); border: 1px solid var(--border); }
    .btn-secondary:hover { background: rgba(255,255,255,0.06); border-color: rgba(255,255,255,0.2); }

    /* Keypad Grid */
    .keypad-grid {
      display: grid; grid-template-columns: repeat(4, 1fr); gap: 0.6rem;
      max-width: 320px; margin: 0 auto;
    }
    .key-btn {
      aspect-ratio: 1; border-radius: 12px; background: var(--bg-surface);
      border: 1px solid var(--border); font-size: 1.25rem; font-weight: 600;
      display: flex; align-items: center; justify-content: center;
      transition: all 0.15s ease;
    }
    .key-btn:hover { background: rgba(0, 229, 255, 0.1); border-color: var(--cyan); color: var(--cyan); }
    .key-btn:active, .key-btn.active { background: var(--cyan); color: #000; transform: scale(0.95); }
    .key-action { color: var(--cyan); }

    /* Alert Banner */
    .alert-box {
      background: rgba(255, 59, 48, 0.12);
      border: 1px solid rgba(255, 59, 48, 0.35);
      border-radius: 16px; padding: 1rem 1.25rem;
      display: flex; gap: 0.75rem; align-items: flex-start;
    }
    .alert-box.hidden { display: none; }
    .alert-text { font-size: 0.85rem; line-height: 1.4; color: #FFA39E; }
    .alert-text strong { color: #FFF; }

    /* Terminal Console */
    .terminal {
      background: #06090F; border: 1px solid rgba(255,255,255,0.06);
      border-radius: 16px; padding: 1rem;
      font-family: 'JetBrains Mono', monospace; font-size: 0.8rem;
      height: 220px; overflow-y: auto; display: flex; flex-direction: column; gap: 0.35rem;
    }
    .log-line { display: flex; gap: 0.5rem; color: #CBD5E1; }
    .log-time { color: #64748B; flex-shrink: 0; }
    .log-text { word-break: break-all; }
    .log-text.key { color: var(--cyan); font-weight: 600; }
    .log-text.lock { color: var(--green); font-weight: 600; }
    .log-text.alarm { color: var(--red); font-weight: 700; }
  </style>
</head>
<body>
  <header>
    <div class="brand">
      <div class="brand-icon">L</div>
      <div>
        <div class="brand-title">LocKify</div>
        <div class="brand-subtitle">Hardware Test Console</div>
      </div>
    </div>
    <div class="chip-badge">
      <div class="dot" id="connDot"></div>
      <span id="chipStatus">ESP32: /dev/cu.usbserial-0001</span>
    </div>
  </header>

  <main>
    <!-- Left Column: Visualizer & Controls -->
    <div class="card">
      <div class="card-title">
        <span>Smart Lock Telemetry</span>
        <span id="uptimeBadge" style="font-family:'JetBrains Mono'">Uptime: 0s</span>
      </div>

      <div class="lock-display">
        <div class="lock-circle" id="lockCircle" onclick="toggleLock()">
          <div class="lock-icon" id="lockIcon">🔒</div>
          <div class="lock-state-text" id="lockStateText">LOCKED</div>
        </div>
        <div class="servo-badge" id="servoBadge">SG90 Servo: 0° (Deadbolt Engaged)</div>
      </div>

      <div class="telemetry-grid">
        <div class="telem-box">
          <div class="telem-label">Door Sensor</div>
          <div class="telem-val val-closed" id="doorVal">CLOSED</div>
        </div>
        <div class="telem-box">
          <div class="telem-label">Intruder Siren</div>
          <div class="telem-val" id="alarmVal" style="color:var(--text-muted)">OFF</div>
        </div>
        <div class="telem-box">
          <div class="telem-label">LED Indicator</div>
          <div class="telem-val" id="ledVal" style="color:var(--red)">RED ON</div>
        </div>
      </div>

      <div class="btn-row">
        <button class="btn-unlock" onclick="sendCommand('UNLOCK')">
          <span>🔓</span> Remote Unlock (90°)
        </button>
        <button class="btn-lock" onclick="sendCommand('LOCK')">
          <span>🔒</span> Remote Lock (0°)
        </button>
      </div>

      <div class="btn-row">
        <button class="btn-secondary" onclick="sendCommand('DOOR_TOGGLE')">
          <span>🚪</span> Toggle Door Sensor (GPIO 5)
        </button>
        <button class="btn-secondary" onclick="sendCommand('INSIDE_BUTTON')">
          <span>🔘</span> Inside Exit Button (GPIO 16)
        </button>
      </div>
    </div>

    <!-- Right Column: Keypad & Terminal -->
    <div class="card">
      <div class="card-title">
        <span>Keypad (4x4 Matrix)</span>
        <span style="font-size:0.75rem">PIN: 1234 #</span>
      </div>

      <div class="alert-box" id="stuckAlert">
        <div style="font-size:1.5rem">⚠️</div>
        <div class="alert-text">
          <strong>Keypad Short Detected:</strong><br>
          <span id="alertMsg">Key '#' is actively shorted between GPIO 27 (Row 4) and GPIO 33 (Col 3). Check breadboard wiring.</span>
        </div>
      </div>

      <div class="keypad-grid">
        <button class="key-btn" onclick="sendKey('1')">1</button>
        <button class="key-btn" onclick="sendKey('2')">2</button>
        <button class="key-btn" onclick="sendKey('3')">3</button>
        <button class="key-btn key-action" onclick="sendKey('A')">A</button>

        <button class="key-btn" onclick="sendKey('4')">4</button>
        <button class="key-btn" onclick="sendKey('5')">5</button>
        <button class="key-btn" onclick="sendKey('6')">6</button>
        <button class="key-btn key-action" onclick="sendKey('B')">B</button>

        <button class="key-btn" onclick="sendKey('7')">7</button>
        <button class="key-btn" onclick="sendKey('8')">8</button>
        <button class="key-btn" onclick="sendKey('9')">9</button>
        <button class="key-btn key-action" onclick="sendKey('C')">C</button>

        <button class="key-btn key-action" onclick="sendKey('*')">*</button>
        <button class="key-btn" onclick="sendKey('0')">0</button>
        <button class="key-btn key-action" onclick="sendKey('#')">#</button>
        <button class="key-btn key-action" onclick="sendKey('D')">D</button>
      </div>

      <div class="card-title" style="margin-top:0.5rem">
        <span>Live Hardware Serial Stream</span>
        <button class="btn-secondary" style="padding:0.25rem 0.6rem; font-size:0.75rem;" onclick="clearLogs()">Clear</button>
      </div>

      <div class="terminal" id="terminal"></div>
    </div>
  </main>

  <script>
    const circle = document.getElementById('lockCircle');
    const lockIcon = document.getElementById('lockIcon');
    const lockText = document.getElementById('lockStateText');
    const servoBadge = document.getElementById('servoBadge');
    const doorVal = document.getElementById('doorVal');
    const alarmVal = document.getElementById('alarmVal');
    const ledVal = document.getElementById('ledVal');
    const stuckAlert = document.getElementById('stuckAlert');
    const alertMsg = document.getElementById('alertMsg');
    const terminal = document.getElementById('terminal');
    const connDot = document.getElementById('connDot');
    const chipStatus = document.getElementById('chipStatus');

    function updateUI(s) {
      if (s.connected) {
        connDot.className = 'dot';
        chipStatus.innerText = 'ESP32 Connected (' + s.port + ')';
      } else {
        connDot.className = 'dot offline';
        chipStatus.innerText = 'ESP32 Disconnected';
      }

      if (s.isLocked) {
        circle.className = 'lock-circle';
        lockIcon.innerText = '🔒';
        lockText.innerText = 'LOCKED';
        lockText.style.color = 'var(--red)';
        servoBadge.innerText = 'SG90 Servo: 0° (Deadbolt Engaged)';
        servoBadge.style.color = 'var(--red)';
        ledVal.innerText = 'RED ON';
        ledVal.style.color = 'var(--red)';
      } else {
        circle.className = 'lock-circle unlocked';
        lockIcon.innerText = '🔓';
        lockText.innerText = 'UNLOCKED';
        lockText.style.color = 'var(--cyan)';
        servoBadge.innerText = 'SG90 Servo: 90° (Deadbolt Retracted)';
        servoBadge.style.color = 'var(--cyan)';
        ledVal.innerText = 'BLUE ON';
        ledVal.style.color = 'var(--cyan)';
      }

      if (s.doorClosed) {
        doorVal.innerText = 'CLOSED';
        doorVal.className = 'telem-val val-closed';
      } else {
        doorVal.innerText = 'OPEN';
        doorVal.className = 'telem-val val-open';
      }

      if (s.alarmActive) {
        alarmVal.innerText = 'SIREN ACTIVE!';
        alarmVal.className = 'telem-val val-alarm';
      } else {
        alarmVal.innerText = 'OFF';
        alarmVal.className = 'telem-val';
        alarmVal.style.color = 'var(--text-muted)';
      }

      if (s.stuckKeyAlert) {
        stuckAlert.className = 'alert-box';
        alertMsg.innerText = s.stuckKeyAlert;
      }
    }

    function addLog(time, text) {
      const line = document.createElement('div');
      line.className = 'log-line';
      let cls = 'log-text';
      if (text.includes('[KEY]')) cls += ' key';
      if (text.includes('[LOCK]') || text.includes('UNLOCKED')) cls += ' lock';
      if (text.includes('[ALARM]')) cls += ' alarm';
      line.innerHTML = `<span class="log-time">[${time}]</span><span class="${cls}">${text}</span>`;
      terminal.appendChild(line);
      terminal.scrollTop = terminal.scrollHeight;
    }

    function clearLogs() { terminal.innerHTML = ''; }

    function sendCommand(cmd) {
      fetch('/api/command', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ command: cmd })
      });
    }

    function sendKey(k) {
      sendCommand('KEY:' + k);
      // Flash button visually
      const btns = document.querySelectorAll('.key-btn');
      btns.forEach(b => {
        if (b.innerText === k) {
          b.classList.add('active');
          setTimeout(() => b.classList.remove('active'), 150);
        }
      });
    }

    function toggleLock() {
      const isLocked = lockText.innerText === 'LOCKED';
      sendCommand(isLocked ? 'UNLOCK' : 'LOCK');
    }

    // Connect Server-Sent Events (SSE)
    const evtSource = new EventSource('/api/stream');
    evtSource.onmessage = function(e) {
      const msg = JSON.parse(e.data);
      if (msg.type === 'status') {
        updateUI(msg.data);
      } else if (msg.type === 'event_log') {
        addLog(msg.data.time, msg.data.text);
      } else if (msg.type === 'alert') {
        stuckAlert.className = 'alert-box';
        alertMsg.innerText = msg.data;
      }
    };

    // Initial fetch
    fetch('/api/status').then(r => r.json()).then(s => updateUI(s));
  </script>
</body>
</html>
"""

class RequestHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass  # suppress default noisy server logs

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self):
        if self.path == "/" or self.path == "/index.html":
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(HTML_PAGE.encode("utf-8"))
        elif self.path == "/api/status":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(json.dumps(state).encode("utf-8"))
        elif self.path == "/api/stream":
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Connection", "keep-alive")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            clients.append(self)
            try:
                # Keep connection alive
                while True:
                    time.sleep(15)
                    self.wfile.write(b": keep-alive\n\n")
                    self.wfile.flush()
            except Exception:
                if self in clients:
                    clients.remove(self)
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        if self.path == "/api/command":
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length).decode("utf-8")
            data = json.loads(body)
            cmd = data.get("command", "")
            success = send_serial(cmd)
            self.send_response(200 if success else 500)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(json.dumps({"success": success, "command": cmd}).encode("utf-8"))
        else:
            self.send_response(404)
            self.end_headers()


def run_server():
    t = threading.Thread(target=serial_worker, daemon=True)
    t.start()

    socketserver.TCPServer.allow_reuse_address = True
    server = socketserver.ThreadingTCPServer(("", PORT), RequestHandler)
    print(f"\n=======================================================")

    print(f"  LocKify Localhost Tester running at:")
    print(f"  👉 http://localhost:{PORT}")
    print(f"  ESP32 Port: {SERIAL_PORT}")
    print(f"=======================================================\n")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down server.")
        server.server_close()

if __name__ == "__main__":
    run_server()
