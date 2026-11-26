package com.murattil.murattil

import android.content.Intent
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// AudioServiceActivity (بدل FlutterActivity) عشان التلاوة تكمّل في الخلفية والشاشة مقفولة
class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // الأذان: تجربة الصوت، الإيقاف، والجدولة
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "murattil/adhan").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "play" -> {
                        val i = Intent(this, AdhanService::class.java)
                            .setAction(AdhanService.ACTION_PLAY)
                            .putExtra("sound", call.argument<String>("sound") ?: "")
                            .putExtra("title", call.argument<String>("title") ?: "تجربة صوت الأذان")
                            .putExtra("body", call.argument<String>("body") ?: "")
                            .putExtra("volume", call.argument<Int>("volume") ?: 90)
                        ContextCompat.startForegroundService(this, i)
                        result.success(true)
                    }
                    "stop" -> {
                        stopService(Intent(this, AdhanService::class.java))
                        NotificationManagerCompat.from(this).cancel(AdhanService.NOTIF_ID)
                        result.success(true)
                    }
                    "schedule" -> {
                        AdhanScheduler.schedule(this, call.argument<String>("items") ?: "[]")
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("adhan", e.message, null)
            }
        }
    }
}
