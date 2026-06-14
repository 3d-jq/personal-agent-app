package com.example.personal_agent_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import android.app.NotificationManager
import android.app.NotificationChannel

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val title = intent.getStringExtra("title") ?: "提醒"
        val message = intent.getStringExtra("message") ?: ""

        val channelId = "agent_reminders"
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(channelId, "Agent 提醒", NotificationManager.IMPORTANCE_HIGH)
        nm.createNotificationChannel(channel)

        val pi = PendingIntent.getActivity(
            context, 0,
            context.packageManager.getLaunchIntentForPackage(context.packageName)!!,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val n = NotificationCompat.Builder(context, channelId)
            .setContentTitle(title)
            .setContentText(message)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pi)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()

        nm.notify(intent.getIntExtra("id", 0), n)
    }
}

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // Re-schedule persisted reminders after boot
        val prefs = context.getSharedPreferences("reminders", Context.MODE_PRIVATE)
        val keys = prefs.all.keys
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        for (key in keys) {
            val data = prefs.getString(key, null) ?: continue
            val parts = data.split("|||")
            if (parts.size < 4) continue
            val id = key.toIntOrNull() ?: continue
            val title = parts[0]
            val message = parts[1]
            val triggerMs = parts[2].toLongOrNull() ?: continue

            if (System.currentTimeMillis() >= triggerMs) continue // already passed

            val intent = Intent(context, AlarmReceiver::class.java).apply {
                putExtra("id", id)
                putExtra("title", title)
                putExtra("message", message)
            }
            val pi = PendingIntent.getBroadcast(
                context, id, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerMs, pi)
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerMs, pi)
            }
        }
    }
}

object AlarmScheduler {
    fun schedule(context: Context, id: Int, title: String, message: String, delaySeconds: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val triggerMs = android.os.SystemClock.elapsedRealtime() + delaySeconds * 1000

        val intent = Intent(context, AlarmReceiver::class.java).apply {
            putExtra("id", id)
            putExtra("title", title)
            putExtra("message", message)
        }
        val pi = PendingIntent.getBroadcast(
            context, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Use setExactAndAllowWhileIdle on all supported versions (API 23+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerMs, pi)
        } else {
            alarmManager.setExact(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerMs, pi)
        }

        // Persist for reboot recovery
        val prefs = context.getSharedPreferences("reminders", Context.MODE_PRIVATE)
        prefs.edit().putString(id.toString(), "$title|||$message|||$triggerMs|||").apply()
    }

    fun cancel(context: Context, id: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, AlarmReceiver::class.java)
        val pi = PendingIntent.getBroadcast(
            context, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pi)
        pi.cancel()

        context.getSharedPreferences("reminders", Context.MODE_PRIVATE).edit().remove(id.toString()).apply()
    }
}
