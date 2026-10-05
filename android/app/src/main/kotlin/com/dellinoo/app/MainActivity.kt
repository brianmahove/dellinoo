package com.dellinoo.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Push notification channels (lib/core/push.dart). The payments Worker
        // picks one per message (payments/src/fcm.ts); separate channels let a
        // customer mute promos in Android settings and keep order updates.
        // "order_updates" is also the manifest's default. Re-creating an
        // existing channel is a no-op.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channels = listOf(
                NotificationChannel("order_updates", "Order updates", NotificationManager.IMPORTANCE_HIGH)
                    .apply { description = "Payment confirmations and delivery progress for your orders" },
                NotificationChannel("price_drops", "Price drops", NotificationManager.IMPORTANCE_DEFAULT)
                    .apply { description = "When something on your wishlist gets cheaper" },
                NotificationChannel("deals", "Deals & offers", NotificationManager.IMPORTANCE_DEFAULT)
                    .apply { description = "Sales and new arrivals from Dellinoo" },
            )
            getSystemService(NotificationManager::class.java).createNotificationChannels(channels)
        }
    }
}
