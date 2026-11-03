const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Triggers whenever a new security event is written to a device's event log:
 *   /devices/{deviceId}/events/{eventId}
 *
 * Sends a high-priority push notification via Firebase Cloud Messaging (FCM)
 * to all devices subscribed to topic `lock_{deviceId}` or registered in
 * `/devices/{deviceId}/fcmTokens/{uid}`.
 *
 * This delivers real-time notifications even when the LocKify app is completely closed.
 */
exports.onSecurityEventCreated = functions.database
  .ref("/devices/{deviceId}/events/{eventId}")
  .onCreate(async (snapshot, context) => {
    const { deviceId, eventId } = context.params;
    const eventData = snapshot.val();
    if (!eventData) return null;

    const type = eventData.type || "event";
    const method = eventData.method || "System";
    const severity = eventData.severity || "normal";
    const title = eventData.title || `LocKify Alert (${deviceId})`;
    const description = eventData.description || `Event: ${type} via ${method}`;

    const isAlarm = severity === "alarm";
    const isWarning = severity === "warning";
    const channelId = isAlarm || isWarning ? "lockify_alarm_channel" : "lockify_activity_channel";
    const priority = isAlarm || isWarning ? "high" : "normal";

    const payload = {
      notification: {
        title: title,
        body: description,
      },
      data: {
        deviceId: String(deviceId),
        eventId: String(eventId),
        type: String(type),
        method: String(method),
        severity: String(severity),
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: priority,
        notification: {
          channelId: channelId,
          sound: "default",
          defaultSound: true,
          defaultVibrateTimings: true,
          priority: isAlarm ? "max" : isWarning ? "high" : "default",
          notificationPriority: isAlarm
            ? "PRIORITY_MAX"
            : isWarning
            ? "PRIORITY_HIGH"
            : "PRIORITY_DEFAULT",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
            contentAvailable: true,
          },
        },
      },
      topic: `lock_${deviceId}`,
    };

    try {
      // 1. Send push notification to all users subscribed to the lock's topic
      const topicResponse = await admin.messaging().send(payload);
      console.log(`[FCM] Sent topic notification for device ${deviceId}:`, topicResponse);
    } catch (err) {
      console.error(`[FCM] Error sending topic message to lock_${deviceId}:`, err);
    }

    // 2. Also send directly to individual registered user tokens under /devices/{deviceId}/fcmTokens
    try {
      const tokensSnap = await admin.database().ref(`/devices/${deviceId}/fcmTokens`).once("value");
      if (tokensSnap.exists()) {
        const tokensObj = tokensSnap.val();
        const tokens = Object.values(tokensObj)
          .map((item) => (typeof item === "string" ? item : item && item.token))
          .filter((t) => typeof t === "string" && t.length > 0);

        if (tokens.length > 0) {
          const directPayload = {
            notification: payload.notification,
            data: payload.data,
            android: payload.android,
            apns: payload.apns,
            tokens: tokens,
          };
          const multiResponse = await admin.messaging().sendEachForMulticast(directPayload);
          console.log(`[FCM] Sent to ${tokens.length} direct tokens: ${multiResponse.successCount} succeeded, ${multiResponse.failureCount} failed.`);
        }
      }
    } catch (tokenErr) {
      console.error(`[FCM] Error sending direct token messages for ${deviceId}:`, tokenErr);
    }

    return null;
  });

/**
 * Triggers whenever burglarAlarmActive becomes true in /devices/{deviceId}/status:
 * Immediately dispatches an emergency breakthrough push notification.
 */
exports.onBurglarAlarmTriggered = functions.database
  .ref("/devices/{deviceId}/status/burglarAlarmActive")
  .onUpdate(async (change, context) => {
    const { deviceId } = context.params;
    const before = change.before.val();
    const after = change.after.val();

    if (!before && after === true) {
      const message = {
        topic: `lock_${deviceId}`,
        notification: {
          title: "🚨 INTRUDER ALERT DETECTED!",
          body: `Door was forced open while locked on ${deviceId}! Siren is actively sounding.`,
        },
        data: {
          deviceId: String(deviceId),
          type: "burglar_alarm",
          severity: "alarm",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "lockify_alarm_channel",
            sound: "default",
            defaultSound: true,
            defaultVibrateTimings: true,
            priority: "max",
            notificationPriority: "PRIORITY_MAX",
          },
        },
      };

      try {
        await admin.messaging().send(message);
        console.log(`[FCM] Emergency alarm notification sent for ${deviceId}`);
      } catch (err) {
        console.error(`[FCM] Error sending emergency alarm notification for ${deviceId}:`, err);
      }
    }
    return null;
  });

