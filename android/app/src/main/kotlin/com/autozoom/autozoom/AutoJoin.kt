package com.autozoom.autozoom

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import org.json.JSONArray
import org.json.JSONObject

/** Schedules "open Zoom at class start" alarms that survive app kill and reboot. */
object AutoJoinScheduler {
    private const val PREFS = "autozoom_autojoin"
    private const val KEY = "items"
    private const val FLAGS = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun load(ctx: Context): List<JSONObject> {
        val arr = JSONArray(prefs(ctx).getString(KEY, null) ?: "[]")
        return (0 until arr.length()).map { arr.getJSONObject(it) }
    }

    private fun save(ctx: Context, items: List<JSONObject>) {
        prefs(ctx).edit().putString(KEY, JSONArray(items).toString()).apply()
    }

    private fun alarms(ctx: Context) = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    private fun pending(ctx: Context, id: Int, item: JSONObject = JSONObject()): PendingIntent {
        val i = Intent(ctx, AutoJoinReceiver::class.java)
            .putExtra("id", id)
            .putExtra("uri", item.optString("uri"))
            .putExtra("fallbackUri", item.optString("fallbackUri"))
            .putExtra("title", item.optString("title"))
        return PendingIntent.getBroadcast(ctx, id, i, FLAGS)
    }

    private fun canExact(ctx: Context) =
        Build.VERSION.SDK_INT < 31 || alarms(ctx).canScheduleExactAlarms()

    private fun isFuture(item: JSONObject) = item.getLong("timeMillis") > System.currentTimeMillis()

    private fun schedule(ctx: Context, item: JSONObject) {
        val time = item.getLong("timeMillis")
        val pi = pending(ctx, item.getInt("id"), item)
        val am = alarms(ctx)
        if (Build.VERSION.SDK_INT >= 23) {
            if (canExact(ctx)) am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, pi)
            else am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, pi)
        } else {
            am.setExact(AlarmManager.RTC_WAKEUP, time, pi)
        }
    }

    /** Replaces the whole schedule. */
    fun sync(ctx: Context, items: List<JSONObject>) {
        load(ctx).forEach { alarms(ctx).cancel(pending(ctx, it.getInt("id"))) }
        val future = items.filter(::isFuture)
        future.forEach { schedule(ctx, it) }
        save(ctx, future)
    }

    fun cancel(ctx: Context, id: Int) {
        alarms(ctx).cancel(pending(ctx, id))
        save(ctx, load(ctx).filter { it.getInt("id") != id })
    }

    /** Re-arms persisted items after reboot / app update. */
    fun restore(ctx: Context) {
        val future = load(ctx).filter(::isFuture)
        future.forEach { schedule(ctx, it) }
        save(ctx, future)
    }

    fun permissionStatus(ctx: Context): Map<String, Boolean> {
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return mapOf(
            "overlay" to (Build.VERSION.SDK_INT < 23 || Settings.canDrawOverlays(ctx)),
            "fullScreen" to (Build.VERSION.SDK_INT < 34 || nm.canUseFullScreenIntent()),
            "exactAlarm" to canExact(ctx),
        )
    }
}

class AutoJoinReceiver : BroadcastReceiver() {
    @Suppress("DEPRECATION")
    override fun onReceive(ctx: Context, intent: Intent) {
        val id = intent.getIntExtra("id", 0)
        val title = intent.getStringExtra("title") ?: ""
        val fallback = intent.getStringExtra("fallbackUri")
        AutoJoinScheduler.cancel(ctx, id)

        var view = Intent(Intent.ACTION_VIEW, Uri.parse(intent.getStringExtra("uri") ?: ""))
        if (view.resolveActivity(ctx.packageManager) == null && !fallback.isNullOrEmpty()) {
            view = Intent(Intent.ACTION_VIEW, Uri.parse(fallback))
        }
        view.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

        var started = false
        if (Build.VERSION.SDK_INT < 23 || Settings.canDrawOverlays(ctx)) {
            try {
                ctx.startActivity(view)
                started = true
            } catch (e: Exception) {
            }
        }
        // ponytail: Android 15+ may silently block the overlay-exempt start (needs a visible overlay
        // window), and startActivity doesn't throw, so always post the notification there too.
        if (started && Build.VERSION.SDK_INT < 35) return

        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val pi = PendingIntent.getActivity(
            ctx, id, view, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val builder = if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(
                NotificationChannel(
                    "autozoom_autojoin", "Tự động vào Zoom", NotificationManager.IMPORTANCE_HIGH
                )
            )
            Notification.Builder(ctx, "autozoom_autojoin")
        } else {
            Notification.Builder(ctx).setPriority(Notification.PRIORITY_HIGH)
        }
        builder.setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Đang vào lớp: $title")
            .setContentText("Nhấn để mở Zoom")
            .setCategory(Notification.CATEGORY_ALARM)
            .setFullScreenIntent(pi, true)
            .setContentIntent(pi)
            .setAutoCancel(true)
        nm.notify("autojoin", id, builder.build())
    }
}

class AutoJoinBootReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        AutoJoinScheduler.restore(ctx)
    }
}
