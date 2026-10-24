#include "cloud.h"
#include "config.h"

#if __has_include("secrets.h")
#include "secrets.h"
#define CLOUD_HAS_SECRETS 1
#else
#define CLOUD_HAS_SECRETS 0
#endif

#if CLOUD_ENABLED && CLOUD_HAS_SECRETS

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <sys/time.h>
#include <time.h>

// ======================== QUEUES / SHARED STATE ========================

struct CloudEvent {
  char    type[32];
  char    method[12];
  int64_t timestampMs;   // 0 = let Firebase stamp it
};

struct CloudResult {
  CloudCommand cmd;
  bool         executed;
  char         reason[24];
};

static QueueHandle_t eventQueue  = nullptr;   // main -> cloud
static QueueHandle_t cmdQueue    = nullptr;   // cloud -> main
static QueueHandle_t resultQueue = nullptr;   // main -> cloud

static portMUX_TYPE  stateMux   = portMUX_INITIALIZER_UNLOCKED;
static CloudState    sharedState;
static volatile bool stateDirty = false;
static volatile bool online     = false;

// Main-loop side copy, used to detect changes cheaply
static CloudState lastPublished;
static bool       publishedOnce = false;

// ======================== CLOUD-TASK STATE ========================

static WiFiClientSecure dbTls;
static HTTPClient       dbHttp;

static String   idToken;
static String   myUid;
static uint32_t tokenObtainedAt = 0;
static uint32_t nextAuthAttempt = 0;

static bool     accessOk         = false;
static uint32_t lastAccessCheck  = 0;
static uint32_t nextAccessRetry  = 0;
static String   ownerUid;
static String   deviceUid;
static JsonDocument authorizedUsers;

static uint32_t lastStatusWrite = 0;
static uint32_t lastPoll        = 0;
static bool     everOnline      = false;
static String   lastProcessedCommandId;

static bool     timeStarted = false;

// Firebase server time = millis() + serverOffsetMs, learned from each status write.
// Commands are stamped with server time, so this is the clock their age is checked against.
static int64_t  serverOffsetMs = 0;
static bool     haveServerTime = false;

#define HANDLED_IDS 16
static char handledIds[HANDLED_IDS][40];
static int  handledNext = 0;

// ======================== HELPERS ========================

static int64_t nowEpochMs() {
  bool    have;
  int64_t offset;
  portENTER_CRITICAL(&stateMux);
  have   = haveServerTime;
  offset = serverOffsetMs;
  portEXIT_CRITICAL(&stateMux);
  if (have) return (int64_t)millis() + offset;

  struct timeval tv;                       // fall back to NTP if it got through
  gettimeofday(&tv, nullptr);
  if (tv.tv_sec < 1700000000) return 0;    // no clock yet
  return (int64_t)tv.tv_sec * 1000 + tv.tv_usec / 1000;
}

static const char* reasonText(const char* code) {
  if (!strcmp(code, "BLOCKED_DOOR_OPEN"))  return "The door is open, so it was not locked";
  if (!strcmp(code, "ALARM_PIN_REQUIRED")) return "The alarm is on. Only the keypad PIN can stop it";
  if (!strcmp(code, "ALARM_ACTIVE"))       return "The alarm is on. Enter the PIN on the keypad first";
  if (!strcmp(code, "EXPIRED"))            return "The request arrived too late and was ignored";
  if (!strcmp(code, "UNAUTHORIZED"))       return "The account is not allowed to control this lock";
  if (!strcmp(code, "MALFORMED"))          return "The request was invalid";
  return code;
}

static bool wasHandled(const char* id) {
  for (int i = 0; i < HANDLED_IDS; i++) {
    if (strcmp(handledIds[i], id) == 0) return true;
  }
  return false;
}

static void markHandled(const char* id) {
  strlcpy(handledIds[handledNext], id, sizeof(handledIds[0]));
  handledNext = (handledNext + 1) % HANDLED_IDS;
}

static void pushEvent(const char* type, const char* method) {
  CloudEvent ev = {};
  strlcpy(ev.type, type, sizeof(ev.type));
  strlcpy(ev.method, method, sizeof(ev.method));
  ev.timestampMs = nowEpochMs();
  xQueueSend(eventQueue, &ev, 0);   // drop if full rather than block
}

static const char* methodLabel(const char* method) {
  if (!strcmp(method, "keypad")) return "Keypad";
  if (!strcmp(method, "button")) return "Inside button";
  if (!strcmp(method, "app"))    return "LocKify app";
  if (!strcmp(method, "auto"))   return "Auto-lock";
  if (!strcmp(method, "sensor")) return "Door sensor";
  return "Lock";
}

// Human-readable text the app shows in the activity history
static void describeEvent(const CloudEvent& ev, const char*& title, String& description, const char*& severity) {
  const char* t = ev.type;
  const char* m = ev.method;
  severity = "normal";

  if (!strcmp(t, "unlock")) {
    title = "Door unlocked";
    if (!strcmp(m, "keypad"))      description = "Unlocked with the keypad PIN";
    else if (!strcmp(m, "button")) description = "Unlocked from the inside button";
    else if (!strcmp(m, "app"))    description = "Unlocked remotely from the app";
    else                           description = "Unlocked";
  } else if (!strcmp(t, "lock")) {
    title = "Door locked";
    if (!strcmp(m, "auto"))        description = "Locked automatically " + String(AUTO_LOCK_DELAY / 1000) + " s after the door closed";
    else if (!strcmp(m, "keypad")) description = "Locked with the A key";
    else if (!strcmp(m, "button")) description = "Locked from the inside button";
    else if (!strcmp(m, "app"))    description = "Locked remotely from the app";
    else                           description = "Locked";
  } else if (!strcmp(t, "failed_attempt")) {
    title = "Wrong PIN entered";
    description = "Someone entered an incorrect PIN on the keypad";
    severity = "warning";
  } else if (!strcmp(t, "lockout")) {
    title = "Keypad locked out";
    description = String(MAX_PIN_ATTEMPTS) + " wrong PINs in a row. Keypad disabled for " + String(LOCKOUT_TIME / 1000) + " s";
    severity = "warning";
  } else if (!strcmp(t, "door_opened")) {
    title = "Door opened";
    description = "The door sensor reported the door open";
  } else if (!strcmp(t, "door_closed")) {
    title = "Door closed";
    description = "The door sensor reported the door closed";
  } else if (!strcmp(t, "burglar_alarm")) {
    title = "Break-in alarm";
    description = "Door opened while locked. Siren on until the PIN is entered";
    severity = "alarm";
  } else if (!strcmp(t, "alarm_cleared")) {
    title = "Alarm stopped";
    description = String("Alarm cleared via ") + methodLabel(m);
  } else if (!strcmp(t, "door_warning")) {
    title = "Door left open";
    description = "Door open for more than " + String(DOOR_WARNING_TIME / 1000) + " s";
    severity = "warning";
  } else if (!strcmp(t, "pin_changed")) {
    title = "Keypad PIN changed";
    description = "A new PIN was saved on the lock";
  } else if (!strcmp(t, "lock_online")) {
    title = "Lock online";
    description = "Connected to Wi-Fi and the cloud";
  } else if (!strcmp(t, "lock_reconnected")) {
    title = "Lock back online";
    description = "Reconnected after losing the connection";
    severity = "warning";
  } else if (!strncmp(t, "rej_", 4)) {
    title = "Remote request rejected";
    description = reasonText(t + 4);
    severity = "warning";
  } else {
    title = "Lock event";
    description = t;
  }
}

// ======================== HTTP ========================

// One HTTPS request to the Realtime Database. Returns the HTTP status (<0 on network error).
static int dbRequest(const char* method, const String& path, const String& body,
                     String* response = nullptr, const char* query = "") {
  String url = String(FIREBASE_DATABASE_URL) + path + ".json?auth=" + idToken + query;
  if (!dbHttp.begin(dbTls, url)) return -1;
  dbHttp.setConnectTimeout(8000);
  dbHttp.setTimeout(8000);
  dbHttp.addHeader("Content-Type", "application/json");

  int code = dbHttp.sendRequest(method, body);
  String payload = code > 0 ? dbHttp.getString() : String();
  dbHttp.end();

  if (code == 401) {
    if (payload.indexOf("expired") >= 0 || payload.indexOf("token") >= 0) {
      idToken = "";              // force a fresh sign-in
    }
  }
  if (code < 0) {
    Serial.println("[CLOUD] Network error: " + HTTPClient::errorToString(code));
  }
  if (response) *response = payload;
  return code;
}

static bool signIn() {
  WiFiClientSecure tls;
  tls.setInsecure();
  HTTPClient http;
  String url = String("https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=") + FIREBASE_API_KEY;
  if (!http.begin(tls, url)) return false;
  http.setConnectTimeout(8000);
  http.setTimeout(8000);
  http.addHeader("Content-Type", "application/json");

  JsonDocument req;
  req["email"] = DEVICE_EMAIL;
  req["password"] = DEVICE_PASSWORD;
  req["returnSecureToken"] = true;
  String body;
  serializeJson(req, body);

  int code = http.POST(body);
  String payload = code > 0 ? http.getString() : String();
  http.end();

  if (code != 200) {
    JsonDocument err;
    String msg = "HTTP " + String(code);
    if (!deserializeJson(err, payload)) msg = err["error"]["message"] | msg.c_str();
    Serial.println("[CLOUD] Sign-in failed: " + msg);
    return false;
  }

  JsonDocument res;
  if (deserializeJson(res, payload)) return false;
  idToken = res["idToken"].as<String>();
  myUid   = res["localId"].as<String>();
  tokenObtainedAt = millis();
  Serial.println("[CLOUD] Signed in to Firebase (uid " + myUid + ")");
  return idToken.length() > 0;
}

// Reads the lock's metadata so commands can be checked against the owner and allowed users.
// Returns 1 when this account may act for the lock, 0 on a temporary error, -1 when denied.
static int refreshAccess() {
  String payload;
  int code = dbRequest("GET", "/devices/" DEVICE_ID "/metadata", "", &payload);
  if (code == 401 || code == 403) {
    Serial.println("[CLOUD] No access to /devices/" DEVICE_ID " yet. Sign in to the LocKify app once");
    Serial.println("[CLOUD] as the owner, then add this lock's UID in the app (Settings > Lock hardware).");
    Serial.println("[CLOUD] This lock's UID: " + myUid);
    return -1;
  }
  if (code != 200) return 0;

  JsonDocument meta;
  if (deserializeJson(meta, payload)) return 0;
  if (meta.isNull()) return -1;
  ownerUid  = meta["ownerUid"]  | "";
  deviceUid = meta["deviceUid"] | "";
  authorizedUsers.clear();
  authorizedUsers.set(meta["authorizedUsers"]);

  if (myUid != ownerUid && myUid != deviceUid) {
    Serial.println("[CLOUD] This account is not linked to the lock. Add UID " + myUid + " in the app.");
    return -1;
  }

  // Keep the firmware version in the app current (owner-only path, so ignore failures)
  if (myUid == ownerUid) {
    dbRequest("PATCH", "/devices/" DEVICE_ID "/metadata", "{\"firmwareVersion\":\"" FIRMWARE_VERSION "\"}");
  }
  return 1;
}

static bool isAllowedUser(const char* uid) {
  if (!uid || !*uid) return false;
  if (ownerUid == uid) return true;
  return authorizedUsers[uid].is<bool>() && authorizedUsers[uid].as<bool>();
}

// ======================== STATUS / EVENTS / COMMANDS ========================

static bool writeStatus() {
  CloudState s;
  bool changed;
  portENTER_CRITICAL(&stateMux);
  s = sharedState;
  changed = stateDirty;
  stateDirty = false;
  portEXIT_CRITICAL(&stateMux);

  JsonDocument doc;
  doc["isLocked"]           = s.isLocked;
  doc["doorClosed"]         = s.doorClosed;
  doc["burglarAlarmActive"] = s.burglarAlarmActive;
  doc["isLockout"]          = s.isLockout;
  doc["lastMethod"]         = s.lastMethod;
  doc["isOnline"]           = true;
  doc["firmwareVersion"]    = FIRMWARE_VERSION;
  if (changed || !online) doc["lastUpdated"][".sv"] = "timestamp";
  doc["lastHeartbeat"][".sv"] = "timestamp";
  if (lastProcessedCommandId.length()) doc["lastProcessedCommandId"] = lastProcessedCommandId;

  String body, response;
  serializeJson(doc, body);
  uint32_t sentAt = millis();
  int code = dbRequest("PATCH", "/devices/" DEVICE_ID "/status", body, &response);
  if (code != 200) {
    if (changed) {
      portENTER_CRITICAL(&stateMux);
      stateDirty = true;             // try again next round
      portEXIT_CRITICAL(&stateMux);
    }
    return false;
  }
  lastStatusWrite = millis();

  // The reply contains the server's resolved timestamp: use it as our clock
  JsonDocument res;
  if (!deserializeJson(res, response) && res["lastHeartbeat"].is<int64_t>()) {
    int64_t serverNow = res["lastHeartbeat"].as<int64_t>();
    uint32_t midpoint = sentAt + (millis() - sentAt) / 2;
    portENTER_CRITICAL(&stateMux);
    serverOffsetMs = serverNow - (int64_t)midpoint;
    haveServerTime = true;
    portEXIT_CRITICAL(&stateMux);
  }
  return true;
}

static void sendEvents() {
  CloudEvent ev;
  for (int i = 0; i < 4 && xQueuePeek(eventQueue, &ev, 0) == pdTRUE; i++) {
    const char* title;
    const char* severity;
    String description;
    describeEvent(ev, title, description, severity);

    JsonDocument doc;
    doc["type"]        = ev.type;
    doc["title"]       = title;
    doc["description"] = description;
    doc["method"]      = methodLabel(ev.method);
    doc["severity"]    = severity;
    doc["gsmAlertSent"] = false;
    if (ev.timestampMs > 0) doc["timestamp"] = ev.timestampMs;
    else                    doc["timestamp"][".sv"] = "timestamp";

    String body;
    serializeJson(doc, body);
    int code = dbRequest("POST", "/devices/" DEVICE_ID "/events", body);
    if (code != 200) return;          // keep it queued and retry later
    xQueueReceive(eventQueue, &ev, 0);
  }
}

static bool setCommandStatus(const char* id, const char* status, const char* reason) {
  JsonDocument doc;
  doc["status"] = status;
  if (strcmp(status, "PROCESSING") != 0) doc["executedAt"][".sv"] = "timestamp";
  if (reason && *reason) doc["failureReason"] = reason;
  String body;
  serializeJson(doc, body);
  return dbRequest("PATCH", String("/devices/" DEVICE_ID "/commands/") + id, body) == 200;
}

static void reject(const char* id, const char* reason) {
  Serial.println(String("[CLOUD] Rejected command ") + id + ": " + reason);
  if (setCommandStatus(id, "REJECTED", reason)) {
    markHandled(id);
    char type[32];
    snprintf(type, sizeof(type), "rej_%s", reason);
    pushEvent(type, "app");
  }
}

static bool parseAction(const char* s, CloudAction& out) {
  if (!strcmp(s, "LOCK"))        { out = CLOUD_LOCK;        return true; }
  if (!strcmp(s, "UNLOCK"))      { out = CLOUD_UNLOCK;      return true; }
  if (!strcmp(s, "CLEAR_ALARM")) { out = CLOUD_CLEAR_ALARM; return true; }
  if (!strcmp(s, "PING"))        { out = CLOUD_PING;        return true; }
  return false;
}

static void pollCommands() {
  String payload;
  // The newest few commands are enough: each one is handled within a second or two
  int code = dbRequest("GET", "/devices/" DEVICE_ID "/commands", "", &payload,
                       "&orderBy=%22%24key%22&limitToLast=5");
  if (code != 200 || payload == "null") return;

  JsonDocument doc;
  if (deserializeJson(doc, payload) || !doc.is<JsonObject>()) return;

  int64_t now = nowEpochMs();
  for (JsonPair kv : doc.as<JsonObject>()) {
    const char* id = kv.key().c_str();
    JsonObject c = kv.value().as<JsonObject>();
    const char* status = c["status"] | "";
    if (strcmp(status, "PENDING") != 0) continue;     // already processed by us or the app
    if (wasHandled(id)) continue;                     // never run the same command twice
    if (strlen(id) >= sizeof(CloudCommand::id)) { reject(id, "MALFORMED"); continue; }

    CloudAction action;
    const char* actionStr   = c["action"] | "";
    const char* commandId   = c["commandId"] | "";
    const char* requestedBy = c["requestedBy"] | "";
    if (!parseAction(actionStr, action) || strcmp(commandId, id) != 0 || !c["requestedAt"].is<int64_t>()) {
      reject(id, "MALFORMED");
      continue;
    }
    if (!isAllowedUser(requestedBy)) {
      // Someone may have just been given access: re-read the list once before refusing
      refreshAccess();
      lastAccessCheck = millis();
      if (!isAllowedUser(requestedBy)) {
        reject(id, "UNAUTHORIZED");
        continue;
      }
    }
    int64_t requestedAt = c["requestedAt"].as<int64_t>();
    int64_t age = now - requestedAt;
    if (age > COMMAND_MAX_AGE_MS || age < -5000) {
      reject(id, "EXPIRED");
      continue;
    }

    // Claim it before acting, so a reconnect can never run it again
    if (!setCommandStatus(id, "PROCESSING", nullptr)) continue;
    markHandled(id);

    CloudCommand cmd = {};
    strlcpy(cmd.id, id, sizeof(cmd.id));
    cmd.action = action;
    Serial.println(String("[CLOUD] Command ") + id + ": " + actionStr);
    if (xQueueSend(cmdQueue, &cmd, 0) != pdTRUE) {
      setCommandStatus(id, "FAILED", "LOCK_BUSY");
    }
  }
}

static void sendResults() {
  CloudResult r;
  while (xQueuePeek(resultQueue, &r, 0) == pdTRUE) {
    if (!setCommandStatus(r.cmd.id, r.executed ? "EXECUTED" : "REJECTED", r.executed ? nullptr : r.reason)) return;
    xQueueReceive(resultQueue, &r, 0);
    lastProcessedCommandId = r.cmd.id;
    if (!r.executed) {
      char type[32];
      snprintf(type, sizeof(type), "rej_%s", r.reason);
      pushEvent(type, "app");
    }
    portENTER_CRITICAL(&stateMux);
    stateDirty = true;               // report lastProcessedCommandId
    portEXIT_CRITICAL(&stateMux);
  }
}

static void goOffline() {
  if (online) {
    online = false;
    Serial.println("[CLOUD] Lost connection to the cloud");
  }
}

// ======================== TASK ========================

static void cloudTask(void*) {
  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.println("[CLOUD] Connecting to Wi-Fi \"" WIFI_SSID "\"...");
  uint32_t lastWifiKick = millis();

  // Certificate checks are skipped to keep setup simple; traffic is still encrypted.
  dbTls.setInsecure();
  dbHttp.setReuse(true);

  for (;;) {
    if (WiFi.status() != WL_CONNECTED) {
      goOffline();
      if (millis() - lastWifiKick > 20000) {
        lastWifiKick = millis();
        Serial.println("[CLOUD] Wi-Fi not connected, retrying...");
        WiFi.disconnect();
        WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
      }
      vTaskDelay(pdMS_TO_TICKS(500));
      continue;
    }

    if (!timeStarted) {
      Serial.println("[CLOUD] Wi-Fi connected, IP " + WiFi.localIP().toString());
      configTime(0, 0, "pool.ntp.org", "time.google.com");
      timeStarted = true;
    }

    // Sign in (and again every 50 minutes, before the 1-hour token expires)
    if (idToken.length() == 0 || millis() - tokenObtainedAt > 50UL * 60UL * 1000UL) {
      if ((int32_t)(millis() - nextAuthAttempt) < 0) { vTaskDelay(pdMS_TO_TICKS(250)); continue; }
      if (!signIn()) {
        goOffline();
        nextAuthAttempt = millis() + 30000;
        continue;
      }
      accessOk = false;
      nextAccessRetry = 0;
    }

    // Make sure this account may act for the lock; re-read the allowed users each minute
    if (!accessOk || millis() - lastAccessCheck > 60000) {
      if (!accessOk && (int32_t)(millis() - nextAccessRetry) < 0) { vTaskDelay(pdMS_TO_TICKS(250)); continue; }
      int access = refreshAccess();
      lastAccessCheck = millis();
      if (access == 1) {
        accessOk = true;
      } else if (access == -1 || !accessOk) {
        accessOk = false;
        goOffline();
        nextAccessRetry = millis() + 30000;
        continue;
      }
    }

    bool dirty = stateDirty;
    if (dirty || millis() - lastStatusWrite >= HEARTBEAT_INTERVAL_MS) {
      if (writeStatus()) {
        if (!online) {
          online = true;
          Serial.println("[CLOUD] Online, reporting status");
          pushEvent(everOnline ? "lock_reconnected" : "lock_online", "system");
          everOnline = true;
        }
      } else {
        goOffline();
      }
    }

    sendResults();
    sendEvents();

    // Commands need real time to check their age, so wait until we have a clock
    if (nowEpochMs() > 0 && millis() - lastPoll >= COMMAND_POLL_MS) {
      lastPoll = millis();
      pollCommands();
    }

    vTaskDelay(pdMS_TO_TICKS(50));
  }
}

// ======================== PUBLIC API ========================

void cloudBegin() {
  eventQueue  = xQueueCreate(16, sizeof(CloudEvent));
  cmdQueue    = xQueueCreate(4, sizeof(CloudCommand));
  resultQueue = xQueueCreate(4, sizeof(CloudResult));
  memset(handledIds, 0, sizeof(handledIds));
  xTaskCreatePinnedToCore(cloudTask, "cloud", 16384, nullptr, 1, nullptr, CLOUD_TASK_CORE);
  Serial.println("[CLOUD] Cloud link starting (device " DEVICE_ID ")");
}

void cloudPublishState(const CloudState& state) {
  if (publishedOnce && memcmp(&state, &lastPublished, sizeof(CloudState)) == 0) return;
  lastPublished = state;
  publishedOnce = true;
  portENTER_CRITICAL(&stateMux);
  sharedState = state;
  stateDirty = true;
  portEXIT_CRITICAL(&stateMux);
}

void cloudLogEvent(const char* type, const char* method) {
  if (!eventQueue) return;
  pushEvent(type, method);
}

bool cloudNextCommand(CloudCommand& out) {
  return cmdQueue && xQueueReceive(cmdQueue, &out, 0) == pdTRUE;
}

void cloudCommandDone(const CloudCommand& cmd, bool executed, const char* reason) {
  CloudResult r = {};
  r.cmd = cmd;
  r.executed = executed;
  strlcpy(r.reason, reason ? reason : "", sizeof(r.reason));
  xQueueSend(resultQueue, &r, 0);
}

bool cloudOnline() { return online; }

#else  // ------------------- cloud disabled -------------------

void cloudBegin() {
#if CLOUD_ENABLED
  Serial.println("[CLOUD] secrets.h not found - running offline. Copy secrets.example.h to secrets.h.");
#else
  Serial.println("[CLOUD] Cloud disabled in config.h - running offline.");
#endif
}
void cloudPublishState(const CloudState&) {}
void cloudLogEvent(const char*, const char*) {}
bool cloudNextCommand(CloudCommand&) { return false; }
void cloudCommandDone(const CloudCommand&, bool, const char*) {}
bool cloudOnline() { return false; }

#endif
