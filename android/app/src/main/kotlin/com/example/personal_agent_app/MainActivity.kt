package com.example.personal_agent_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.app.NotificationCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example/save_to_gallery"
    private val OPEN_CHANNEL = "com.example/open_file"
    private val LIVE_CHANNEL = "com.example/live_activity"
    private val REMINDER_CHANNEL = "com.example/reminder"
    private val SHARE_CHANNEL = "com.example/share_file"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Save to gallery ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveImage" -> {
                    try {
                        val bytes = call.argument<ByteArray>("bytes")
                        val name = call.argument<String>("name") ?: "image.png"
                        if (bytes == null) { result.error("NO_DATA", "No data", null); return@setMethodCallHandler }
                        saveImageToGallery(bytes, name)
                        result.success(true)
                    } catch (e: Exception) { result.error("SAVE_ERROR", e.message, null) }
                }
                "saveVideo" -> {
                    try {
                        val bytes = call.argument<ByteArray>("bytes")
                        val name = call.argument<String>("name") ?: "video.mp4"
                        if (bytes == null) { result.error("NO_DATA", "No data", null); return@setMethodCallHandler }
                        saveVideoToGallery(bytes, name)
                        result.success(true)
                    } catch (e: Exception) { result.error("SAVE_ERROR", e.message, null) }
                }
                else -> result.notImplemented()
            }
        }

        // ── Open file ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OPEN_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openFile") {
                try {
                    val path = call.argument<String>("path")
                    if (path == null) { result.error("NO_PATH", "No file path", null); return@setMethodCallHandler }
                    val file = File(path)
                    if (!file.exists()) {
                        result.error("FILE_NOT_FOUND", "File not found: $path", null)
                        return@setMethodCallHandler
                    }
                    // 按扩展名推断正确的 MIME，避免 .mov/.webm 被当成 mp4 无法播放
                    val ext = file.extension.lowercase()
                    val mimeType = call.argument<String>("mimeType") ?: when (ext) {
                        "mp4" -> "video/mp4"
                        "mov" -> "video/quicktime"
                        "webm" -> "video/webm"
                        "mkv" -> "video/x-matroska"
                        else -> "video/*"
                    }
                    val uri = FileProvider.getUriForFile(this, "${packageName}.fileprovider", file)
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, mimeType)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    val chooser = Intent.createChooser(intent, "选择播放器")
                    startActivity(chooser)
                    result.success(true)
                } catch (e: Exception) { result.error("OPEN_ERROR", e.message, null) }
            } else result.notImplemented()
        }

        // ── Task Notifications ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LIVE_CHANNEL).setMethodCallHandler { call, result ->
            try {
                val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                val channel = NotificationChannel("ai_tasks", "AI Tasks", NotificationManager.IMPORTANCE_LOW).apply {
                    description = "AI task execution notifications"
                }
                nm.createNotificationChannel(channel)

                val title = call.argument<String>("title") ?: "AI Assistant"
                val message = call.argument<String>("message") ?: ""
                val intent = Intent(this, MainActivity::class.java).apply { flags = Intent.FLAG_ACTIVITY_SINGLE_TOP }
                val pi = PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

                when (call.method) {
                    "startTask", "updateMessage", "updateProgress" -> {
                        val isIndeterminate = call.method != "updateProgress"
                        val progress = call.argument<Int>("progress") ?: 0
                        val maxProgress = call.argument<Int>("maxProgress") ?: 100
                        val n = NotificationCompat.Builder(this, "ai_tasks")
                            .setContentTitle(title)
                            .setContentText(message)
                            .setSmallIcon(android.R.drawable.ic_dialog_info)
                            .setOngoing(true)
                            .setProgress(maxProgress, progress, isIndeterminate)
                            .setContentIntent(pi)
                            .setPriority(NotificationCompat.PRIORITY_LOW)
                            .build()
                        nm.notify(5000, n)
                    }
                    "complete" -> {
                        val n = NotificationCompat.Builder(this, "ai_tasks")
                            .setContentTitle(title)
                            .setContentText(message)
                            .setSmallIcon(android.R.drawable.ic_dialog_info)
                            .setOngoing(false)
                            .setAutoCancel(true)
                            .setContentIntent(pi)
                            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                            .build()
                        nm.notify(5000, n)
                    }
                    "fail", "cancel" -> nm.cancel(5000)
                }
                result.success(true)
            } catch (e: Exception) {
                result.error("NOTIFICATION_ERROR", e.message, null)
            }
        }

        // ── Share file ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "shareFile") {
                try {
                    val path = call.argument<String>("path")
                    val mimeType = call.argument<String>("mimeType") ?: "text/html"
                    val title = call.argument<String>("title") ?: "分享笔记"
                    if (path == null) { result.error("NO_PATH", "No file path", null); return@setMethodCallHandler }
                    val file = File(path)
                    if (!file.exists()) { result.error("FILE_NOT_FOUND", "File not found: $path", null); return@setMethodCallHandler }
                    val uri = FileProvider.getUriForFile(this, "${packageName}.fileprovider", file)
                    val intent = Intent(Intent.ACTION_SEND).apply {
                        type = mimeType
                        putExtra(Intent.EXTRA_STREAM, uri)
                        putExtra(Intent.EXTRA_SUBJECT, title)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(Intent.createChooser(intent, title))
                    result.success(true)
                } catch (e: Exception) { result.error("SHARE_ERROR", e.message, null) }
            } else result.notImplemented()
        }

        // ── Alarm-based Reminders ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, REMINDER_CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "schedule" -> {
                        val id = call.argument<Int>("id") ?: 0
                        val title = call.argument<String>("title") ?: ""
                        val message = call.argument<String>("message") ?: ""
                        val delaySeconds = (call.argument<Number>("delaySeconds") ?: 0).toLong()
                        AlarmScheduler.schedule(this, id, title, message, delaySeconds)
                        result.success(true)
                    }
                    "cancel" -> {
                        val id = call.argument<Int>("id") ?: 0
                        AlarmScheduler.cancel(this, id)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("REMINDER_ERROR", e.message, null)
            }
        }

        // ── Calendar ──
        val CALENDAR_CHANNEL = "com.example/calendar"
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALENDAR_CHANNEL).setMethodCallHandler { call, result ->
            try {
                val resolver = contentResolver
                when (call.method) {
                    "query" -> {
                        val s = call.argument<Long>("startMs") ?: (System.currentTimeMillis() - 86400000)
                        val e = call.argument<Long>("endMs") ?: (System.currentTimeMillis() + 7 * 86400000)
                        result.success(CalendarHelper.queryEvents(resolver, s, e))
                    }
                    "add" -> {
                        val t = call.argument<String>("title") ?: ""
                        val d = call.argument<String>("description")
                        val s = call.argument<Long>("startMs") ?: System.currentTimeMillis()
                        val e = call.argument<Long>("endMs") ?: (s + 3600000)
                        result.success(CalendarHelper.addEvent(resolver, t, d, s, e))
                    }
                    "delete" -> {
                        val id = call.argument<Long>("id") ?: 0L
                        result.success(CalendarHelper.deleteEvent(resolver, id))
                    }
                    else -> result.notImplemented()
                }
            } catch (ex: Exception) {
                result.error("CALENDAR_ERROR", ex.message, null)
            }
        }
    }

    private fun saveImageToGallery(bytes: ByteArray, name: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val cv = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, name)
                put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/AgnesAI")
            }
            val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, cv)
            uri?.let { contentResolver.openOutputStream(it)?.use { os -> os.write(bytes) } }
        } else {
            val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), "AgnesAI")
            if (!dir.exists()) dir.mkdirs()
            FileOutputStream(File(dir, name)).use { it.write(bytes) }
        }
    }

    private fun saveVideoToGallery(bytes: ByteArray, name: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val cv = ContentValues().apply {
                put(MediaStore.Video.Media.DISPLAY_NAME, name)
                put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
                put(MediaStore.Video.Media.RELATIVE_PATH, Environment.DIRECTORY_MOVIES + "/DWeis")
            }
            val uri = contentResolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, cv)
            uri?.let { contentResolver.openOutputStream(it)?.use { os -> os.write(bytes) } }
        } else {
            val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES), "DWeis")
            if (!dir.exists()) dir.mkdirs()
            FileOutputStream(File(dir, name)).use { it.write(bytes) }
        }
    }
}
