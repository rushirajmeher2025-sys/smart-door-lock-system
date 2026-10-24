# LocKify app

Flutter app for the Smart Door Lock System. See [../docs/SETUP.md](../docs/SETUP.md) for connecting it to Firebase and the lock.

## Run it

```bash
flutter pub get
flutter run -d chrome                                          # Demo mode until Firebase is configured
flutter run -d chrome --dart-define=LOCKIFY_EMULATOR=127.0.0.1 # against the local Firebase emulator
flutter test
```

While `flutter run` is active, press `r` to hot reload after saving and `R` to restart.

## Layout

- `lib/repositories/lock_repository.dart`: the interface the screens use, plus command outcomes.
- `lib/repositories/firebase_lock_repository.dart`: live data from `/devices/{deviceId}` (status, events, commands, access).
- `lib/repositories/mock_lock_repository.dart`: Demo mode; applies the same safety rules as the firmware.
- `lib/screens/`: auth gate, login, dashboard, activity, settings.
- `lib/widgets/`: `LockOrb` (animated padlock), `SwipeToConfirm`, `IntroOverlay` (launch animation), `Backdrop`, `Panel`.
- `lib/utils/constants.dart`: app name, tagline, device ID (must match the firmware's `DEVICE_ID`), timings.
