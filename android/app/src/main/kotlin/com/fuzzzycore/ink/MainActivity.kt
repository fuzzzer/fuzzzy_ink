package com.fuzzzycore.ink

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private var guard: Guard? = null

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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PROCESS_TEXT_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ProcessText.queryTextActions" -> result.success(emptyMap<String, String>())
                    else -> result.notImplemented()
                }
            }
    }

    companion object {
        private const val PROCESS_TEXT_CHANNEL = "flutter/processtext"
    }

    override fun onDestroy() {
        guard?.onDestroy()
        super.onDestroy()
    }
}
