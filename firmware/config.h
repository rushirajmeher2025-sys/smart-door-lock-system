#ifndef CONFIG_H
#define CONFIG_H

#include <Arduino.h>

// ============================================================
//  ESA Smart Lock - Configuration (offline version)
// ============================================================

// -- OPTIONS -------------------------------------------------
#define BUZZER_ENABLED       true     // false = silent (no tone() calls)

// -- GPIO PIN DEFINITIONS ------------------------------------

// Servo / Actuator
#define SERVO_PIN            18

// Buzzer (use a PASSIVE buzzer for tone() to work)
#define BUZZER_PIN           19

// LEDs
#define RED_LED_PIN          4     // Locked indicator
#define BLUE_LED_PIN         23    // Unlocked indicator

// Push-buttons (wire diagonally opposite legs: one leg to GPIO, other leg to GND)
#define DOOR_SENSOR_PIN      5     // Door button - each press toggles door open/closed
#define INSIDE_BUTTON_PIN    16    // Inside exit button - LOW = pressed (RX2 on the board)

// OLED Display (I2C) - 1.3" SH1106
#define OLED_SDA             21
#define OLED_SCL             22
#define SCREEN_WIDTH         128
#define SCREEN_HEIGHT        64

// Keypad Rows
#define KP_R1                13
#define KP_R2                17    // TX2 on the board
#define KP_R3                14
#define KP_R4                27

// Keypad Columns
#define KP_C1                26
#define KP_C2                25
#define KP_C3                33
#define KP_C4                32

// -- SERVO ---------------------------------------------------
// Power tip: run from a good 5V wall charger (not a laptop USB port),
// and optionally add a 470uF-1000uF capacitor across servo V+ and GND.
#define LOCKED_POSITION      0
#define UNLOCKED_POSITION    90
#define SERVO_MOVE_TIME      700      // ms (only used if auto-detach is on)
#define SERVO_AUTO_DETACH    false    // true = power servo off after moving, false = keep holding position
#define SERVO_REFRESH_MS     500      // re-send target position this often (0 = off)

// -- DOOR-LEFT-OPEN WARNING (gentle, plays once) -------------
#define DOOR_WARNING_TIME    10000    // ms the door can stay open before the warning
#define WARN_BEEPS           3        // number of soft beeps (max 4)
#define WARN_FREQ            1000     // Hz - lower pitch sounds softer on a passive buzzer
#define WARN_BEEP_MS         150      // length of each beep
#define WARN_GAP_MS          350      // silence between beeps

// -- BURGLAR ALARM (door opens while the lock is locked) -----
#define BURGLAR_ALARM_ENABLED      true
#define BURGLAR_GRACE_MS           2000     // ignore door changes this long after locking
#define BURGLAR_ALARM_DURATION     30000    // ms the siren sounds (screen stays in alarm until PIN)
#define BURGLAR_FREQ_LOW           2500     // Hz
#define BURGLAR_FREQ_HIGH          3500     // Hz
#define BURGLAR_STEP_MS            150      // ms per tone, alternating low/high
#define BURGLAR_BUTTON_CAN_SILENCE false    // true = inside button can also stop the alarm

// -- TIMING (milliseconds) -----------------------------------
#define LOCKOUT_TIME         10000    // Keypad lockout after MAX_PIN_ATTEMPTS
#define AUTO_LOCK_DELAY      5000     // Auto-lock N ms after door closes (unlocked)
#define DEBOUNCE_DELAY       50       // Button debounce
#define TIMED_MSG_DEFAULT    1500     // Short on-screen notification
#define TIMED_MSG_LONG       2000     // Longer on-screen notification

// -- SECURITY LIMITS -----------------------------------------
#define MAX_PIN_ATTEMPTS     3        // Wrong PINs before keypad lockout
#define MIN_PIN_LENGTH       4
#define MAX_PIN_LENGTH       8

// -- NVS (Non-Volatile Storage) ------------------------------
#define NVS_NAMESPACE        "smartlock"
#define NVS_KEY_PIN          "pin"

// -- DEFAULTS ------------------------------------------------
#define DEFAULT_PIN          "1234"

// -- PIN-change state machine --------------------------------
enum PinChangeMode {
  PIN_NORMAL,
  PIN_VERIFY_OLD,
  PIN_ENTER_NEW,
  PIN_CONFIRM_NEW
};

#endif // CONFIG_H