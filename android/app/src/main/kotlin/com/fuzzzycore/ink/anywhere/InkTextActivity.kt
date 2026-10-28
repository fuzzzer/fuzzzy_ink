package com.fuzzzycore.ink.anywhere

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.fuzzzycore.ink.MainActivity
import com.fuzzzycore.ink.anywhere.ui.InkSheet
import com.fuzzzycore.ink.anywhere.ui.InkSheetTheme
import io.flutter.embedding.engine.FlutterEngine
import kotlinx.coroutines.flow.Flow

/**
 * "Fuzzzy Ink" in other apps' text selection menu (`ACTION_PROCESS_TEXT`),
 * and the "Write sealed" sheet the Quick Settings tile opens.
 *
 * A translucent activity of its own (the app's main activity is
 * `singleTask`, which would answer a result request at once) that shows a
 * Material 3 bottom sheet over the other app. It talks to the app's one
 * engine ([InkEngine]); Dart unlocks, locks and opens. The sheet's window is
 * kept out of screenshots and recordings (`FLAG_SECURE`, and the sheet's own
 * window too) and hides other apps' overlays while it is up (Android 12+).
 *
 * The only text it hands back to the other app is the sealed output of a
 * Lock, in place of an editable selection (`EXTRA_PROCESS_TEXT`). Opened text
 * never comes here: it shows on the app's own private screen.
 */
class InkTextActivity : FragmentActivity() {
    private lateinit var engine: FlutterEngine
    private lateinit var seat: EngineSeat
    private lateinit var channel: AnywhereChannel

    /** The person went on in Fuzzzy Ink itself (Open, Open in Fuzzzy Ink, Open Fuzzzy Ink). */
    private var isHandedOver = false

    /** "Lock again after each use" was asked for already (once per sheet). */
    private var isRelockSent = false

    private val viewModel: SheetViewModel by viewModels {
        SheetViewModelFactory(sheetRequest(), EnginePort(), PreferencesDraftNote(applicationContext), PreferencesAutoCopy(applicationContext))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) window.setHideOverlayWindows(true)
        if (!InkEngine.isInBuild(this)) {
            finish()
            return
        }
        engine = InkEngine.obtain(this)
        seat = EngineSeat(this)
        channel = AnywhereChannel(engine.dartExecutor.binaryMessenger)
        setContent {
            InkSheetTheme {
                InkSheet(state = viewModel.state, actions = viewModel, onFinished = ::finishWith)
            }
        }
    }

    /** The sheet may be the app's first window this run: an earlier run's copy goes (Guard.clearLeftover). */
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) InkEngine.guard?.clearLeftover()
    }

    private fun sheetRequest(): SheetRequest = SheetRequest.of(
        action = intent?.action,
        text = intent?.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT),
        isReadOnly = intent?.getBooleanExtra(Intent.EXTRA_PROCESS_TEXT_READONLY, true) ?: true,
        isForResult = callingActivity != null,
        callingPackage = callingPackage,
        ownPackage = packageName,
    )

    /** Sealed output only ([UiState.Finished.returnText]); anything else answers "cancelled". */
    private fun finishWith(returnText: String?) {
        if (isFinishing) return
        // At once, not at teardown: the next sheet may already be up by then.
        relockOnce()
        if (returnText != null) {
            setResult(RESULT_OK, Intent().putExtra(Intent.EXTRA_PROCESS_TEXT, returnText))
        } else {
            setResult(RESULT_CANCELED)
        }
        finish()
        @Suppress("DEPRECATION")
        overridePendingTransition(0, 0)
    }

    override fun onDestroy() {
        if (isFinishing && ::engine.isInitialized) {
            relockOnce()
            seat.release(engine)
        }
        super.onDestroy()
    }

    /**
     * Whatever happened: "Lock again after each use" (Dart decides whether
     * this entry point unlocked the app and whether to lock), unless the
     * person went on in the app itself, which is in front with its own
     * auto-lock.
     */
    private fun relockOnce() {
        if (isRelockSent || isHandedOver || !::engine.isInitialized) return
        isRelockSent = true
        channel.send("relock")
    }

    private inner class EnginePort : SheetPort {
        override suspend fun call(method: String, arguments: Map<String, Any?>) =
            channel.call(method, arguments)

        override val events: Flow<AnywhereEvent> get() = AnywhereChannel.events

        override val isStarting: Boolean get() = InkEngine.isStarting

        override fun takeEngineForPrompt() = seat.take(engine)

        override fun bringInkForward() {
            isHandedOver = true
            seat.release(engine)
            startActivity(
                Intent(this@InkTextActivity, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT),
            )
        }
    }
}

/** The one-time draft note's mark: a flag only, never text. */
private class PreferencesDraftNote(context: Context) : DraftNote {
    private val preferences = context.getSharedPreferences("ink_anywhere_sheet", Context.MODE_PRIVATE)

    override val isSeen: Boolean get() = preferences.getBoolean(KEY, false)

    override fun markSeen() {
        preferences.edit().putBoolean(KEY, true).apply()
    }

    private companion object {
        const val KEY = "draftNoteSeen"
    }
}

/** "Copy automatically next time": a flag only, never text. */
private class PreferencesAutoCopy(context: Context) : AutoCopy {
    private val preferences = context.getSharedPreferences("ink_anywhere_sheet", Context.MODE_PRIVATE)

    override val isOn: Boolean get() = preferences.getBoolean(KEY, false)

    override fun set(isOn: Boolean) {
        preferences.edit().putBoolean(KEY, isOn).apply()
    }

    private companion object {
        const val KEY = "copyAutomatically"
    }
}

private class SheetViewModelFactory(
    private val request: SheetRequest,
    private val port: SheetPort,
    private val note: DraftNote,
    private val autoCopy: AutoCopy,
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T =
        SheetViewModel(request, port, note, autoCopy) as T
}
