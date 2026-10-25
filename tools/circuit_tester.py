#!/usr/bin/env python3
"""
LocKify / Smart Door Lock - Hardware Circuit Diagnostic & Live Monitor Tool
Monitors the ESP32 serial stream, debounces noisy/stuck inputs, and validates
hardware functionality (Keypad, Buttons, Servo, OLED, Buzzer, Alarm).
"""

import serial
import time
import sys
import argparse

PORT = "/dev/cu.usbserial-0001"
BAUD = 115200

KEYPAD_PIN_MAP = {
    '1': ('Row 1 (GPIO 13)', 'Col 1 (GPIO 26)'),
    '2': ('Row 1 (GPIO 13)', 'Col 2 (GPIO 25)'),
    '3': ('Row 1 (GPIO 13)', 'Col 3 (GPIO 33)'),
    'A': ('Row 1 (GPIO 13)', 'Col 4 (GPIO 32)'),
    '4': ('Row 2 (GPIO 17)', 'Col 1 (GPIO 26)'),
    '5': ('Row 2 (GPIO 17)', 'Col 2 (GPIO 25)'),
    '6': ('Row 2 (GPIO 17)', 'Col 3 (GPIO 33)'),
    'B': ('Row 2 (GPIO 17)', 'Col 4 (GPIO 32)'),
    '7': ('Row 3 (GPIO 14)', 'Col 1 (GPIO 26)'),
    '8': ('Row 3 (GPIO 14)', 'Col 2 (GPIO 25)'),
    '9': ('Row 3 (GPIO 14)', 'Col 3 (GPIO 33)'),
    'C': ('Row 3 (GPIO 14)', 'Col 4 (GPIO 32)'),
    '*': ('Row 4 (GPIO 27)', 'Col 1 (GPIO 26)'),
    '0': ('Row 4 (GPIO 27)', 'Col 2 (GPIO 25)'),
    '#': ('Row 4 (GPIO 27)', 'Col 3 (GPIO 33)'),
    'D': ('Row 4 (GPIO 27)', 'Col 4 (GPIO 32)'),
}

def monitor_circuit(duration=None, port=PORT, baud=BAUD):
    print("=" * 60)
    print("  LocKify ESP32 Hardware Circuit Tester & Live Monitor")
    print(f"  Connected Port: {port} @ {baud} baud")
    print("=" * 60)
    
    try:
        ser = serial.Serial(port, baud, timeout=0.1)
    except Exception as e:
        print(f"\n[ERROR] Could not open port {port}: {e}")
        return

    ser.reset_input_buffer()
    
    last_event = None
    event_repeat_count = 0
    last_print_time = 0
    stuck_warning_given = set()

    start_time = time.time()
    print("\n[READY] Listening for live circuit events (Ctrl+C to stop)...\n")

    try:
        while True:
            if duration and (time.time() - start_time > duration):
                break

            line = ser.readline()
            if not line:
                # Flush pending repeat report if idle
                if event_repeat_count > 1 and (time.time() - last_print_time > 0.5):
                    print(f"    └── (repeated {event_repeat_count} times)")
                    event_repeat_count = 0
                continue

            text = line.decode('utf-8', errors='replace').strip()
            if not text:
                continue

            now = time.time()
            if text == last_event:
                event_repeat_count += 1
                if event_repeat_count >= 50 and text not in stuck_warning_given:
                    stuck_warning_given.add(text)
                    print(f"\n[!] ALERT: High frequency flood detected for '{text}'!")
                    if text.startswith("[KEY] "):
                        key = text[6:].strip()
                        if key in KEYPAD_PIN_MAP:
                            row, col = KEYPAD_PIN_MAP[key]
                            print(f"    --> Key '{key}' is stuck or shorted!")
                            print(f"    --> Check pins: {row} <---> {col}")
                    print()
                continue
            else:
                if event_repeat_count > 1:
                    print(f"    └── (repeated {event_repeat_count} times)")
                event_repeat_count = 1
                last_event = text
                last_print_time = now

            # Clean display formatting
            timestamp = time.strftime("%H:%M:%S")
            if text.startswith("[KEY]"):
                key = text[5:].strip()
                pin_info = f" ({KEYPAD_PIN_MAP.get(key, ('?', '?'))[0]}, {KEYPAD_PIN_MAP.get(key, ('?', '?'))[1]})" if key in KEYPAD_PIN_MAP else ""
                print(f"[{timestamp}] ⌨️  KEYPAD: Key '{key}' pressed{pin_info}")
            elif text.startswith("[BUTTON]"):
                print(f"[{timestamp}] 🔘 BUTTON: {text[8:].strip()} (GPIO 16)")
            elif text.startswith("[DOOR]"):
                print(f"[{timestamp}] 🚪 DOOR SENSOR: {text[6:].strip()} (GPIO 5)")
            elif text.startswith("[LOCK]"):
                print(f"[{timestamp}] 🔒 LOCK ACTION: {text[6:].strip()}")
            elif text.startswith("[SERVO]"):
                print(f"[{timestamp}] ⚙️  SERVO MOTOR: {text[7:].strip()} (GPIO 18)")
            elif text.startswith("[ALARM]"):
                print(f"[{timestamp}] 🚨 ALARM: {text[7:].strip()}")
            elif text.startswith("[PIN]"):
                print(f"[{timestamp}] 🔑 PIN STATUS: {text[5:].strip()}")
            elif text.startswith("[EVENT]"):
                print(f"[{timestamp}] 📊 EVENT: {text[7:].strip()}")
            elif text.startswith("[BOOT]"):
                print(f"[{timestamp}] 🔌 SYSTEM BOOT: {text[6:].strip()}")
            else:
                print(f"[{timestamp}] {text}")

    except KeyboardInterrupt:
        print("\n\n[INFO] Monitoring stopped by user.")
    finally:
        ser.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Test and monitor smart lock circuit")
    parser.add_argument("--duration", type=float, default=None, help="Stop after N seconds")
    parser.add_argument("--port", type=str, default=PORT, help="Serial port")
    args = parser.parse_args()
    monitor_circuit(duration=args.duration, port=args.port)
