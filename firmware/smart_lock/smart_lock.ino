// ============================================================
//  ESA SMART DOOR LOCK  v3.0  (SH1106 / U8g2 + LocKify cloud)
//  ESP32 + 1.3" SH1106 OLED + Keypad + Servo
//
//  Keypad Controls
//  ---------------
//  0-9  PIN digits           A  Lock door
//  #    Enter / Submit       B  Backspace
//  *    Clear / Cancel       C  Change PIN
//  D    Show door status
//
//  Door button (GPIO 5): each press toggles door open/closed
//  Inside button (GPIO 16): unlock / lock without PIN
//
//  Burglar alarm: if the door opens while the lock is LOCKED,
//  a siren sounds. Only the correct PIN stops it.
//
//  Cloud (v3.0): reports status/events to Firebase and accepts
//  lock/unlock from the LocKify app (see cloud.cpp). Everything
//  above keeps working when Wi-Fi or the internet is down.
// ============================================================

#include <Wire.h>
#include <U8g2lib.h>
#include <Keypad.h>
#include <ESP32Servo.h>
#include <Preferences.h>

#include "config.h"
#include "cloud.h"

// ======================== OBJECTS ========================

U8G2_SH1106_128X64_NONAME_F_HW_I2C u8g2(U8G2_R0, U8X8_PIN_NONE, OLED_SCL, OLED_SDA);

Servo doorServo;
Preferences preferences;

const byte ROWS = 4;
const byte COLS = 4;
char keys[ROWS][COLS] = {
  {'1', '2', '3', 'A'},
  {'4', '5', '6', 'B'},
  {'7', '8', '9', 'C'},
  {'*', '0', '#', 'D'}
};
byte rowPins[ROWS] = { KP_R1, KP_R2, KP_R3, KP_R4 };
byte colPins[COLS] = { KP_C1, KP_C2, KP_C3, KP_C4 };
Keypad keypad = Keypad(makeKeymap(keys), rowPins, colPins, ROWS, COLS);

// ======================== STATE ========================

bool isLocked            = true;
bool doorClosed          = true;
bool doorWasOpened       = false;
String lastMethod        = "keypad";   // what last locked/unlocked the door (shown in the app)

String correctPIN = DEFAULT_PIN;
String enteredPIN = "";
String newPIN     = "";
String confirmPIN = "";

PinChangeMode pinState = PIN_NORMAL;

int  failedAttempts  = 0;
bool lockout         = false;
unsigned long lockoutStart = 0;

unsigned long doorClosedTime       = 0;
bool          autoLockTimerRunning = false;

unsigned long doorOpenedTime    = 0;
bool          doorWarningActive = false;

// Inside button debounce
bool          lastButtonReading = HIGH;
bool          buttonPressed     = false;
unsigned long lastDebounceTime  = 0;

// Door button debounce (toggle)
bool          doorLastReading  = HIGH;
bool          doorBtnHeld      = false;
unsigned long doorLastDebounce = 0;

bool          timedMsgActive   = false;
unsigned long timedMsgStart    = 0;
unsigned long timedMsgDuration = 0;

#define TONE_QUEUE_SIZE 8
struct ToneStep { uint16_t freq; uint16_t durMs; };
ToneStep      toneQueue[TONE_QUEUE_SIZE];
int           toneQueueCount = 0;
int           toneCurrentIdx = -1;
unsigned long toneStartTime  = 0;

bool          servoAttached    = false;
unsigned long servoDetachAt    = 0;
int           servoTarget      = LOCKED_POSITION;
unsigned long lastServoRefresh = 0;

// Burglar alarm state
bool          burglarAlarmActive = false;   // stays true until a valid PIN is entered
bool          burglarSounding    = false;   // siren currently sounding
bool          burglarHigh        = false;
unsigned long burglarStartedAt   = 0;
unsigned long burglarToggledAt   = 0;
unsigned long lockedAt           = 0;       // when the lock last locked

// ======================== FORWARD DECLARATIONS ========================

void restoreDefaultScreen();

// ===================== SERVO =====================

void servoBegin() {
  // Reserve PWM timers for the servo so tone() can't clash with it
  ESP32PWM::allocateTimer(2);
  ESP32PWM::allocateTimer(3);
  doorServo.setPeriodHertz(50);
}

void moveServo(int pos) {
  if (!servoAttached) {
    doorServo.attach(SERVO_PIN, 500, 2400);
    servoAttached = true;
  }
  servoTarget = pos;
  doorServo.write(pos);
  servoDetachAt    = millis() + SERVO_MOVE_TIME;
  lastServoRefresh = millis();
  Serial.println("[SERVO] -> " + String(pos) + " deg");
}

void servoUpdate() {
#if SERVO_AUTO_DETACH
  if (servoAttached && (long)(millis() - servoDetachAt) > 0) {
    doorServo.detach();
    servoAttached = false;
  }
#endif
}

// Re-send the target position now and then, so a power glitch
// can't leave the servo in the wrong position for long.
void servoRefresh() {
#if SERVO_REFRESH_MS > 0
  if (servoAttached && millis() - lastServoRefresh >= SERVO_REFRESH_MS) {
    lastServoRefresh = millis();
    doorServo.write(servoTarget);
  }
#endif
}

// ===================== NON-BLOCKING BUZZER =====================

void buzzerClear() {
#if BUZZER_ENABLED
  noTone(BUZZER_PIN);
#endif
  toneQueueCount = 0;
  toneCurrentIdx = -1;
}

void buzzerEnqueue(uint16_t freq, uint16_t dur) {
  if (toneQueueCount < TONE_QUEUE_SIZE) {
    toneQueue[toneQueueCount++] = { freq, dur };
  }
}

void buzzerStartNext() {
#if BUZZER_ENABLED
  if (toneCurrentIdx < 0) toneCurrentIdx = 0;
  if (toneCurrentIdx >= toneQueueCount) {
    toneCurrentIdx = -1;
    toneQueueCount = 0;
    return;
  }
  ToneStep& t = toneQueue[toneCurrentIdx];
  if (t.freq > 0) tone(BUZZER_PIN, t.freq);
  else            noTone(BUZZER_PIN);
  toneStartTime = millis();
#endif
}

void buzzerUpdate() {
#if BUZZER_ENABLED
  if (toneCurrentIdx < 0) return;
  if (millis() - toneStartTime >= toneQueue[toneCurrentIdx].durMs) {
    noTone(BUZZER_PIN);
    toneCurrentIdx++;
    buzzerStartNext();
  }
#endif
}

void playSuccess()  { buzzerClear(); buzzerEnqueue(1200, 120); buzzerEnqueue(0, 30); buzzerEnqueue(1800, 120); buzzerStartNext(); }
void playError()    { buzzerClear(); buzzerEnqueue(300,  400); buzzerStartNext(); }
void playLock()     { buzzerClear(); buzzerEnqueue(1000, 100); buzzerStartNext(); }

// Gentle "door left open" reminder: a few short, low-pitched beeps (plays once)
void playWarning() {
  buzzerClear();
  for (int i = 0; i < WARN_BEEPS; i++) {
    buzzerEnqueue(WARN_FREQ, WARN_BEEP_MS);
    if (i < WARN_BEEPS - 1) buzzerEnqueue(0, WARN_GAP_MS);
  }
  buzzerStartNext();
}

// ===================== DISPLAY HELPERS (U8g2) =====================
// size 1 -> small font (6x10), size 2 -> big font (10x20)

void drawCenteredText(String text, int y, int size) {
  const uint8_t* font = (size >= 2) ? u8g2_font_10x20_tr : u8g2_font_6x10_tr;
  u8g2.setFont(font);

  // If big text doesn't fit, fall back to the small font
  if (size >= 2 && u8g2.getStrWidth(text.c_str()) > SCREEN_WIDTH) {
    size = 1;
    u8g2.setFont(u8g2_font_6x10_tr);
  }

  int textWidth = u8g2.getStrWidth(text.c_str());
  int x = (SCREEN_WIDTH - textWidth) / 2;
  if (x < 0) x = 0;

  int baseline = y + ((size >= 2) ? 16 : 8);
  u8g2.drawStr(x, baseline, text.c_str());
}

void showStatus(String title, String message) {
  u8g2.clearBuffer();
  if (title.length() > 10)
    drawCenteredText(title, 12, 1);
  else
    drawCenteredText(title, 8, 2);
  u8g2.drawLine(10, 32, 117, 32);
  drawCenteredText(message, 42, 1);
  u8g2.sendBuffer();
}

void showPINEntry(String title, String pin) {
  u8g2.clearBuffer();
  drawCenteredText(title, 4, 1);
  u8g2.drawLine(10, 18, 117, 18);

  String masked = "";
  for (unsigned int i = 0; i < pin.length(); i++) masked += "* ";
  masked.trim();

  drawCenteredText(masked.length() > 0 ? masked : "----", 26, 2);
  drawCenteredText("[#] OK   [*] CLEAR", 52, 1);
  u8g2.sendBuffer();
}

void showTimed(String title, String message, unsigned long duration) {
  showStatus(title, message);
  timedMsgActive   = true;
  timedMsgStart    = millis();
  timedMsgDuration = duration;
}

void timedMsgUpdate() {
  if (!timedMsgActive) return;
  if (millis() - timedMsgStart >= timedMsgDuration) {
    timedMsgActive = false;
    restoreDefaultScreen();
  }
}

// ===================== DEFAULT SCREEN =====================

void restoreDefaultScreen() {
  if (lockout) {
    showStatus("LOCKOUT", "Wait...");
    return;
  }

  switch (pinState) {
    case PIN_VERIFY_OLD:   showPINEntry("OLD PIN", enteredPIN); return;
    case PIN_ENTER_NEW:    showPINEntry("NEW PIN", newPIN);     return;
    case PIN_CONFIRM_NEW:  showPINEntry("CONFIRM", confirmPIN); return;
    default: break;
  }

  if (burglarAlarmActive) {
    showStatus("INTRUDER!", "Enter PIN to stop");
    return;
  }

  if (isLocked)
    showStatus("LOCKED", "Enter PIN");
  else
    showStatus("UNLOCKED", doorClosed ? "Door Closed" : "Door Opened");
}

// ===================== NVS STORAGE =====================

void loadPIN() {
  Serial.println("[NVS] Reading saved PIN...");

  if (!preferences.begin(NVS_NAMESPACE, true)) {
    Serial.println("[NVS] ERROR: Could not open Preferences.");
    correctPIN = DEFAULT_PIN;
    return;
  }

  String storedPIN = preferences.getString(NVS_KEY_PIN, "");
  preferences.end();

  correctPIN = (storedPIN.length() >= MIN_PIN_LENGTH) ? storedPIN : DEFAULT_PIN;
  Serial.println("[NVS] PIN loaded (" + String(correctPIN.length()) + " digits)");
  cloudSetCurrentPin(correctPIN.c_str());
}

void savePIN(String pin) {
  Serial.println("[NVS] Saving new PIN...");
  if (!preferences.begin(NVS_NAMESPACE, false)) {
    Serial.println("[NVS] ERROR: Could not open for writing.");
    return;
  }
  preferences.putString(NVS_KEY_PIN, pin);
  preferences.end();
  correctPIN = pin;
  Serial.println("[NVS] PIN saved successfully");
}

// ===================== SERIAL EVENT LOG =====================

void logEvent(String event, String method) {
  Serial.println("[EVENT] " + event + " (" + method + ")  locked="
                 + String(isLocked ? "yes" : "no") + "  door="
                 + String(doorClosed ? "closed" : "open") + "  uptime="
                 + String(millis() / 1000) + "s");
  if (event != "status") cloudLogEvent(event.c_str(), method.c_str());
}

// ===================== LEDs =====================

void updateLEDs() {
  digitalWrite(RED_LED_PIN,  isLocked ? HIGH : LOW);
  digitalWrite(BLUE_LED_PIN, isLocked ? LOW  : HIGH);
}

// ===================== BURGLAR ALARM =====================

void sirenTone(int freq) {
#if BUZZER_ENABLED
  tone(BUZZER_PIN, freq);
#endif
}

void sirenOff() {
#if BUZZER_ENABLED
  noTone(BUZZER_PIN);
#endif
}

void triggerBurglarAlarm() {
  if (burglarAlarmActive) return;

  burglarAlarmActive = true;
  burglarSounding    = true;
  burglarHigh        = true;
  burglarStartedAt   = millis();
  burglarToggledAt   = millis();

  buzzerClear();
  sirenTone(BURGLAR_FREQ_HIGH);

  Serial.println("[ALARM] INTRUDER! Door opened while locked");
  showStatus("INTRUDER!", "Enter PIN to stop");
  logEvent("burglar_alarm", "sensor");
}

void clearBurglarAlarm(String method) {
  if (!burglarAlarmActive) return;

  burglarAlarmActive = false;
  if (burglarSounding) {
    burglarSounding = false;
    sirenOff();
  }
  updateLEDs();
  Serial.println("[ALARM] Alarm cleared");
  logEvent("alarm_cleared", method);
}

void handleBurglarAlarm() {
  if (!burglarAlarmActive) return;

  if (burglarSounding) {
    if (millis() - burglarStartedAt >= BURGLAR_ALARM_DURATION) {
      // Siren time is over; the alert stays on screen until the PIN is entered
      burglarSounding = false;
      sirenOff();
    } else if (millis() - burglarToggledAt >= BURGLAR_STEP_MS) {
      burglarToggledAt = millis();
      burglarHigh = !burglarHigh;
      sirenTone(burglarHigh ? BURGLAR_FREQ_HIGH : BURGLAR_FREQ_LOW);
    }
  }

  // Flash the red LED while the alarm is active
  bool on = ((millis() / 300) % 2) == 0;
  digitalWrite(RED_LED_PIN,  on ? HIGH : LOW);
  digitalWrite(BLUE_LED_PIN, LOW);
}

// ===================== LOCK CONTROL =====================

void unlockDoor(String method) {
  clearBurglarAlarm(method);    // a valid unlock disarms the alarm
  moveServo(UNLOCKED_POSITION);
  isLocked             = false;
  lastMethod           = method;
  doorWasOpened        = false;
  autoLockTimerRunning = false;
  doorWarningActive    = false;
  doorOpenedTime       = millis();   // restart the door-left-open timer
  updateLEDs();

  playSuccess();
  showStatus("UNLOCKED", doorClosed ? "Door Closed" : "Door Opened");
  logEvent("unlock", method);
}

// Returns false when the lock refused (alarm active or door open)
bool lockDoor(String method) {
  if (burglarAlarmActive) return false;   // nothing to do while the alarm is active

  if (!doorClosed) {
    Serial.println("[LOCK] BLOCKED - door is open");
    showTimed("DOOR OPEN", "Close Door First", TIMED_MSG_DEFAULT);
    playError();
    return false;
  }

  moveServo(LOCKED_POSITION);
  isLocked             = true;
  lastMethod           = method;
  lockedAt             = millis();   // alarm is armed after the grace period
  doorWasOpened        = false;
  autoLockTimerRunning = false;
  doorWarningActive    = false;
  updateLEDs();

  playLock();
  showStatus("LOCKED", "Enter PIN");
  logEvent("lock", method);
  return true;
}

// ===================== PIN CHECKING =====================

void checkPIN() {
  if (enteredPIN == correctPIN) {
    Serial.println("[PIN] ACCESS GRANTED");
    failedAttempts = 0;
    enteredPIN = "";
    unlockDoor("keypad");
  } else {
    failedAttempts++;
    Serial.println("[PIN] ACCESS DENIED (attempt "
                   + String(failedAttempts) + "/"
                   + String(MAX_PIN_ATTEMPTS) + ")");
    playError();
    logEvent("failed_attempt", "keypad");

    if (failedAttempts >= MAX_PIN_ATTEMPTS) {
      lockout      = true;
      lockoutStart = millis();
      showStatus("LOCKOUT", "Wait 10 Seconds");
      logEvent("lockout", "keypad");
    } else {
      showTimed("WRONG PIN", "Try Again", TIMED_MSG_DEFAULT);
    }
    enteredPIN = "";
  }
}

// ===================== PIN CHANGE FLOW =====================

void startChangePIN() {
  if (burglarAlarmActive) {
    showTimed("ALARM ACTIVE", "Enter PIN to stop", TIMED_MSG_DEFAULT);
    playError();
    return;
  }

  if (!isLocked) {
    showTimed("LOCK FIRST", "Press A to Lock", TIMED_MSG_DEFAULT);
    playError();
    return;
  }

  enteredPIN = "";
  newPIN     = "";
  confirmPIN = "";
  pinState   = PIN_VERIFY_OLD;
  showPINEntry("OLD PIN", "");
  Serial.println("[PIN] Change PIN started");
}

void verifyOldPIN() {
  if (enteredPIN == correctPIN) {
    Serial.println("[PIN] Old PIN correct");
    enteredPIN = "";
    newPIN     = "";
    pinState   = PIN_ENTER_NEW;
    showPINEntry("NEW PIN", "");
    playSuccess();
  } else {
    Serial.println("[PIN] Old PIN incorrect");
    playError();
    enteredPIN = "";
    pinState   = PIN_NORMAL;
    showTimed("WRONG PIN", "PIN Unchanged", TIMED_MSG_LONG);
  }
}

void startConfirmPIN() {
  if (newPIN.length() < MIN_PIN_LENGTH) {
    playError();
    newPIN   = "";
    pinState = PIN_ENTER_NEW;
    showTimed("TOO SHORT", "Min 4 Digits", TIMED_MSG_DEFAULT);
    return;
  }

  confirmPIN = "";
  pinState   = PIN_CONFIRM_NEW;
  showPINEntry("CONFIRM", "");
}

void finishPINChange() {
  if (newPIN == confirmPIN) {
    Serial.println("[PIN] PINs match - saving");
    savePIN(newPIN);
    cloudReportPinChanged(newPIN.c_str());
    playSuccess();
    pinState   = PIN_NORMAL;
    enteredPIN = "";
    newPIN     = "";
    confirmPIN = "";
    showTimed("PIN SAVED", "Update Complete", TIMED_MSG_LONG);
    logEvent("pin_changed", "keypad");
  } else {
    Serial.println("[PIN] PINs do not match");
    playError();
    pinState   = PIN_NORMAL;
    enteredPIN = "";
    newPIN     = "";
    confirmPIN = "";
    showTimed("MISMATCH", "PIN Unchanged", TIMED_MSG_LONG);
  }
}

void handlePINDigit(char key) {
  Serial.println("[KEY] [digit]");   // masked

  switch (pinState) {
    case PIN_VERIFY_OLD:
      if (enteredPIN.length() < MAX_PIN_LENGTH) enteredPIN += key;
      showPINEntry("OLD PIN", enteredPIN);
      break;
    case PIN_ENTER_NEW:
      if (newPIN.length() < MAX_PIN_LENGTH) newPIN += key;
      showPINEntry("NEW PIN", newPIN);
      break;
    case PIN_CONFIRM_NEW:
      if (confirmPIN.length() < MAX_PIN_LENGTH) confirmPIN += key;
      showPINEntry("CONFIRM", confirmPIN);
      break;
    case PIN_NORMAL:
      if (enteredPIN.length() < MAX_PIN_LENGTH) enteredPIN += key;
      showPINEntry("ENTER PIN", enteredPIN);
      break;
  }
}

// ===================== SENSORS / BUTTONS =====================

void handleDoorChange() {
  // Door opened while the lock is locked (and past the grace period) = break-in
  if (BURGLAR_ALARM_ENABLED && isLocked && !doorClosed &&
      (millis() - lockedAt) > BURGLAR_GRACE_MS) {
    triggerBurglarAlarm();
  }

  if (doorClosed) {
    Serial.println("[DOOR] Closed");
    doorWarningActive = false;

    if (!isLocked && doorWasOpened) {
      doorClosedTime       = millis();
      autoLockTimerRunning = true;
      Serial.println("[AUTO-LOCK] Timer started");
    }
    if (!isLocked && !timedMsgActive) {
      showStatus("UNLOCKED", "Door Closed");
    }
  } else {
    Serial.println("[DOOR] Opened");
    doorWasOpened        = true;
    autoLockTimerRunning = false;
    doorOpenedTime       = millis();

    if (!isLocked && !timedMsgActive) {
      showStatus("UNLOCKED", "Door Opened");
    }
  }

  logEvent(doorClosed ? "door_closed" : "door_opened", "sensor");
}

// Door "sensor" is a push-button: each press toggles open/closed
void readDoorSensor() {
  bool reading = digitalRead(DOOR_SENSOR_PIN);

  if (reading != doorLastReading) {
    doorLastDebounce = millis();
    doorLastReading  = reading;
  }

  if ((millis() - doorLastDebounce) > DEBOUNCE_DELAY) {
    if (reading == LOW && !doorBtnHeld) {
      doorBtnHeld = true;
      doorClosed  = !doorClosed;       // toggle
      handleDoorChange();
    } else if (reading == HIGH) {
      doorBtnHeld = false;
    }
  }
}

void readInsideButton() {
  bool reading = digitalRead(INSIDE_BUTTON_PIN);

  if (reading != lastButtonReading) {
    lastDebounceTime  = millis();
    lastButtonReading = reading;
  }

  if ((millis() - lastDebounceTime) > DEBOUNCE_DELAY) {
    if (reading == LOW && !buttonPressed) {
      buttonPressed = true;
      Serial.println("[BUTTON] Inside button pressed");

      if (burglarAlarmActive && !BURGLAR_BUTTON_CAN_SILENCE) {
        // During an alarm only the PIN can stop it
        showTimed("ALARM ACTIVE", "Enter PIN to stop", TIMED_MSG_DEFAULT);
        playError();
      } else if (isLocked) {
        unlockDoor("button");
      } else {
        lockDoor("button");
      }
    } else if (reading == HIGH) {
      buttonPressed = false;
    }
  }
}

// ===================== TIMER HANDLERS =====================

void handleLockout() {
  if (!lockout) return;
  if (millis() - lockoutStart >= LOCKOUT_TIME) {
    lockout        = false;
    failedAttempts = 0;
    enteredPIN     = "";
    Serial.println("[LOCKOUT] Finished");
    restoreDefaultScreen();
  }
}

void handleAutoLock() {
  if (!autoLockTimerRunning) return;
  if (!doorClosed) { autoLockTimerRunning = false; return; }
  if (millis() - doorClosedTime >= AUTO_LOCK_DELAY) {
    Serial.println("[AUTO-LOCK] Activated");
    autoLockTimerRunning = false;
    lockDoor("auto");
  }
}

// Door left open: show a warning and play a gentle reminder ONCE
void handleDoorWarning() {
  if (isLocked || doorClosed || doorWarningActive) return;
  if (millis() - doorOpenedTime >= DOOR_WARNING_TIME) {
    doorWarningActive = true;
    Serial.println("[WARNING] Door open too long!");
    showStatus("WARNING!", "Door Left Open");
    playWarning();
    logEvent("door_warning", "sensor");
  }
}

// ===================== CLOUD (LocKify app) =====================

// Leave the PIN-change wizard so the screen matches the new lock state
void cancelPinChange() {
  if (pinState == PIN_NORMAL) return;
  pinState   = PIN_NORMAL;
  enteredPIN = "";
  newPIN     = "";
  confirmPIN = "";
}

// A remote command goes through the same safety rules as the keypad and buttons.
void handleRemoteCommand(const CloudCommand& cmd) {
  switch (cmd.action) {
    case CLOUD_UNLOCK:
      if (burglarAlarmActive && !APP_CAN_CLEAR_ALARM) {
        // Only the PIN may stop an intrusion alarm (an unlock would silence it)
        showTimed("ALARM ACTIVE", "Enter PIN to stop", TIMED_MSG_DEFAULT);
        playError();
        cloudCommandDone(cmd, false, "ALARM_PIN_REQUIRED");
        return;
      }
      cancelPinChange();
      unlockDoor("app");
      cloudCommandDone(cmd, !isLocked, isLocked ? "UNLOCK_FAILED" : "");
      break;

    case CLOUD_LOCK: {
      cancelPinChange();
      bool ok = lockDoor("app");
      const char* reason = "";
      if (!ok) reason = burglarAlarmActive ? "ALARM_ACTIVE" : "BLOCKED_DOOR_OPEN";
      if (!ok && burglarAlarmActive) {
        showTimed("ALARM ACTIVE", "Enter PIN to stop", TIMED_MSG_DEFAULT);
        playError();
      }
      cloudCommandDone(cmd, ok, reason);
      break;
    }

    case CLOUD_CLEAR_ALARM:
      if (!APP_CAN_CLEAR_ALARM) {
        cloudCommandDone(cmd, false, "ALARM_PIN_REQUIRED");
      } else {
        clearBurglarAlarm("app");
        restoreDefaultScreen();
        cloudCommandDone(cmd, true, "");
      }
      break;

    case CLOUD_PING:
      cloudCommandDone(cmd, true, "");
      break;
  }
}

void handleCloud() {
  CloudState s = {};
  s.isLocked           = isLocked;
  s.doorClosed         = doorClosed;
  s.burglarAlarmActive = burglarAlarmActive;
  s.isLockout          = lockout;
  strlcpy(s.lastMethod, lastMethod.c_str(), sizeof(s.lastMethod));
  cloudPublishState(s);

  CloudCommand cmd;
  if (cloudNextCommand(cmd)) handleRemoteCommand(cmd);

  char incomingPin[16];
  if (cloudGetNewPin(incomingPin, sizeof(incomingPin))) {
    Serial.println(String("[CLOUD] New PIN received from app: ") + incomingPin);
    savePIN(incomingPin);
    showTimed("PIN UPDATED", "From App", TIMED_MSG_LONG);
    playSuccess();
  }
}

// ===================== KEYPAD HANDLER =====================

void handleKeypress(char key) {
  if (key >= '0' && key <= '9') {
    handlePINDigit(key);
    return;
  }

  Serial.println("[KEY] " + String(key));

  switch (key) {

    case '#':
      switch (pinState) {
        case PIN_NORMAL:
          if (enteredPIN.length() == 0) showTimed("EMPTY", "Enter PIN First", TIMED_MSG_DEFAULT);
          else checkPIN();
          break;
        case PIN_VERIFY_OLD:
          if (enteredPIN.length() == 0) showTimed("EMPTY", "Enter Old PIN", TIMED_MSG_DEFAULT);
          else verifyOldPIN();
          break;
        case PIN_ENTER_NEW:
          if (newPIN.length() == 0) showTimed("EMPTY", "Enter New PIN", TIMED_MSG_DEFAULT);
          else startConfirmPIN();
          break;
        case PIN_CONFIRM_NEW:
          if (confirmPIN.length() == 0) showTimed("EMPTY", "Confirm PIN", TIMED_MSG_DEFAULT);
          else finishPINChange();
          break;
      }
      break;

    case '*':
      enteredPIN = "";
      newPIN     = "";
      confirmPIN = "";
      if (pinState == PIN_NORMAL)
        showTimed("CLEARED", "Enter PIN", TIMED_MSG_DEFAULT);
      else {
        pinState = PIN_NORMAL;
        showTimed("CANCELLED", "PIN Unchanged", TIMED_MSG_DEFAULT);
      }
      break;

    case 'A':
      if (pinState == PIN_NORMAL) {
        enteredPIN     = "";
        failedAttempts = 0;
        lockout        = false;
        lockDoor("keypad");
      }
      break;

    case 'B':
      switch (pinState) {
        case PIN_VERIFY_OLD:
          if (enteredPIN.length() > 0) enteredPIN.remove(enteredPIN.length() - 1);
          showPINEntry("OLD PIN", enteredPIN);
          break;
        case PIN_ENTER_NEW:
          if (newPIN.length() > 0) newPIN.remove(newPIN.length() - 1);
          showPINEntry("NEW PIN", newPIN);
          break;
        case PIN_CONFIRM_NEW:
          if (confirmPIN.length() > 0) confirmPIN.remove(confirmPIN.length() - 1);
          showPINEntry("CONFIRM", confirmPIN);
          break;
        default:
          if (enteredPIN.length() > 0) enteredPIN.remove(enteredPIN.length() - 1);
          showPINEntry("ENTER PIN", enteredPIN);
          break;
      }
      break;

    case 'C':
      if (pinState == PIN_NORMAL) startChangePIN();
      break;

    case 'D':
      if (pinState == PIN_NORMAL) {
        logEvent("status", "keypad");
        showTimed("STATUS", doorClosed ? "Door: Closed" : "Door: Open", TIMED_MSG_DEFAULT);
      }
      break;
  }
}

// ===================== SETUP =====================

void setup() {
  Serial.begin(115200);
  delay(300);

  esp_reset_reason_t r = esp_reset_reason();
  Serial.print("[BOOT] Reset reason: ");
  switch (r) {
    case ESP_RST_POWERON:  Serial.println("Power-on");                break;
    case ESP_RST_EXT:      Serial.println("EN button / external");    break;
    case ESP_RST_SW:       Serial.println("Software reset");          break;
    case ESP_RST_PANIC:    Serial.println("CRASH (panic/exception)"); break;
    case ESP_RST_INT_WDT:
    case ESP_RST_TASK_WDT:
    case ESP_RST_WDT:      Serial.println("Watchdog");                break;
    case ESP_RST_BROWNOUT: Serial.println("BROWNOUT (power dip)");    break;
    default:               Serial.println((int)r);                    break;
  }

  Serial.println("\n==============================");
  Serial.println("   ESA SMART DOOR LOCK v" FIRMWARE_VERSION);
  Serial.println("     (LocKify cloud ready)");
  Serial.print("   Buzzer: ");
  Serial.println(BUZZER_ENABLED ? "ON" : "OFF");
  Serial.print("   Burglar alarm: ");
  Serial.println(BURGLAR_ALARM_ENABLED ? "ON" : "OFF");
  Serial.println("==============================");

  loadPIN();

  pinMode(RED_LED_PIN,       OUTPUT);
  pinMode(BLUE_LED_PIN,      OUTPUT);
  pinMode(BUZZER_PIN,        OUTPUT);
  pinMode(DOOR_SENSOR_PIN,   INPUT_PULLUP);
  pinMode(INSIDE_BUTTON_PIN, INPUT_PULLUP);

  doorClosed = true;     // door starts closed; press the door button to toggle

  servoBegin();
  isLocked = true;
  lockedAt = millis();
  moveServo(LOCKED_POSITION);
  updateLEDs();

  // OLED (SH1106 via U8g2) - I2C pins are set in the constructor
  u8g2.begin();
  u8g2.setContrast(255);

  showStatus("STARTING", "Please Wait...");
  delay(800);
  restoreDefaultScreen();

  cloudBegin();   // Wi-Fi + Firebase in the background; the lock is usable right away

  Serial.println("\nSystem ready. Default PIN: " DEFAULT_PIN);
  Serial.println("CONTROLS:");
  Serial.println("  0-9  PIN digits    #  Enter/Submit");
  Serial.println("  *    Clear/Cancel  A  Lock door");
  Serial.println("  B    Backspace     C  Change PIN");
  Serial.println("  D    Door status");
  Serial.println("  Door button (GPIO " + String(DOOR_SENSOR_PIN) + "): toggles open/closed");
  Serial.println("  Inside button (GPIO " + String(INSIDE_BUTTON_PIN) + "): unlock/lock");
  Serial.println("==============================");
}

// ===================== SERIAL COMMANDS =====================

void handleSerialCommands() {
  while (Serial.available()) {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();
    if (cmd.length() == 0) continue;

    if (cmd == "UNLOCK") {
      unlockDoor("serial_app");
    } else if (cmd == "LOCK") {
      lockDoor("serial_app");
    } else if (cmd == "DOOR_TOGGLE") {
      doorClosed = !doorClosed;
      handleDoorChange();
    } else if (cmd == "INSIDE_BUTTON") {
      Serial.println("[BUTTON] Inside button pressed");
      if (burglarAlarmActive && !BURGLAR_BUTTON_CAN_SILENCE) {
        showTimed("ALARM ACTIVE", "Enter PIN to stop", TIMED_MSG_DEFAULT);
        playError();
      } else if (isLocked) {
        unlockDoor("button");
      } else {
        lockDoor("button");
      }
    } else if (cmd.startsWith("KEY:")) {
      char k = cmd.charAt(4);
      handleKeypress(k);
    } else if (cmd == "STATUS") {
      logEvent("status", "query");
    }
  }
}

// ===================== LOOP =====================

void loop() {
  handleSerialCommands();

  buzzerUpdate();
  servoUpdate();
  servoRefresh();
  timedMsgUpdate();

  readDoorSensor();
  readInsideButton();

  handleLockout();
  handleAutoLock();
  handleDoorWarning();
  handleBurglarAlarm();

  handleCloud();   // before the keypad skip below, so app commands work during lockout too

  // Keypad - skip during lockout or while a timed message is showing
  if (lockout || timedMsgActive) return;

  static char lastPhysicalKey = NO_KEY;
  static unsigned long lastPhysicalKeyTime = 0;
  char key = keypad.getKey();
  if (key != NO_KEY) {
    if (key != lastPhysicalKey || (millis() - lastPhysicalKeyTime > 300)) {
      lastPhysicalKey = key;
      lastPhysicalKeyTime = millis();
      handleKeypress(key);
    }
  } else {
    lastPhysicalKey = NO_KEY;
  }
}