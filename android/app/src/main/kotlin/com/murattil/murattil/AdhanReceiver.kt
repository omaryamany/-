package com.murattil.murattil

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat

/** منبّه وقت الصلاة → تشغيل الأذان، وزر «إيقاف الأذان» */
class AdhanReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        when (intent.action) {
            AdhanService.ACTION_STOP -> {
                ctx.stopService(Intent(ctx, AdhanService::class.java))
                NotificationManagerCompat.from(ctx).cancel(AdhanService.NOTIF_ID)
            }
            AdhanScheduler.ACTION_ALARM -> {
                val title = intent.getStringExtra("title") ?: "حان وقت الصلاة"
                val body = intent.getStringExtra("body") ?: ""
                val sound = intent.getStringExtra("sound") ?: ""
                val si = Intent(ctx, AdhanService::class.java)
                    .setAction(AdhanService.ACTION_PLAY)
                    .putExtra("title", title)
                    .putExtra("body", body)
                    .putExtra("sound", sound)
                    .putExtra("volume", intent.getIntExtra("volume", 90))
                try {
                    ContextCompat.startForegroundService(ctx, si)
                } catch (e: Exception) {
                    AdhanService.fallbackNotify(ctx, title, body, sound)
                }
            }
        }
    }
}

/** بعد إعادة تشغيل الموبايل أو تحديث التطبيق: إعادة جدولة الأذان */
class AdhanBootReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        AdhanScheduler.restore(ctx)
    }
}
