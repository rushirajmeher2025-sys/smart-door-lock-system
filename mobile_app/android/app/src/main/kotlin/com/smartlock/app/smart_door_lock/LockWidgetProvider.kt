package com.smartlock.app.smart_door_lock

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import android.app.PendingIntent
import android.net.Uri
import es.antonborri.home_widget.HomeWidgetPlugin

class LockWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.lock_widget_layout)

            // Read saved widget data from HomeWidget plugin
            val widgetData = HomeWidgetPlugin.getData(context)
            val lockStatus = widgetData.getString("lock_status", "Unknown") ?: "Unknown"
            val deviceName = widgetData.getString("device_name", "Lock") ?: "Lock"
            val isOnline = widgetData.getBoolean("is_online", false)

            views.setTextViewText(R.id.widget_lock_status, if (!isOnline) "Offline" else lockStatus)
            views.setTextViewText(R.id.widget_device_name, deviceName)

            // Tapping the icon button sends a lock action via HomeWidget background callback
            val lockIntent = HomeWidgetPlugin.createBackgroundIntent(
                context,
                Uri.parse("lockify://widget/lock_action"),
                LockWidgetProvider::class.java
            )
            views.setOnClickPendingIntent(R.id.widget_lock_button, lockIntent)

            // Tapping the widget body opens the app
            val launchIntent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                val pendingIntent = PendingIntent.getActivity(
                    context, 0, launchIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
