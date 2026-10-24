# LocKify go-live guide

How to get from this repo to the real lock working with the app. It takes about 30 minutes. You need a Google account, the ESP32 circuit, a laptop with the Arduino IDE and Flutter, and a **2.4 GHz** Wi-Fi network. A phone hotspot works; college Wi-Fi with a login page does not.

## 1. Create the Firebase project

1. Go to <https://console.firebase.google.com>, click **Add project**, and give it a name (e.g. `lockify-esa`). Google Analytics is not needed.
2. **Build → Authentication → Get started → Sign-in method** → enable **Email/Password**.
3. **Build → Realtime Database → Create database**. Pick the region closest to you and start in **locked mode**.
4. Copy the database URL shown at the top of the Data tab, e.g. `https://lockify-esa-default-rtdb.asia-southeast1.firebasedatabase.app`.
5. **Project settings (gear) → General** → copy the **Web API key**.

## 2. Deploy the security rules

From the repo root:

```bash
cd firebase
npx firebase-tools login
npx firebase-tools use --add          # pick your project, alias "default"
npx firebase-tools deploy --only database
```

Without this step the database stays locked and nothing can connect.

## 3. Connect the app

```bash
cd mobile_app
dart pub global activate flutterfire_cli
flutterfire configure                 # pick your project; select web + android
flutter run -d chrome
```

`flutterfire configure` replaces `lib/firebase_options.dart`. Commit that file so the rest of the team gets it.

In the app, choose **Create account** and register **your** account. The first account to sign in becomes the lock's **owner**.

## 4. Create the lock's own account

Firebase console → **Authentication → Users → Add user**, for example `lock@lockify.app` with a long random password. The lock signs in with this account, so it never needs your personal password.

## 5. Flash the firmware

1. Arduino IDE → **Boards Manager** → install **esp32 by Espressif** (3.x).
2. **Library Manager** → install **U8g2**, **Keypad** (Mark Stanley), **ESP32Servo**, **ArduinoJson** (7.x).
3. In `firmware/smart_lock/`, copy `secrets.example.h` to `secrets.h` and fill in:
   - `WIFI_SSID`, `WIFI_PASSWORD`
   - `FIREBASE_API_KEY`: the Web API key from step 1.5
   - `FIREBASE_DATABASE_URL`: the URL from step 1.4, with no trailing slash
   - `DEVICE_EMAIL`, `DEVICE_PASSWORD`: the lock account from step 4

   `secrets.h` is git-ignored, so it never gets pushed.
4. Open `firmware/smart_lock/smart_lock.ino`, select **ESP32 Dev Module** and the right port, then **Upload**.
5. Open the **Serial Monitor at 115200 baud**. You should see:

   ```
   [CLOUD] Wi-Fi connected, IP 192.168.x.x
   [CLOUD] Signed in to Firebase (uid AbC123...)
   [CLOUD] No access to /devices/esp32_lock_01 yet. ...
   [CLOUD] This lock's UID: AbC123...
   ```

## 6. Link the lock to your account

In the app: **Settings → Lock hardware → Lock account**, then paste the UID from the Serial Monitor. Within about 30 s the monitor prints `[CLOUD] Online, reporting status`, and the dashboard turns **LIVE** with the real lock state.

## 7. Check it end to end

| Test | Expected |
|---|---|
| Swipe to unlock in the app | Servo turns, blue LED, app shows **Unlocked** and "Done" |
| Open the door (door button), swipe to lock | App says **Refused: the door is open**, lock does not move |
| Lock, wait 3 s, open the door | Siren; app turns red: **Intruder** |
| Try to unlock from the app during the alarm | Refused; only the keypad PIN stops it |
| Enter the PIN on the keypad | Alarm stops, unlocks; app updates within a second |
| Unplug the router | Keypad, buttons, alarm and auto-lock keep working; app shows **Offline** after ~35 s |
| Plug it back in | Lock reconnects by itself; "Lock back online" in Activity |

## Sharing access

A family member creates their own account in the app and sends you the **User ID** from their Settings. Add it under **Settings → People with access**. They can then see and control the lock; only you can change who has access.

## Testing without the circuit

The repo includes a stand-in for the ESP32 that talks to Firebase exactly like the firmware:

```bash
cd firebase && npx firebase-tools emulators:start --project demo-lockify     # terminal 1
cd mobile_app && flutter run -d chrome --dart-define=LOCKIFY_EMULATOR=127.0.0.1   # terminal 2
```

Create two accounts in the app or in the emulator UI (<http://127.0.0.1:4000/auth>): one for you and one for the lock. Then:

```bash
python3 tools/esp32_simulator.py --email lock@test.com --password secret123   # terminal 3
curl localhost:8099/door/open     # also: door/close, pin, offline, online, state
```

Running the app with no Firebase config at all starts **Demo mode**, which simulates everything inside the app.

## Troubleshooting

| Symptom (Serial Monitor) | Fix |
|---|---|
| `Wi-Fi not connected, retrying...` | Wrong SSID/password, or a 5 GHz-only network |
| `Sign-in failed: INVALID_LOGIN_CREDENTIALS` | `DEVICE_EMAIL` / `DEVICE_PASSWORD` don't match the user from step 4 |
| `No access to /devices/...` repeating | Link the UID in the app (step 6), and deploy the rules (step 2) |
| `Network error: ...` | No internet on that Wi-Fi, or a captive portal; try a phone hotspot |
| `[BOOT] Reset reason: BROWNOUT` | Wi-Fi + servo draw too much; power the servo from a separate 5 V supply with a shared GND |
| App: "The lock didn't answer in time" | Lock offline; check the monitor. Late commands are ignored by design |

## How it stays safe

- The app never moves the bolt directly. It files a request; the ESP32 checks it before acting: right account, less than 15 s old, not already handled, door closed for locking, no active alarm. It then reports what actually happened.
- Firebase rules ([database.rules.json](../firebase/database.rules.json)) only let the owner, people the owner added, and the linked lock account read or write the lock.
- The keypad PIN stays in the ESP32's flash and is never sent anywhere.
- Everything local (keypad, inside button, auto-lock, lockout, burglar alarm) works with no network.
- Known limits:
  - The servo has no position sensor, so "confirmed" means the lock commanded the servo, not that a sensor saw the bolt move.
  - The ESP32 uses TLS without checking Google's certificate (`setInsecure()`). Traffic is encrypted, but a hostile Wi-Fi network could intercept it.
  - SMS alerts (Phase 8) wait for the GSM modem model to be confirmed.
