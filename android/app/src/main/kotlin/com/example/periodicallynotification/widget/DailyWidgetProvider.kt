package com.siyazilim.periodicallynotification.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import com.siyazilim.periodicallynotification.R
import java.text.SimpleDateFormat
import java.util.*

/**
 * Android Widget Provider for Daily Content
 * Reads data from SharedPreferences (set by home_widget plugin)
 * and displays it in the home screen widget
 */
class DailyWidgetProvider : AppWidgetProvider() {

    companion object {
        // home_widget package uses FlutterSharedPreferences
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val WIDGET_TITLE_KEY = "flutter.widget_title"
        private const val WIDGET_BODY_KEY = "flutter.widget_body"
        private const val WIDGET_UPDATED_AT_KEY = "flutter.widget_updatedAt"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        android.util.Log.e("DailyWidget", "=== onUpdate CALLED ===")
        android.util.Log.e("DailyWidget", "Widget count: ${appWidgetIds.size}")
        // Update all widget instances
        for (appWidgetId in appWidgetIds) {
            android.util.Log.e("DailyWidget", "Updating widget ID: $appWidgetId")
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
        android.util.Log.e("DailyWidget", "=== onUpdate FINISHED ===")
    }

    override fun onReceive(context: Context, intent: android.content.Intent) {
        super.onReceive(context, intent)
        android.util.Log.e("DailyWidget", "=== onReceive CALLED ===")
        android.util.Log.e("DailyWidget", "Action: ${intent.action}")
        
        // Always update widget when receiving any intent
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(
            android.content.ComponentName(context, DailyWidgetProvider::class.java)
        )
        android.util.Log.e("DailyWidget", "Found ${appWidgetIds.size} widget(s)")
        if (appWidgetIds.isNotEmpty()) {
            onUpdate(context, appWidgetManager, appWidgetIds)
        }
        android.util.Log.e("DailyWidget", "=== onReceive FINISHED ===")
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        // home_widget package stores data in SharedPreferences
        // According to home_widget source code, it uses "HomeWidgetPreferences"
        // Try multiple possible SharedPreferences file names
        val possiblePrefsNames = listOf(
            "HomeWidgetPreferences",  // This is what home_widget package uses!
            "FlutterSharedPreferences",
            "flutter.home_widget",
            "home_widget",
            "HomeWidgetProviderPrefs"
        )
        
        var title: String? = null
        var body: String? = null
        var updatedAt: String? = null
        
        // Try each SharedPreferences file
        for (prefsName in possiblePrefsNames) {
            val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            val allKeys = prefs.all.keys
            val allEntries = prefs.all
            
            android.util.Log.e("DailyWidget", "=== Checking $prefsName ===")
            android.util.Log.e("DailyWidget", "Total keys: ${allKeys.size}")
            android.util.Log.e("DailyWidget", "All keys: ${allKeys.joinToString(", ")}")
            
            // Log all entries with their values
            for ((key, value) in allEntries) {
                android.util.Log.e("DailyWidget", "  Key: $key = $value (${value?.javaClass?.simpleName})")
            }
            
            // Try different key formats
            // According to home_widget source code, it saves keys directly without prefix
            // So "widget_title" is saved as "widget_title", not "flutter.widget_title"
            val possibleTitleKeys = listOf(
                "widget_title",  // This is what home_widget package uses!
                "flutter.widget_title",
                "flutter.home_widget.widget_title",
                "flutter.home_widget.widget_title.String",
                "flutter.home_widget.widget_title.string"
            )
            val possibleBodyKeys = listOf(
                "widget_body",  // This is what home_widget package uses!
                "flutter.widget_body",
                "flutter.home_widget.widget_body",
                "flutter.home_widget.widget_body.String",
                "flutter.home_widget.widget_body.string"
            )
            val possibleUpdatedKeys = listOf(
                "widget_updatedAt",  // This is what home_widget package uses!
                "flutter.widget_updatedAt",
                "flutter.home_widget.widget_updatedAt",
                "flutter.home_widget.widget_updatedAt.String",
                "flutter.home_widget.widget_updatedAt.string"
            )
            
            // Try to find title
            if (title == null) {
                for (key in possibleTitleKeys) {
                    val value = prefs.getString(key, null)
                    android.util.Log.e("DailyWidget", "  Trying title key '$key': ${if (value != null) "FOUND: $value" else "not found"}")
                    if (value != null) {
                        title = value
                        android.util.Log.e("DailyWidget", "✅ Found title in $prefsName with key $key: $title")
                        break
                    }
                }
            }
            
            // Try to find body
            if (body == null) {
                for (key in possibleBodyKeys) {
                    val value = prefs.getString(key, null)
                    android.util.Log.e("DailyWidget", "  Trying body key '$key': ${if (value != null) "FOUND: $value" else "not found"}")
                    if (value != null) {
                        body = value
                        android.util.Log.e("DailyWidget", "✅ Found body in $prefsName with key $key: $body")
                        break
                    }
                }
            }
            
            // Try to find updatedAt
            if (updatedAt == null) {
                for (key in possibleUpdatedKeys) {
                    val value = prefs.getString(key, null)
                    android.util.Log.e("DailyWidget", "  Trying updatedAt key '$key': ${if (value != null) "FOUND: $value" else "not found"}")
                    if (value != null) {
                        updatedAt = value
                        android.util.Log.e("DailyWidget", "✅ Found updatedAt in $prefsName with key $key: $updatedAt")
                        break
                    }
                }
            }
            
            android.util.Log.e("DailyWidget", "=== Finished checking $prefsName ===")
            
            // If we found all values, break
            if (title != null && body != null) {
                break
            }
        }
        
        // Set defaults if not found
        title = title ?: "Günün İçeriği"
        body = body ?: "İçerik yükleniyor..."
        
        android.util.Log.e("DailyWidget", "=== WIDGET UPDATE START ===")
        android.util.Log.e("DailyWidget", "Final Title: $title")
        android.util.Log.e("DailyWidget", "Final Body: $body")
        android.util.Log.e("DailyWidget", "Final UpdatedAt: $updatedAt")

        // Create RemoteViews
        val views = RemoteViews(context.packageName, R.layout.daily_widget)
        
        android.util.Log.e("DailyWidget", "Setting widget_title to: $title")
        android.util.Log.e("DailyWidget", "Setting widget_body to: $body")
        
        // Set text
        views.setTextViewText(R.id.widget_title, title)
        views.setTextViewText(R.id.widget_body, body)
        
        // Format and set updated time
        val updatedText = if (updatedAt != null) {
            try {
                val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.getDefault())
                dateFormat.timeZone = TimeZone.getTimeZone("UTC")
                val date = dateFormat.parse(updatedAt)
                if (date != null) {
                    val displayFormat = SimpleDateFormat("dd/MM/yyyy HH:mm", Locale.getDefault())
                    "Son güncelleme: ${displayFormat.format(date)}"
                } else {
                    ""
                }
            } catch (e: Exception) {
                android.util.Log.e("DailyWidget", "Error parsing date: $e")
                ""
            }
        } else {
            ""
        }
        views.setTextViewText(R.id.widget_updated, updatedText)
        
        android.util.Log.e("DailyWidget", "Updated text set to: $updatedText")

        // Update widget - this should trigger visual update
        android.util.Log.e("DailyWidget", "Calling updateAppWidget for widget ID: $appWidgetId")
        appWidgetManager.updateAppWidget(appWidgetId, views)
        android.util.Log.e("DailyWidget", "Widget updated successfully!")
        android.util.Log.e("DailyWidget", "Widget ID: $appWidgetId, Title: $title, Body: $body")
        android.util.Log.e("DailyWidget", "=== WIDGET UPDATE END ===")
    }
}
