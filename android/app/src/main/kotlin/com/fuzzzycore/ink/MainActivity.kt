package com.fuzzzycore.ink

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // App switcher (DESIGN.md section 4.2): never a picture of the
        // content, on every screen. Android 13+ leaves the recents thumbnail
        // blank; private screens are blank on every version (FLAG_SECURE,
        // Guard.kt).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            setRecentsScreenshotEnabled(false)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UserFiles.CHANNEL)
            .setMethodCallHandler(UserFiles(this))
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Guard.CHANNEL)
            .setMethodCallHandler(Guard(this))
    }
}
