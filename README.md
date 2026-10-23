# Smart Door Lock System

An IoT access control and security system powered by an **ESP32 microcontroller**, integrated with a **Flutter mobile application**, **Firebase Realtime Database**, and **SIM800L GSM SMS alerts**.

---

## Architecture Overview

```
                      +-----------------------------+
                      |     Flutter Mobile App      |
                      |  (iOS, Android, Web UI/UX)  |
                      +--------------+--------------+
                                     |
                                     v
                      +-----------------------------+
                      |     Firebase Cloud DB       |
                      | (Realtime State & Auth Log) |
                      +--------------+--------------+
                                     |
                                     v
+------------------+          +---------------+          +------------------+
| 4x4 Keypad PIN   | -------> |     ESP32     | -------> | SG90 Servo Motor |
| & Door Sensors   |          | Microcontrol. |          | (Deadbolt Lock)  |
+------------------+          +-------+-------+          +------------------+
                                      |
                                      v
                             +-----------------+
                             | SIM800L GSM Mod.|
                             | (SMS Alerts)    |
                             +-----------------+
```

---

## Features
- **Multi-Factor Access:**
  - Dynamic 4 to 8-digit PIN via physical 4x4 matrix keypad.
  - One-touch emergency internal exit button override.
  - Remote monitoring and controls via Flutter mobile application.
- **Hardware Telemetry & Security:**
  - 1.3" I2C SH1106 OLED real-time status and masked PIN display.
  - Non-volatile storage (`Preferences.h` / NVS) for credential persistence across reboots.
  - Anti-tamper brute force lockout (10 seconds after 3 failed attempts).
  - Auto-relocking (5 seconds after door closure).
  - Intruder burglar siren (30-second dual-tone alarm with flashing strobe LED).
  - GSM cellular SMS alerts dispatched on unauthorized intrusions or security events.

---

## Repository Structure
```
├── docs/                # Architecture specifications & system design documentation
├── firmware/            # ESP32 C++ firmware (Arduino/ESP-IDF)
│   ├── smart_lock.ino   # Core state machine, actuator control & security loops
│   └── config.h         # GPIO pinout definitions and hardware timing parameters
├── mobile_app/          # Flutter cross-platform mobile application
│   ├── lib/             # Null-safe Dart architecture (Theme, Models, Screens, Widgets)
│   └── pubspec.yaml     # Dependencies and configuration
└── phases/              # Phase-wise implementation roadmap
```

---

## Development Roadmap
- [x] **Phase 0:** Project discovery, hardware pin auditing, and architecture baseline.
- [x] **Phase 1:** Development environment verification, Flutter project scaffolding, and theme design tokens.
- [ ] **Phase 2:** Mobile application UI/UX implementation (interactive security dashboard, lock animations, activity logs).
- [ ] **Phase 3:** Firebase setup & local simulation.
- [ ] **Phase 4:** Mobile app cloud integration (Firebase Auth & Realtime Database).
- [ ] **Phase 5:** ESP32 firmware WiFi & Firebase synchronization.
- [ ] **Phase 6:** SIM800L GSM modem AT command integration & SMS alerts.
- [ ] **Phase 7:** End-to-end integration and security testing.
- [ ] **Phase 8:** Final documentation and production handover.
