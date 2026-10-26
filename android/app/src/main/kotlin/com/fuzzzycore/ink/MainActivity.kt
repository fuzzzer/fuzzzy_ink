package com.fuzzzycore.ink

import android.os.Build
import android.os.Bundle
import com.fuzzzycore.ink.anywhere.AnywhereSwitch
import com.fuzzzycore.ink.anywhere.InkEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private var guard: Guard? = null

    /** The engine's take count when this activity took it ("Lock from other apps" builds). */
    private var takenAt = NOT_TAKEN

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // App switcher (DESIGN.md section 4.2): never a picture of the
        // content, on every screen. Android 13+ leaves the recents thumbnail
        // blank; private screens are blank on every version (FLAG_SECURE,
        // Guard.kt).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            setRecentsScreenshotEnabled(false)
        }
        // A build without "Lock from other apps" leaves no entry point on,
        // whatever an earlier build switched on.
        if (!InkEngine.isInBuild(this)) AnywhereSwitch.apply(this, isOn = false)
    }

    /**
     * "Lock from other apps" builds share one engine with the selection sheet
     * (anywhere/InkEngine.kt); every other build keeps its own, as before.
     */
    override fun getCachedEngineId(): String? {
        if (!InkEngine.isInBuild(this)) return super.getCachedEngineId()
        InkEngine.obtain(this)
        return InkEngine.cachedId
    }

    override fun onStart() {
        super.onStart()
        // The sheet took the engine for a fingerprint prompt while this
        // activity was away: build it again on the engine, which kept the
        // app exactly where it was.
        if (takenAt != NOT_TAKEN && takenAt != InkEngine.takenCount) {
            takenAt = NOT_TAKEN
            recreate()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UserFiles.CHANNEL)
            .setMethodCallHandler(UserFiles(this))
        val sharedGuard = InkEngine.guard.takeIf { InkEngine.isInBuild(this) }
        val guard = sharedGuard ?: Guard(this).also {
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Guard.CHANNEL)
                .setMethodCallHandler(it)
        }
        guard.attach(this)
        this.guard = guard
        if (sharedGuard != null) takenAt = InkEngine.noteTaken()
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
        private const val NOT_TAKEN = -1
    }

    override fun onDestroy() {
        guard?.onDestroy(this)
        super.onDestroy()
    }
}
