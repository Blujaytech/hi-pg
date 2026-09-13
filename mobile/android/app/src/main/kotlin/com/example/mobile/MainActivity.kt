package com.example.mobile

import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

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
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            splashScreen.setOnExitAnimationListener { splashView ->
                splashView.remove()
                markSystemSplashGone()
            }
        }
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
