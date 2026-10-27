#ifndef CLOUD_H
#define CLOUD_H

#include <Arduino.h>

// ============================================================
//  Cloud link (Wi-Fi + Firebase Realtime Database)
//
//  All network work runs in a FreeRTOS task on core 0. The main
//  loop (core 1) keeps full control of the hardware and only
//  exchanges small messages with that task, so the keypad, siren
//  and timers never wait on the network.
// ============================================================

struct CloudState {
  bool isLocked;
  bool doorClosed;
  bool burglarAlarmActive;
  bool isLockout;
  char lastMethod[12];
};

enum CloudAction : uint8_t {
  CLOUD_LOCK,
  CLOUD_UNLOCK,
  CLOUD_CLEAR_ALARM,
  CLOUD_PING
};

struct CloudCommand {
  char        id[40];
  CloudAction action;
};

// Starts Wi-Fi and the background cloud task (no-op if cloud is disabled).
void cloudBegin();

// Call every loop; only wakes the cloud task when something changed.
void cloudPublishState(const CloudState& state);

// Queues a security event for the app's activity history.
void cloudLogEvent(const char* type, const char* method);

// Returns true and fills `out` when a validated remote command is waiting.
bool cloudNextCommand(CloudCommand& out);

// Reports what the hardware did with a remote command.
// `reason` is empty when executed, otherwise a code such as "BLOCKED_DOOR_OPEN".
void cloudCommandDone(const CloudCommand& cmd, bool executed, const char* reason);

// True while the lock is signed in to Firebase and reporting.
bool cloudOnline();

// True while the ESP32 is connected to the local Wi-Fi router.
bool cloudWifiConnected();

// Sets the current hardware PIN so the cloud task can initialize or compare
void cloudSetCurrentPin(const char* pin);

// Reports a keypad PIN change to Firebase Realtime Database
void cloudReportPinChanged(const char* newPin);

// Returns true if an updated PIN from the app is waiting to be saved to NVS
bool cloudGetNewPin(char* outPin, size_t maxLen);

#endif // CLOUD_H
