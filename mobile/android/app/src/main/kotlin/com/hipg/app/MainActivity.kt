package com.hipg.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.location.Address
import android.location.Geocoder
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/**
 * Hands Android 12+'s system splash over to the Flutter launch animation
 * (lib/auth/splash_screen.dart).
 *
 * The system splash stays on top of Flutter's first frames until the
 * platform removes it -- on slow devices seconds later -- so the animation
 * must not start until then or its opening beats play unseen. The Flutter
 * frame underneath is pixel-identical to the splash, so the splash is
 * dropped instantly instead of cross-fading, and Dart is told over the
 * `hipg/launch` channel.
 */
class MainActivity : FlutterActivity() {
    private val handler = Handler(Looper.getMainLooper())
    private var systemSplashGone = Build.VERSION.SDK_INT < Build.VERSION_CODES.S
    private val waitingForSplash = mutableListOf<MethodChannel.Result>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            splashScreen.setOnExitAnimationListener { splashView ->
                splashView.remove()
                markSystemSplashGone()
            }
        }
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(
            NotificationChannel(
                "hipg_updates",
                "Bookings, payments and account",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Important booking, payment, support and account updates"
            },
        )
        manager.createNotificationChannel(
            NotificationChannel(
                "hipg_discovery",
                "Stay ideas and offers",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Helpful PG suggestions and occasional HiPG reminders"
            },
        )
    }

    override fun onFlutterUiDisplayed() {
        super.onFlutterUiDisplayed()
        // Not every launch shows a system splash. If none has been removed
        // shortly after Flutter is on screen, don't keep the animation waiting.
        handler.postDelayed({ markSystemSplashGone() }, SPLASH_FALLBACK_MS)
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hipg/launch")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "systemSplashGone" ->
                        if (systemSplashGone) result.success(null)
                        else waitingForSplash.add(result)
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hipg/property-geocoding")
            .setMethodCallHandler { call, result ->
                if (call.method != "resolve") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val query = call.argument<String>("query")?.trim()
                if (query.isNullOrEmpty() || !Geocoder.isPresent()) {
                    result.success(null)
                    return@setMethodCallHandler
                }
                resolveProperty(query, result)
            }
    }

    private fun resolveProperty(query: String, result: MethodChannel.Result) {
        val geocoder = Geocoder(this, Locale.getDefault())
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            geocoder.getFromLocationName(query, 1, object : Geocoder.GeocodeListener {
                override fun onGeocode(addresses: MutableList<Address>) {
                    completeProperty(addresses.firstOrNull(), result)
                }

                override fun onError(errorMessage: String?) {
                    handler.post { result.success(null) }
                }
            })
            return
        }
        Thread {
            val address = try {
                @Suppress("DEPRECATION")
                geocoder.getFromLocationName(query, 1)?.firstOrNull()
            } catch (_: Exception) {
                null
            }
            completeProperty(address, result)
        }.start()
    }

    private fun completeProperty(address: Address?, result: MethodChannel.Result) {
        handler.post {
            result.success(address?.let {
                mapOf("latitude" to it.latitude, "longitude" to it.longitude)
            })
        }
    }

    private fun markSystemSplashGone() {
        systemSplashGone = true
        waitingForSplash.forEach { it.success(null) }
        waitingForSplash.clear()
    }

    private companion object {
        const val SPLASH_FALLBACK_MS = 2500L
    }
}
