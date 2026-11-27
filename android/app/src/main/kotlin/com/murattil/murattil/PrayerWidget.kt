package com.murattil.murattil

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.util.Calendar

/** ويدجت «مُرتِّل»: الصلاة القادمة مع عدّاد تنازلي، مواقيت اليوم، وورد اليوم */
class PrayerWidget : AppWidgetProvider() {
    companion object {
        private const val PREFS = "murattil_widget"

        fun save(ctx: Context, json: String) {
            ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString("data", json).apply()
            refresh(ctx)
        }

        fun refresh(ctx: Context) {
            val mgr = AppWidgetManager.getInstance(ctx)
            val ids = mgr.getAppWidgetIds(ComponentName(ctx, PrayerWidget::class.java))
            if (ids.isNotEmpty()) render(ctx, mgr, ids)
        }

        private fun sameDay(a: Long, b: Long): Boolean {
            val x = Calendar.getInstance().apply { timeInMillis = a }
            val y = Calendar.getInstance().apply { timeInMillis = b }
            return x.get(Calendar.YEAR) == y.get(Calendar.YEAR) && x.get(Calendar.DAY_OF_YEAR) == y.get(Calendar.DAY_OF_YEAR)
        }

        private val cellIds = intArrayOf(R.id.w_p1, R.id.w_p2, R.id.w_p3, R.id.w_p4, R.id.w_p5)

        fun render(ctx: Context, mgr: AppWidgetManager, ids: IntArray) {
            val data = try {
                JSONObject(ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("data", "{}") ?: "{}")
            } catch (_: Exception) {
                JSONObject()
            }
            val times = data.optJSONArray("times")
            val now = System.currentTimeMillis()
            val v = RemoteViews(ctx.packageName, R.layout.murattil_widget)

            var next = -1
            if (times != null) {
                for (i in 0 until times.length()) {
                    if (times.getJSONObject(i).getLong("at") > now) {
                        next = i
                        break
                    }
                }
            }
            if (next < 0) {
                v.setTextViewText(R.id.w_label, "مواقيت الصلاة")
                v.setTextViewText(R.id.w_name, "افتح التطبيق")
                v.setTextViewText(R.id.w_time, "وحدّد مكانك")
                v.setViewVisibility(R.id.w_chrono, View.GONE)
                v.setViewVisibility(R.id.w_row, View.GONE)
            } else {
                val n = times!!.getJSONObject(next)
                val at = n.getLong("at")
                v.setTextViewText(R.id.w_label, "الصلاة القادمة")
                v.setTextViewText(R.id.w_name, n.getString("name"))
                v.setTextViewText(R.id.w_time, n.getString("time"))
                v.setViewVisibility(R.id.w_chrono, View.VISIBLE)
                v.setChronometer(R.id.w_chrono, SystemClock.elapsedRealtime() + (at - now), null, true)
                if (Build.VERSION.SDK_INT >= 24) v.setChronometerCountDown(R.id.w_chrono, true)
                // مواقيت يوم الصلاة القادمة (الخمس صلوات)
                val first = (next / 5) * 5
                v.setViewVisibility(R.id.w_row, View.VISIBLE)
                for (k in 0 until 5) {
                    val idx = first + k
                    if (idx >= times.length()) break
                    val o = times.getJSONObject(idx)
                    val t = o.getString("time").replace(" ص", "").replace(" م", "")
                    v.setTextViewText(cellIds[k], o.getString("name") + "\n" + t)
                    v.setTextColor(cellIds[k], if (idx == next) Color.parseColor("#F5D394") else Color.parseColor("#B3FFFFFF"))
                }
                if (!sameDay(at, now)) v.setTextViewText(R.id.w_label, "الصلاة القادمة (غدًا)")
                scheduleNext(ctx, at + 1000)
            }
            val sub = listOf(data.optString("hijri"), data.optString("place")).filter { it.isNotEmpty() }.joinToString("  ·  ")
            v.setTextViewText(R.id.w_sub, sub)
            v.setTextViewText(R.id.w_wird, data.optString("wird", "افتح مُرتِّل"))

            val open = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)
            if (open != null) {
                open.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                v.setOnClickPendingIntent(R.id.w_root, PendingIntent.getActivity(ctx, 7101, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            }
            for (id in ids) mgr.updateAppWidget(id, v)
        }

        /** تحديث الويدجت لما ييجي وقت الصلاة عشان ينقل للي بعدها */
        private fun scheduleNext(ctx: Context, at: Long) {
            val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val i = Intent(ctx, PrayerWidget::class.java).setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
            val ids = AppWidgetManager.getInstance(ctx).getAppWidgetIds(ComponentName(ctx, PrayerWidget::class.java))
            i.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            val pi = PendingIntent.getBroadcast(ctx, 7102, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            try {
                val exact = Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms()
                if (exact && Build.VERSION.SDK_INT >= 23) am.setExactAndAllowWhileIdle(AlarmManager.RTC, at, pi)
                else if (Build.VERSION.SDK_INT >= 23) am.setAndAllowWhileIdle(AlarmManager.RTC, at, pi)
                else am.set(AlarmManager.RTC, at, pi)
            } catch (_: Exception) {
            }
        }
    }

    override fun onUpdate(ctx: Context, mgr: AppWidgetManager, ids: IntArray) {
        render(ctx, mgr, ids)
    }
}
