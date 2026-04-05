package com.siyazilim.periodicallynotification.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.widget.RemoteViews
import com.bumptech.glide.Glide
import com.bumptech.glide.load.resource.bitmap.RoundedCorners
import com.bumptech.glide.request.target.AppWidgetTarget
import com.siyazilim.periodicallynotification.R
import java.io.File

/**
 * Android Widget Provider for Daily Content
 * Reads data from SharedPreferences (set by home_widget plugin)
 * and displays it in the home screen widget with Material 3 dark theme
 */
class DailyWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val WIDGET_IMAGE_PATH_KEY = "widget_imagePath"
    }

    /** RemoteViews bitmap limit (~500KB) - küçük ölçekle */
    private fun loadScaledBitmap(file: File, maxW: Int, maxH: Int): Bitmap? {
        val opts = BitmapFactory.Options().apply {
            inJustDecodeBounds = true
        }
        BitmapFactory.decodeFile(file.absolutePath, opts)
        val w = opts.outWidth
        val h = opts.outHeight
        if (w <= 0 || h <= 0) return null
        var sampleSize = 1
        while (w / sampleSize > maxW || h / sampleSize > maxH) sampleSize *= 2
        val decodeOpts = BitmapFactory.Options().apply { inSampleSize = sampleSize }
        val bitmap = BitmapFactory.decodeFile(file.absolutePath, decodeOpts) ?: return null
        val scale = minOf(maxW.toFloat() / bitmap.width, maxH.toFloat() / bitmap.height, 1f)
        if (scale >= 1f) return bitmap
        val m = Matrix().apply { postScale(scale, scale) }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, m, true).also {
            if (it != bitmap) bitmap.recycle()
        }
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
        var imagePath: String? = null
        var imageUrl: String? = null
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
                "widget_updatedAt",
                "flutter.widget_updatedAt",
                "flutter.home_widget.widget_updatedAt",
                "flutter.home_widget.widget_updatedAt.String",
                "flutter.home_widget.widget_updatedAt.string"
            )
            val possibleImagePathKeys = listOf(
                "widget_imagePath",
                "flutter.widget_imagePath",
                "flutter.home_widget.widget_imagePath",
                "flutter.home_widget.widget_imagePath.String",
                "flutter.home_widget.widget_imagePath.string"
            )
            val possibleImageUrlKeys = listOf(
                "widget_imageUrl",
                "flutter.widget_imageUrl",
                "flutter.home_widget.widget_imageUrl",
                "flutter.home_widget.widget_imageUrl.String",
                "flutter.home_widget.widget_imageUrl.string"
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
                    if (value != null) {
                        updatedAt = value
                        break
                    }
                }
            }

            // Try to find imagePath (yerel dosya - Flutter tarafından indirilir)
            if (imagePath == null) {
                for (key in possibleImagePathKeys) {
                    val value = prefs.getString(key, null)
                    if (value != null && value.isNotEmpty()) {
                        imagePath = value
                        android.util.Log.e("DailyWidget", "✅ Found imagePath: $imagePath")
                        break
                    }
                }
            }
            // Try to find imageUrl (fallback - örn. arka planda indirme başarısız olduysa)
            if (imageUrl == null) {
                for (key in possibleImageUrlKeys) {
                    val value = prefs.getString(key, null)
                    if (value != null && value.isNotEmpty()) {
                        imageUrl = value
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

        // Create RemoteViews - Material 3 dark theme layout
        val views = RemoteViews(context.packageName, R.layout.daily_widget)

        // Title with lightbulb emoji (Günün İçeri... style)
        val displayTitle = "💡 $title"
        views.setTextViewText(R.id.widget_title, displayTitle)
        views.setTextViewText(R.id.widget_body, body)

        // Image: 1) Yerel dosyadan senkron yükle (tercih), 2) Yoksa URL ile Glide (fallback)
        var imageShown = false
        val pathsToTry = mutableListOf<String>()
        if (!imagePath.isNullOrEmpty()) pathsToTry.add(imagePath)
        pathsToTry.add(context.filesDir.absolutePath + "/widget_cache/widget_image.jpg")
        pathsToTry.add(context.getDir("app_flutter", Context.MODE_PRIVATE).absolutePath + "/widget_cache/widget_image.jpg")
        pathsToTry.add(context.cacheDir.absolutePath + "/widget_cache/widget_image.jpg")

        for (path in pathsToTry.distinct()) {
            val file = File(path)
            if (file.exists()) {
                try {
                    val bitmap = loadScaledBitmap(file, 216, 216)
                    if (bitmap != null) {
                        views.setViewVisibility(R.id.widget_image, android.view.View.VISIBLE)
                        views.setImageViewBitmap(R.id.widget_image, bitmap)
                        imageShown = true
                        android.util.Log.e("DailyWidget", "✅ Image loaded from: $path")
                        bitmap.recycle()
                        break
                    }
                } catch (e: Exception) {
                    android.util.Log.e("DailyWidget", "Image load error: ${e.message}")
                }
            }
        }
        if (!imageShown && !imageUrl.isNullOrEmpty()) {
            views.setViewVisibility(R.id.widget_image, android.view.View.VISIBLE)
            try {
                val awt = AppWidgetTarget(context, R.id.widget_image, views, appWidgetId)
                Glide.with(context.applicationContext)
                    .asBitmap()
                    .load(imageUrl)
                    .transform(RoundedCorners(48))
                    .into(awt)
            } catch (e: Exception) {
                android.util.Log.e("DailyWidget", "Glide fallback error: ${e.message}")
                views.setViewVisibility(R.id.widget_image, android.view.View.GONE)
            }
        } else if (!imageShown) {
            views.setViewVisibility(R.id.widget_image, android.view.View.GONE)
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
        android.util.Log.e("DailyWidget", "Widget updated successfully!")
        android.util.Log.e("DailyWidget", "Widget ID: $appWidgetId, Title: $title, Body: $body")
        android.util.Log.e("DailyWidget", "=== WIDGET UPDATE END ===")
    }
}
