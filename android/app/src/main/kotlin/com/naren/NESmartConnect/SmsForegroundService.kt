package com.naren.NESmartConnect

import android.app.*
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import android.content.pm.ServiceInfo

class SmsForegroundService : Service() {

    private val CHANNEL_ID = "sms_fg_channel"
    private val NOTIF_ID   = 101

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startAsFg(createNotification())
    }

    // ---------- channel ----------
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val chan = NotificationChannel(
                CHANNEL_ID,
                "SMS Live Service",
                NotificationManager.IMPORTANCE_MIN
            ).apply {
                description = "Keeps NESmartConnect alive while screen is open"
                lockscreenVisibility = Notification.VISIBILITY_SECRET
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(chan)
        }
    }

    // ---------- foreground start ----------
    private fun startAsFg(notification: Notification) {
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(
                NOTIF_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
        } else {
            startForeground(NOTIF_ID, notification)
        }
    }

    // ---------- tiny silent notification ----------
    private fun createNotification(): Notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_notify_sync)  // replace with your 24×24 icon if desired
            .setContentTitle("NESmartConnect active")
            .setContentText("Listening for device SMS …")
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setOngoing(true)
            .setShowWhen(false)
            .build()

    override fun onStartCommand(i: Intent?, flags: Int, startId: Int) =
        START_NOT_STICKY

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopForeground(true)
        super.onDestroy()
    }
}