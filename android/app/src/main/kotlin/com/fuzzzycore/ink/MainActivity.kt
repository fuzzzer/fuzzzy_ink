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
    }

    override fun onDestroy() {
        guard?.onDestroy()
        super.onDestroy()
    }
}
