# LocKify · Smart Door Lock System

*Security at Your Fingertips.*

An IoT access control and security system powered by an **ESP32 microcontroller**, integrated with the **LocKify Flutter app** and **Firebase** (Authentication + Realtime Database). SIM800L GSM SMS alerts are planned.

**Setting it up? Follow [docs/SETUP.md](docs/SETUP.md).**

---

## Architecture Overview

```
                      +-----------------------------+
                      |        LocKify app          |
                      |  (Flutter: Android, iOS,    |
                      |   Web)                      |
                      +--------------+--------------+
                                     |  status / events  ^
                                     v  commands         |
                      +-----------------------------+
                      |  Firebase Auth + Realtime   |
                      |  Database (security rules)  |
                      +--------------+--------------+
                                     |  HTTPS (cloud task, core 0)
                                     v
+------------------+          +---------------+          +------------------+
| 4x4 Keypad PIN   | -------> |     ESP32     | -------> | SG90 Servo Motor |
| & Door Sensors   |          | (lock logic,  |          | (Deadbolt Lock)  |
+------------------+          |   core 1)     |          +------------------+
                              +-------+-------+
                                      |
                                      v
                             +-----------------+
                             | SIM800L GSM     |
                             | (planned)       |
                             +-----------------+
```

The app never drives the servo directly. It files a command in Firebase; the ESP32 checks who sent it, how old it is, and whether it's safe (door closed, no alarm), then acts and reports the real result.

---

## Features
- **Access:**
  - Dynamic 4 to 8-digit PIN via physical 4x4 matrix keypad.
  - One-touch internal exit button.
  - Remote lock/unlock from the LocKify app (swipe to confirm), with per-account access sharing.
- **Hardware Telemetry & Security:**
  - 1.3" I2C SH1106 OLED real-time status and masked PIN display.
  - Non-volatile storage (`Preferences.h` / NVS) for credential persistence across reboots.
  - Anti-tamper brute force lockout (10 seconds after 3 failed attempts).
  - Auto-relocking (5 seconds after door closure).
  - Intruder burglar siren (30-second dual-tone alarm with flashing LED); only the keypad PIN stops it.
- **Cloud & App:**
  - Live lock, door, alarm and keypad state, with offline and stale-data detection.
  - Activity history of every lock event, including rejected remote requests and reconnects.
  - Firmware keeps all local functions working with no Wi-Fi or internet.
  - Demo mode, Firebase emulator mode, and a Python ESP32 simulator for testing without hardware.

---

## Repository Structure
```
├── docs/
│   ├── SETUP.md               # Step-by-step go-live guide (Firebase, app, firmware)
│   └── database_schema.md     # Database layout, rules and command lifecycle
├── firebase/                  # Realtime Database security rules + emulator config
├── firmware/smart_lock/       # ESP32 Arduino sketch
│   ├── smart_lock.ino         # Lock state machine, keypad, servo, alarm
│   ├── config.h               # GPIO pinout, timings, cloud settings
│   ├── cloud.h / cloud.cpp    # Wi-Fi + Firebase link (background task)
│   └── secrets.example.h      # Copy to secrets.h (git-ignored) for Wi-Fi/Firebase credentials
├── mobile_app/                # LocKify Flutter app
│   └── lib/                   # Screens, widgets, repositories (Firebase + demo), models
├── tools/esp32_simulator.py   # Stand-in for the ESP32 when testing without hardware
└── phases/                    # Phase-wise implementation roadmap
```

---

## Development Roadmap
- [x] **Phase 0:** Project discovery, hardware pin auditing, and architecture baseline.
- [x] **Phase 1:** Development environment verification, Flutter project scaffolding, and theme design tokens.
- [x] **Phase 2:** Mobile application UI/UX (LocKify redesign: animated lock, swipe-to-confirm, activity timeline).
- [x] **Phase 3:** Firebase Authentication.
- [x] **Phase 4:** Firebase data structure and security rules.
- [x] **Phase 5:** Live device status in the app (offline/stale detection, permission errors).
- [x] **Phase 6:** ESP32 Wi-Fi & Firebase synchronization (compiled; awaiting test on the physical circuit).
- [x] **Phase 7:** Secure remote lock/unlock (verified against the emulator with the ESP32 simulator).
- [ ] **Phase 8:** SIM800L GSM SMS alerts (waiting for the modem model and wiring to be confirmed).
- [x] **Phase 9:** Activity history.
- [ ] **Phase 10:** End-to-end testing on the real hardware ([checklist](docs/SETUP.md#7-check-it-end-to-end)).
- [ ] **Phase 11:** Final documentation and demo.
