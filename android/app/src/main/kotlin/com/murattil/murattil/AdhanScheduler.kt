package com.murattil.murattil

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

/** جدولة الأذان بمنبّهات النظام (بتشتغل حتى والتطبيق مقفول) */
object AdhanScheduler {
    const val ACTION_ALARM = "com.murattil.quran.ADHAN_ALARM"
    private const val PREFS = "murattil_adhan"

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun schedule(ctx: Context, itemsJson: String) {
        cancelAll(ctx)
        prefs(ctx).edit().putString("items", itemsJson).apply()
        register(ctx, JSONArray(itemsJson))
    }

    fun restore(ctx: Context) {
        try {
            register(ctx, JSONArray(prefs(ctx).getString("items", "[]")))
        } catch (_: Exception) {
        }
    }

    private fun pending(ctx: Context, id: Int, o: JSONObject?): PendingIntent {
        val i = Intent(ctx, AdhanReceiver::class.java).setAction(ACTION_ALARM).putExtra("id", id)
        if (o != null) {
            i.putExtra("sound", o.optString("sound"))
                .putExtra("title", o.optString("title"))
                .putExtra("body", o.optString("body"))
                .putExtra("volume", o.optInt("volume", 90))
        }
        return PendingIntent.getBroadcast(ctx, 5000 + id, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun register(ctx: Context, arr: JSONArray) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val now = System.currentTimeMillis()
        val exact = Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms()
        for (k in 0 until arr.length()) {
            val o = arr.getJSONObject(k)
            val at = o.getLong("at")
            if (at <= now) continue
            val pi = pending(ctx, o.getInt("id"), o)
            try {
                if (exact) {
                    if (Build.VERSION.SDK_INT >= 23) am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
                    else am.setExact(AlarmManager.RTC_WAKEUP, at, pi)
                } else {
                    if (Build.VERSION.SDK_INT >= 23) am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
                    else am.set(AlarmManager.RTC_WAKEUP, at, pi)
                }
            } catch (_: Exception) {
            }
        }
    }

    private fun cancelAll(ctx: Context) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        try {
            val arr = JSONArray(prefs(ctx).getString("items", "[]"))
            for (k in 0 until arr.length()) am.cancel(pending(ctx, arr.getJSONObject(k).getInt("id"), null))
        } catch (_: Exception) {
        }
    }
}
