package com.dellinoo.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Push notifications (lib/core/push.dart) post to this channel — the
        // payments Worker sends with channel_id "order_updates", and it's the
        // manifest's default. Creating an existing channel is a no-op.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "order_updates",
                "Order updates",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply { description = "Payment confirmations and delivery progress for your orders" }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }
}
