# Firebase Realtime Database Architecture & Security Schema

This document details the database structure, security rules, access-control matrix, and command lifecycle for the **Smart Door Lock System** connecting the Flutter mobile app, ESP32 microcontroller, and Firebase cloud.

---

## 1. Top-Level Hierarchy Overview

```
/
├── devices/
│   └── {deviceId}/
│       ├── status/              # Real-time physical hardware telemetry (ESP32 -> Cloud)
│       ├── commands/            # Remote lock/unlock requests (App -> ESP32)
│       │   └── {commandId}/
│       ├── events/              # Security audit log & alert history (ESP32 -> Cloud)
│       │   └── {eventId}/
│       └── metadata/            # Device specs, ownership & authorization ACL
└── users/
    └── {uid}/
        └── devices/             # Device index map for rapid querying
            └── {deviceId}: true
```

---

## 2. Field-by-Field Schema Specification

### A. Physical Status: `/devices/{deviceId}/status`
Represents the genuine, confirmed state of the physical lock reported by the ESP32.
* **Writer:** Physical ESP32 (or Owner Admin).
* **Readers:** Authenticated & authorized users.

| Field | Type | Description | Example |
| :--- | :--- | :--- | :--- |
| `isLocked` | `boolean` | Current position of deadbolt servo (`true` = 0°, `false` = 90°). | `true` |
| `doorClosed` | `boolean` | State of the magnetic/toggle door sensor. | `true` |
| `isOnline` | `boolean` | Device cloud heartbeat indicator. | `true` |
| `lastUpdated` | `number` | Server epoch timestamp (ms) of the last status change. | `1729729800000` |
| `lastHeartbeat` | `number` | Epoch timestamp (ms) of the latest ESP32 keepalive ping. | `1729729830000` |
| `burglarAlarmActive`| `boolean`| `true` if door was forced open while locked. | `false` |
| `isLockout` | `boolean` | `true` if 3 failed PIN attempts triggered a 10s lockout. | `false` |
| `lastMethod` | `string` | Method of last actuation (`keypad`, `button`, `app`, `auto`). | `"keypad"` |
| `lastProcessedCommandId`| `string`| ID of the most recently executed remote command. | `"-OBx3kq..."` |
| `firmwareVersion` | `string` | Firmware build reporting this status. | `"3.0"` |

`lastUpdated` changes only when the lock state changes; `lastHeartbeat` is refreshed every 10 s. The app treats the lock as offline when `lastHeartbeat` is older than 35 s.

---

### B. Remote Commands: `/devices/{deviceId}/commands/{commandId}`
Queue of remote actuation requests issued by authorized mobile app users.
* **Writers:**
  * **Creation:** Authorized mobile users (only with status `"PENDING"`).
  * **Status Update:** ESP32 device updates to `"PROCESSING"`, `"EXECUTED"`, or `"REJECTED"`.
* **Readers:** Authorized users & ESP32.

| Field | Type | Allowed Values / Validation | Description |
| :--- | :--- | :--- | :--- |
| `commandId` | `string` | Must match `$commandId` node key. | Firebase push ID (time-ordered), so the lock can read the newest few with `orderBy="$key"&limitToLast=5`. |
| `action` | `string` | `"LOCK"`, `"UNLOCK"`, `"CLEAR_ALARM"`, `"PING"` | Requested operation. |
| `requestedBy` | `string` | Must equal `auth.uid`. | UID of the requesting mobile user. |
| `requestedAt` | `number` | Epoch timestamp (ms), written as the server timestamp. | The lock rejects commands more than 15 s old as `EXPIRED`. |
| `status` | `string` | `"PENDING"`, `"PROCESSING"`, `"EXECUTED"`, `"REJECTED"`, `"FAILED"` | Command lifecycle state. |
| `executedAt` | `number` | Epoch timestamp (ms) or null. | When ESP32 completed servo rotation. |
| `failureReason` | `string` | `BLOCKED_DOOR_OPEN`, `ALARM_PIN_REQUIRED`, `ALARM_ACTIVE`, `EXPIRED`, `UNAUTHORIZED`, `MALFORMED`, `LOCK_BUSY` | Reason if rejected by firmware safety. |

---

### C. Security Events: `/devices/{deviceId}/events/{eventId}`
Append-only chronological audit trail of all security events and physical activities.
* **Writer:** ESP32 hardware controller.
* **Readers:** Authorized users.

| Field | Type | Description | Example |
| :--- | :--- | :--- | :--- |
| `type` | `string` | Firmware event name (`unlock`, `lock`, `failed_attempt`, `lockout`, `door_opened`, `door_closed`, `burglar_alarm`, `alarm_cleared`, `door_warning`, `pin_changed`, `lock_online`, `lock_reconnected`, `rej_<REASON>`). | `"burglar_alarm"` |
| `title` | `string` | Human-readable event summary. | `"Break-in alarm"` |
| `description` | `string` | Detailed contextual explanation. | `"Door opened while locked (30s siren)"` |
| `method` | `string` | Trigger source (`Keypad PIN`, `Sensor GPIO 5`, etc.). | `"Intrusion Sensor"` |
| `timestamp` | `number` | Epoch timestamp (ms) of the event. | `1729729800000` |
| `severity` | `string` | `"normal"`, `"warning"`, or `"alarm"`. | `"alarm"` |
| `gsmAlertSent` | `boolean` | Whether an SMS was dispatched via SIM800L. | `true` |

---

### D. Device Metadata & Authorization: `/devices/{deviceId}/metadata`
Stores hardware identity, owner UID, and the access-control list (ACL) of permitted users.
* **Writer:** Device Owner (`auth.uid === ownerUid`).
* **Readers:** Authorized users.

| Field | Type | Description | Example |
| :--- | :--- | :--- | :--- |
| `deviceId` | `string` | Unique hardware identifier. | `"esp32_lock_01"` |
| `deviceName` | `string` | Friendly display name. | `"Front Entrance Lock"` |
| `ownerUid` | `string` | UID of the primary administrator. Set once when the first account claims the lock; cannot be changed. | `"user_abc123"` |
| `deviceUid` | `string` | UID of the lock's own Firebase account. Linked by the owner in the app (Settings › Lock account). | `"lock_uid_789"` |
| `authorizedUsers` | `map` | Map of permitted UIDs (`{ "uid_xyz": true }`). | `{ "uid_456": true }` |
| `firmwareVersion` | `string` | ESP32 firmware release string. | `"2.9"` |
| `hardware` | `string` | Microcontroller & module model. | `"ESP32 DevKit V4"` |

---

## 3. Access Control Matrix (Security Rules)

| Path | Unauthenticated | Authorized Mobile User | Device Owner | ESP32 Hardware |
| :--- | :---: | :---: | :---: | :---: |
| `devices/{id}/status` | ❌ No Access | 👁️ **Read Only** | 👁️ Read / ✏️ Write | ✏️ **Write Only** |
| `devices/{id}/commands` | ❌ No Access | ✏️ **Create PENDING** | 👁️ Read / ✏️ Create | ✏️ **Update Status** |
| `devices/{id}/events` | ❌ No Access | 👁️ **Read Only** | 👁️ Read Only | ✏️ **Append Events** |
| `devices/{id}/metadata` | ❌ No Access | 👁️ **Read Only** | ✏️ **Full Admin** | 👁️ Read Only |
| `users/{uid}/devices` | ❌ No Access | ✏️ Own UID Only | ✏️ Own UID Only | ❌ No Access |

---

## 4. Remote Command Lifecycle & Firmware Safety Enforcement

```
[Mobile App User]
       │
       ▼
1. Taps "LOCK" / "UNLOCK"
       │
       ▼
2. Safety Pre-Check (If action == 'LOCK' && door == 'OPEN' -> Abort with alert)
       │
       ▼
3. Write command node to Firebase:
   path: /devices/{deviceId}/commands/{cmd_123}
   { action: 'LOCK', status: 'PENDING', requestedBy: auth.uid, requestedAt: now }
       │
       ▼
[Firebase Database Rules Validate]:
   - requestedBy == auth.uid
   - status == 'PENDING'
   - user in authorizedUsers
       │
       ▼
[ESP32 Realtime DB Listener detects new child with status == 'PENDING']
       │
       ▼
4. ESP32 evaluates hardware constraints:
   ├─ If action == 'LOCK' and digitalRead(DOOR_SENSOR) == OPEN:
   │    └─ Mark command: { status: 'REJECTED', failureReason: 'BLOCKED_DOOR_OPEN' }
   │    └─ Sound error tone & update display
   │
   └─ If safety checks pass:
        ├─ Mark command: { status: 'PROCESSING' }
        ├─ Rotate SG90 servo (0° for locked, 90° for unlocked)
        ├─ Update LEDs & OLED display
        ├─ Mark command: { status: 'EXECUTED', executedAt: now }
        ├─ Update /status node: { isLocked: true, lastProcessedCommandId: 'cmd_123' }
        └─ Append to /events node: { title: 'Remote Lock', severity: 'normal' }
```
