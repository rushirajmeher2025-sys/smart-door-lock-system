#ifndef SECRETS_H
#define SECRETS_H

// ============================================================
//  Copy this file to secrets.h (same folder) and fill it in.
//  secrets.h is git-ignored, so your passwords never get pushed.
//  Without secrets.h the lock still builds and runs offline.
// ============================================================

// Wi-Fi (the ESP32 only supports 2.4 GHz networks)
#define WIFI_SSID              "your-wifi-name"
#define WIFI_PASSWORD          "your-wifi-password"

// Firebase console > Project settings > General > Web API key
#define FIREBASE_API_KEY       "AIzaSy..."

// Firebase console > Realtime Database > Data (the URL at the top, no trailing slash)
#define FIREBASE_DATABASE_URL  "https://your-project-default-rtdb.asia-southeast1.firebasedatabase.app"

// The lock's own Firebase account (Authentication > Users > Add user).
// Use a separate account from the one you sign in to the app with.
#define DEVICE_EMAIL           "lock@lockify.app"
#define DEVICE_PASSWORD        "choose-a-long-password"

#endif // SECRETS_H
