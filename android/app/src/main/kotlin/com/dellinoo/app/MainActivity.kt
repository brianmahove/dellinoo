package com.dellinoo.app

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    /// A USSD dial waiting on the CALL_PHONE permission prompt.
    private var pendingUssd: Pair<String, MethodChannel.Result>? = null

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

    // USSD for manual EcoCash payment (lib/core/ussd.dart). With CALL_PHONE
    // granted the code runs straight away, so the customer lands on EcoCash's
    // own PIN prompt and confirmation; without it, the dialer opens with the
    // code filled in and they tap call themselves. Results: "called",
    // "dialer" or "failed".
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.dellinoo.app/ussd").setMethodCallHandler { call, result ->
            if (call.method != "dial") return@setMethodCallHandler result.notImplemented()
            val code = call.argument<String>("code")
            if (code.isNullOrBlank()) return@setMethodCallHandler result.error("bad_code", "No USSD code", null)
            if (checkSelfPermission(Manifest.permission.CALL_PHONE) == PackageManager.PERMISSION_GRANTED) {
                result.success(dial(code, direct = true))
            } else {
                pendingUssd?.second?.success(dial(pendingUssd!!.first, direct = false))
                pendingUssd = code to result
                requestPermissions(arrayOf(Manifest.permission.CALL_PHONE), USSD_PERMISSION_REQUEST)
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != USSD_PERMISSION_REQUEST) return
        val (code, result) = pendingUssd ?: return
        pendingUssd = null
        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        result.success(dial(code, direct = granted))
    }

    private fun dial(code: String, direct: Boolean): String {
        // "#" must be encoded or everything after it is dropped as a fragment.
        val uri = Uri.parse("tel:" + Uri.encode(code))
        return try {
            startActivity(Intent(if (direct) Intent.ACTION_CALL else Intent.ACTION_DIAL, uri))
            if (direct) "called" else "dialer"
        } catch (e: Exception) {
            try {
                startActivity(Intent(Intent.ACTION_DIAL, uri))
                "dialer"
            } catch (e2: Exception) {
                "failed"
            }
        }
    }

    companion object {
        private const val USSD_PERMISSION_REQUEST = 4153
    }
}
