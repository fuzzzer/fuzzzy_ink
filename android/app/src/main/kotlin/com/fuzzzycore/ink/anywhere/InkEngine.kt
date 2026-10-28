package com.fuzzzycore.ink.anywhere

import android.app.Activity
import android.content.Context
import android.os.SystemClock
import androidx.fragment.app.FragmentActivity
import com.fuzzzycore.ink.Guard
import com.fuzzzycore.ink.R
import io.flutter.embedding.android.ExclusiveAppComponent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * The app's one Flutter engine when the build has "Lock from other apps"
 * (`FUZZ_ANYWHERE=true`, documents/fuzz_anywhere/CHANNEL.md).
 *
 * Dart is the one store owner, so the selection sheet must talk to the same
 * engine as the app's own screens: the engine lives in [FlutterEngineCache],
 * [com.fuzzzycore.ink.MainActivity] shows it, and the sheet calls it, started
 * without a screen when the app was not running. Without the flag the app
 * keeps an engine of its own, as before, and nothing here runs.
 */
object InkEngine {
    private const val ID = "fuzzzy_ink"

    /** How long after a start a missing channel means "still starting". */
    private const val STARTING_MS = 20_000L

    private var startedAt = 0L

    /** The guard channel's handler for this engine (copies, screen protection). */
    var guard: Guard? = null
        private set

    /**
     * Counts the activities that took the engine. [com.fuzzzycore.ink.MainActivity]
     * keeps the count it took it at: a different count means another activity
     * (the sheet, for the fingerprint prompt) took it since.
     */
    var takenCount = 0
        private set

    /** Whether this build has the feature (the build flag, read at build time). */
    fun isInBuild(context: Context): Boolean =
        context.resources.getBoolean(R.bool.fuzz_anywhere_build)

    val cachedId: String get() = ID

    /** Whether the engine was started a moment ago and may still be starting. */
    val isStarting: Boolean
        get() = SystemClock.elapsedRealtime() - startedAt < STARTING_MS

    /** The engine, started now (without a screen) if it is not running. */
    fun obtain(context: Context): FlutterEngine {
        FlutterEngineCache.getInstance().get(ID)?.let { return it }
        val app = context.applicationContext
        val engine = FlutterEngine(app)
        // Not in front until an activity says so: the app's unlock screen
        // waits for the person instead of prompting on its own.
        engine.lifecycleChannel.appIsPaused()
        val guard = Guard(app)
        MethodChannel(engine.dartExecutor.binaryMessenger, Guard.CHANNEL)
            .setMethodCallHandler(guard)
        this.guard = guard
        AnywhereChannel.listen(engine.dartExecutor.binaryMessenger, app)
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        startedAt = SystemClock.elapsedRealtime()
        FlutterEngineCache.getInstance().put(ID, engine)
        return engine
    }

    /** An activity took the engine; answers the new count. */
    fun noteTaken(): Int = ++takenCount
}

/**
 * The sheet's hold on the engine: only for the fingerprint or face prompt,
 * which the app's biometric plugin shows on the activity the engine is
 * attached to. Taking it detaches [com.fuzzzycore.ink.MainActivity], which
 * builds itself again the next time it comes to the front.
 */
class EngineSeat(private val activity: FragmentActivity) : ExclusiveAppComponent<Activity> {
    private var isSeated = false

    fun take(engine: FlutterEngine) {
        if (isSeated) return
        engine.activityControlSurface.attachToActivity(this, activity.lifecycle)
        InkEngine.noteTaken()
        isSeated = true
    }

    fun release(engine: FlutterEngine) {
        if (!isSeated) return
        isSeated = false
        engine.activityControlSurface.detachFromActivity()
    }

    /** Another activity (the app's own) took the engine. */
    override fun detachFromFlutterEngine() {
        isSeated = false
    }

    override fun getAppComponent(): Activity = activity
}
