package com.murattil.murattil

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.VolumeProvider
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.content.BroadcastReceiver
import android.content.IntentFilter
import android.os.SystemClock
import androidx.core.content.ContextCompat
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import kotlin.math.roundToInt

/**
 * تشغيل الأذان كامل بصوت عالي: بيشتغل على مسار «المنبّه» (مش الإشعارات)،
 * وبيرفع صوت المنبّه للمستوى اللي المستخدم اختاره طول مدة الأذان، وبعدين يرجّعه زي ما كان.
 */
class AdhanService : Service() {
    companion object {
        const val ACTION_PLAY = "com.murattil.quran.ADHAN_PLAY"
        const val ACTION_STOP = "com.murattil.quran.ADHAN_STOP"
        const val CHANNEL = "adhan_playback"
        const val NOTIF_ID = 7001

        fun ensureChannel(ctx: Context) {
            if (Build.VERSION.SDK_INT < 26) return
            val nm = ctx.getSystemService(NotificationManager::class.java)
            if (nm.getNotificationChannel(CHANNEL) != null) return
            val ch = NotificationChannel(CHANNEL, "الأذان", NotificationManager.IMPORTANCE_HIGH)
            ch.description = "تشغيل الأذان في وقت الصلاة"
            ch.setSound(null, null) // الصوت بيشتغل من الخدمة نفسها
            ch.enableVibration(true)
            nm.createNotificationChannel(ch)
        }

        fun soundUri(ctx: Context, sound: String): Uri {
            if (sound.isNotEmpty()) {
                val id = ctx.resources.getIdentifier(sound, "raw", ctx.packageName)
                if (id != 0) return Uri.parse("android.resource://${ctx.packageName}/$id")
            }
            return Settings.System.DEFAULT_ALARM_ALERT_URI ?: Settings.System.DEFAULT_NOTIFICATION_URI
        }

        /** لو النظام منع تشغيل الخدمة: إشعار عادي بصوت الأذان (على مسار المنبّه) */
        fun fallbackNotify(ctx: Context, title: String, body: String, sound: String) {
            try {
                val chId = "adhan_fb_" + (if (sound.isEmpty()) "default" else sound)
                val uri = soundUri(ctx, sound)
                if (Build.VERSION.SDK_INT >= 26) {
                    val nm = ctx.getSystemService(NotificationManager::class.java)
                    if (nm.getNotificationChannel(chId) == null) {
                        val ch = NotificationChannel(chId, "الأذان (احتياطي)", NotificationManager.IMPORTANCE_HIGH)
                        ch.setSound(uri, AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).build())
                        nm.createNotificationChannel(ch)
                    }
                }
                val n = NotificationCompat.Builder(ctx, chId)
                    .setSmallIcon(R.drawable.ic_stat_murattil)
                    .setContentTitle(title)
                    .setContentText(body)
                    .setPriority(NotificationCompat.PRIORITY_MAX)
                    .setCategory(NotificationCompat.CATEGORY_ALARM)
                    .setSound(uri)
                    .setAutoCancel(true)
                    .setContentIntent(openApp(ctx))
                    .build()
                NotificationManagerCompat.from(ctx).notify(NOTIF_ID, n)
            } catch (_: Exception) {
            }
        }

        fun openApp(ctx: Context): PendingIntent? {
            val i = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName) ?: return null
            i.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            return PendingIntent.getActivity(ctx, 7002, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }

        fun stopIntent(ctx: Context): PendingIntent {
            val i = Intent(ctx, AdhanReceiver::class.java).setAction(ACTION_STOP)
            return PendingIntent.getBroadcast(ctx, 7003, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
    }

    private var player: MediaPlayer? = null
    private var savedVolume = -1
    private var wake: PowerManager.WakeLock? = null
    private var focus: AudioFocusRequest? = null

    // إيقاف الأذان بزرار الصوت (فوق أو تحت) — حتى والشاشة مقفولة
    private var session: MediaSession? = null
    private var volumeReceiver: BroadcastReceiver? = null
    private var startedAt = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        val sound = intent?.getStringExtra("sound") ?: ""
        val title = intent?.getStringExtra("title") ?: "حان وقت الصلاة"
        val body = intent?.getStringExtra("body") ?: ""
        val volume = intent?.getIntExtra("volume", 90) ?: 90
        ensureChannel(this)
        val n = NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_murattil)
            .setContentTitle(title)
            .setContentText(body)
            .setSubText("اضغط زرار الصوت لإيقاف الأذان")
            .setColor(0xFF1E3A6E.toInt())
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(openApp(this))
            .setDeleteIntent(stopIntent(this))
            .addAction(0, "إيقاف الأذان", stopIntent(this))
            .build()
        try {
            if (Build.VERSION.SDK_INT >= 29) {
                startForeground(NOTIF_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
            } else {
                startForeground(NOTIF_ID, n)
            }
        } catch (e: Exception) {
            fallbackNotify(this, title, body, sound)
            stopSelf()
            return START_NOT_STICKY
        }
        play(sound, volume)
        listenForVolumeKeys()
        return START_NOT_STICKY
    }

    /**
     * زرار الصوت يوقف الأذان: جلسة وسائط بتستقبل زراير الصوت (بدل ما تغيّر مستوى الصوت)،
     * ومعاها مراقبة لتغيّر الصوت كاحتياطي على الأجهزة اللي مابتبعتش الزراير للجلسة.
     */
    private fun listenForVolumeKeys() {
        startedAt = SystemClock.elapsedRealtime()
        try {
            val s = MediaSession(this, "murattil-adhan")
            s.setPlaybackToRemote(object : VolumeProvider(VolumeProvider.VOLUME_CONTROL_RELATIVE, 100, 100) {
                override fun onAdjustVolume(direction: Int) {
                    if (direction != 0) stopByUser()
                }
            })
            s.setCallback(object : MediaSession.Callback() {
                override fun onPause() = stopByUser()
                override fun onStop() = stopByUser()
                override fun onMediaButtonEvent(mediaButtonIntent: Intent): Boolean {
                    stopByUser()
                    return true
                }
            })
            s.setPlaybackState(
                PlaybackState.Builder()
                    .setActions(PlaybackState.ACTION_STOP or PlaybackState.ACTION_PAUSE or PlaybackState.ACTION_PLAY_PAUSE)
                    .setState(PlaybackState.STATE_PLAYING, 0, 1f)
                    .build()
            )
            s.isActive = true
            session = s
        } catch (_: Exception) {
        }
        try {
            val r = object : BroadcastReceiver() {
                override fun onReceive(c: Context, i: Intent) {
                    // أول ثانيتين بنتجاهل (التطبيق نفسه بيظبط مستوى صوت المنبّه في البداية)
                    if (SystemClock.elapsedRealtime() - startedAt > 2000) stopByUser()
                }
            }
            ContextCompat.registerReceiver(this, r, IntentFilter("android.media.VOLUME_CHANGED_ACTION"), ContextCompat.RECEIVER_EXPORTED)
            volumeReceiver = r
        } catch (_: Exception) {
        }
    }

    private var stopping = false

    /** المستخدم ضغط زرار الصوت: الأذان يقف، والإشعار يتشال */
    private fun stopByUser() {
        if (stopping) return
        stopping = true
        try {
            if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_REMOVE) else stopForeground(true)
        } catch (_: Exception) {
        }
        NotificationManagerCompat.from(this).cancel(NOTIF_ID)
        stopSelf()
    }

    private fun releaseKeys() {
        try {
            session?.isActive = false
            session?.release()
        } catch (_: Exception) {
        }
        session = null
        try {
            volumeReceiver?.let { unregisterReceiver(it) }
        } catch (_: Exception) {
        }
        volumeReceiver = null
    }

    private fun play(sound: String, volume: Int) {
        releasePlayer()
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        try {
            val max = am.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            if (savedVolume < 0) savedVolume = am.getStreamVolume(AudioManager.STREAM_ALARM)
            val target = (max * volume.coerceIn(10, 100) / 100.0).roundToInt().coerceIn(1, max)
            am.setStreamVolume(AudioManager.STREAM_ALARM, target, 0)
        } catch (_: Exception) {
        }
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build()
        // التلاوة (أو أي صوت تاني) بتقف مؤقتًا لحد ما الأذان يخلص
        try {
            if (Build.VERSION.SDK_INT >= 26) {
                val f = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT).setAudioAttributes(attrs).build()
                focus = f
                am.requestAudioFocus(f)
            }
        } catch (_: Exception) {
        }
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wake = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "murattil:adhan").apply { acquire(10 * 60 * 1000L) }
        } catch (_: Exception) {
        }
        try {
            player = MediaPlayer().apply {
                setAudioAttributes(attrs)
                setDataSource(this@AdhanService, soundUri(this@AdhanService, sound))
                setVolume(1f, 1f)
                setOnCompletionListener { finish() }
                setOnErrorListener { _, _, _ -> finish(); true }
                prepare()
                start()
            }
        } catch (_: Exception) {
            finish()
        }
    }

    /** الأذان خلص: الإشعار يفضل (من غير زر)، والخدمة تقف */
    private fun finish() {
        releaseKeys()
        try {
            if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_DETACH) else stopForeground(false)
        } catch (_: Exception) {
        }
        stopSelf()
    }

    private fun releasePlayer() {
        try {
            player?.stop()
        } catch (_: Exception) {
        }
        player?.release()
        player = null
    }

    override fun onDestroy() {
        releaseKeys()
        releasePlayer()
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (savedVolume >= 0) {
            try {
                am.setStreamVolume(AudioManager.STREAM_ALARM, savedVolume, 0)
            } catch (_: Exception) {
            }
            savedVolume = -1
        }
        if (Build.VERSION.SDK_INT >= 26) focus?.let { am.abandonAudioFocusRequest(it) }
        try {
            wake?.let { if (it.isHeld) it.release() }
        } catch (_: Exception) {
        }
        super.onDestroy()
    }
}
