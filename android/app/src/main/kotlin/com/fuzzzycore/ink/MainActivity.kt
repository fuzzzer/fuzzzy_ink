package com.fuzzzycore.ink

import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private var guard: Guard? = null

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
        val guard = Guard(this)
        this.guard = guard
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Guard.CHANNEL)
            .setMethodCallHandler(guard)
        // Other apps' text actions ("Translate" and the like, PROCESS_TEXT)
        // would receive the selected text: the app lists none, in any field
        // (security review 2026-10-26). This replaces the engine's handler on
        // Flutter's own channel; the plaintext fields' allow-list menu drops
        // such items as well.
        // Which quick unlock the phone has, so the app names it
        // (`ink_device_channel.dart`; iOS and macOS answer more there).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "biometricKind" -> result.success(biometricKind())
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PROCESS_TEXT_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ProcessText.queryTextActions" -> result.success(emptyMap<String, String>())
                    else -> result.notImplemented()
                }
            }
    }

    /// `fingerprint` or `face` when the phone has only that one; `other`
    /// when it has both, an iris reader, or none the system reports.
    private fun biometricKind(): String {
        val features = packageManager
        val fingerprint = features.hasSystemFeature(PackageManager.FEATURE_FINGERPRINT)
        val newer = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q
        val face = newer && features.hasSystemFeature(PackageManager.FEATURE_FACE)
        val iris = newer && features.hasSystemFeature(PackageManager.FEATURE_IRIS)
        return when {
            fingerprint && !face && !iris -> "fingerprint"
            face && !fingerprint && !iris -> "face"
            else -> "other"
        }
    }

    companion object {
        private const val PROCESS_TEXT_CHANNEL = "flutter/processtext"
        private const val DEVICE_CHANNEL = "com.fuzzzycore.ink/device"
    }

    override fun onDestroy() {
        guard?.onDestroy()
        super.onDestroy()
    }
}
