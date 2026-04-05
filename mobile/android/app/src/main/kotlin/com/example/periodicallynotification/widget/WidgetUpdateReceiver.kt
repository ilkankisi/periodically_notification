package com.siyazilim.periodicallynotification.widget

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.appwidget.AppWidgetManager

/**
 * Broadcast receiver to update widget when data changes
 * This can be triggered by home_widget plugin or FCM
 */
class WidgetUpdateReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "com.siyazilim.periodicallynotification.UPDATE_WIDGET") {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val provider = DailyWidgetProvider()
            val appWidgetIds = appWidgetManager.getAppWidgetIds(
                android.content.ComponentName(context, DailyWidgetProvider::class.java)
            )
            provider.onUpdate(context, appWidgetManager, appWidgetIds)
        }
    }
}
