package com.smartlock.app.smart_door_lock

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import com.smartlock.app.smart_door_lock.R
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetProvider

class LockWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.lock_widget_layout)

            val lockStatus = widgetData.getString("lock_status", "Locked") ?: "Locked"
            val deviceName = widgetData.getString("device_name", "Front door") ?: "Front door"
            val isOnline = widgetData.getBoolean("is_online", true)

            val displayStatus = if (!isOnline) "Offline" else lockStatus
            views.setTextViewText(R.id.widget_lock_status, displayStatus)
            views.setTextViewText(R.id.widget_device_name, deviceName)

            // 1. Tapping left info container launches the app
            val appIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
            val launchPendingIntent = PendingIntent.getActivity(
                context,
                0,
                appIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_info_container, launchPendingIntent)

            // 2. Tapping the right lock button sends background broadcast to lock the door
            val lockIntent = HomeWidgetBackgroundIntent.getBroadcast(
                context,
                Uri.parse("lockify://widget/lock_action")
            )
            views.setOnClickPendingIntent(R.id.widget_lock_button, lockIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
