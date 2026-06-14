package com.example.personal_agent_app

import android.content.ContentResolver
import android.content.ContentUris
import android.content.ContentValues
import android.provider.CalendarContract
import java.util.TimeZone

object CalendarHelper {
    fun getDefaultCalendarId(resolver: ContentResolver): Long {
        val projection = arrayOf(CalendarContract.Calendars._ID)
        val uri = CalendarContract.Calendars.CONTENT_URI.buildUpon()
            .appendQueryParameter(CalendarContract.CALLER_IS_SYNCADAPTER, "true")
            .appendQueryParameter(CalendarContract.Calendars.ACCOUNT_TYPE, "com.android.calendar")
            .build()
        resolver.query(uri, projection, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) return cursor.getLong(0)
        }
        return 1L
    }

    fun queryEvents(resolver: ContentResolver, startMs: Long, endMs: Long): String {
        val calId = getDefaultCalendarId(resolver)
        val projection = arrayOf(CalendarContract.Events._ID, CalendarContract.Events.TITLE, CalendarContract.Events.DESCRIPTION, CalendarContract.Events.DTSTART, CalendarContract.Events.DTEND, CalendarContract.Events.ALL_DAY)
        val selection = "${CalendarContract.Events.CALENDAR_ID} = ? AND ${CalendarContract.Events.DTSTART} >= ? AND ${CalendarContract.Events.DTEND} <= ?"
        val args = arrayOf(calId.toString(), startMs.toString(), endMs.toString())
        val events = mutableListOf<String>()
        resolver.query(CalendarContract.Events.CONTENT_URI, projection, selection, args, "${CalendarContract.Events.DTSTART} ASC")?.use { cursor ->
            while (cursor.moveToNext()) {
                val timeFmt = java.text.SimpleDateFormat("MM/dd HH:mm", java.util.Locale.CHINA)
                val id = cursor.getLong(0)
                val title = cursor.getString(1) ?: ""
                val desc = cursor.getString(2) ?: ""
                val s = cursor.getLong(3)
                val e = cursor.getLong(4)
                events.add("$title: ${timeFmt.format(java.util.Date(s))}-${timeFmt.format(java.util.Date(e))}${if (desc.isNotEmpty()) " ($desc)" else ""}")
            }
        }
        return if (events.isEmpty()) "无日程" else events.joinToString("\n")
    }

    fun addEvent(resolver: ContentResolver, title: String, description: String?, startMs: Long, endMs: Long): String {
        val calId = getDefaultCalendarId(resolver)
        val existing = queryEvents(resolver, startMs - 60000, endMs + 60000)
        val hasConflict = existing != "无日程"
        val values = ContentValues().apply {
            put(CalendarContract.Events.CALENDAR_ID, calId)
            put(CalendarContract.Events.TITLE, title)
            put(CalendarContract.Events.DESCRIPTION, description ?: "")
            put(CalendarContract.Events.DTSTART, startMs)
            put(CalendarContract.Events.DTEND, endMs)
            put(CalendarContract.Events.EVENT_TIMEZONE, TimeZone.getDefault().id)
        }
        val uri = resolver.insert(CalendarContract.Events.CONTENT_URI, values) ?: return "添加失败"
        val id = ContentUris.parseId(uri)
        return "已添加: $title${if (hasConflict) " (⚠️时间冲突)" else ""} (ID:$id)"
    }

    fun deleteEvent(resolver: ContentResolver, eventId: Long): String {
        val deleted = resolver.delete(ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, eventId), null, null)
        return if (deleted > 0) "已删除" else "未找到该事件"
    }
}
