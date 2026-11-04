package com.smartlock.app.smart_door_lock

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import com.smartlock.app.smart_door_lock.R
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
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

            val lockStatus = widgetData.getString("lock_status", "Unknown") ?: "Unknown"
            val deviceName = widgetData.getString("device_name", "Lock") ?: "Lock"
            val isOnline = widgetData.getBoolean("is_online", false)

            views.setTextViewText(R.id.widget_lock_status, if (!isOnline) "Offline" else lockStatus)
            views.setTextViewText(R.id.widget_device_name, deviceName)

            // Tapping the lock button sends background broadcast to lock the door
            val lockIntent = HomeWidgetBackgroundIntent.getBroadcast(
                context,
                Uri.parse("lockify://widget/lock_action")
            )
            views.setOnClickPendingIntent(R.id.widget_lock_button, lockIntent)

            // Tapping the widget body launches the main activity
            val launchIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java
            )
            views.setOnClickPendingIntent(R.id.widget_root, launchIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
