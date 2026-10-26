package com.fuzzzycore.ink

import android.app.Activity
import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PersistableBundle
import android.view.WindowManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

/**
 * The native side of the screen and copy guard (`screen_guard.dart`,
 * `copy_guard.dart`).
 *
 * - `setSecure`: `FLAG_SECURE` on the window while a sensitive screen is
 *   visible, so screenshots, screen recordings and the recents thumbnail come
 *   out blank.
 * - `copy`: puts text on the clipboard under a label only this app knows; a
 *   sensitive copy carries `EXTRA_IS_SENSITIVE`, which keeps it out of the
 *   clipboard preview (Android 13+) and out of keyboards' clipboard history.
 * - `clearIfOurs`: empties the clipboard only while it still holds that copy,
 *   judged by the label alone, so another app's text is never read.
 *
 * A sensitive copy (a safe password) is cleared even when the app is in the
 * background (security review 2026-10-26): from Android 10 a background app
 * cannot look at the clipboard, so the old check waited for the app to come
 * back, which it often never did. Its expiry is timed here, on the main
 * looper, which runs while the process lives, and it also runs when the
 * activity is destroyed; without focus the clip is cleared with
 * `clearPrimaryClip` (API 28+), which needs no read. The cost: text the user
 * copied in another app within those seconds is cleared too. Sealed output
 * that "Lock from other apps" copies comes marked sensitive for the same
 * reason (the person pastes it in another app). A killed process clears
 * nothing then; its copy is cleared at the app's next start, the first time
 * the app may look ([clearLeftover]), and Android 13+ drops the clip after
 * about an hour anyway.
 *
 * The guard belongs to the engine, not to one activity: with "Lock from
 * other apps" the engine outlives [MainActivity] and serves the selection
 * sheet too (`anywhere/InkEngine.kt`). The activity that shows the app's
 * screens [attach]es itself; a protection asked for while none is attached is
 * kept and applied to the next one, so a private screen is never shown
 * unprotected after the app's activity is built again.
 */
class Guard(context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.fuzzzycore.ink/guard"
        private const val LABEL_PREFIX = "fuzzzy-ink-"

        /** `ClipDescription.EXTRA_IS_SENSITIVE`, which keyboards read before API 33 too. */
        private const val EXTRA_IS_SENSITIVE = "android.content.extra.IS_SENSITIVE"

        /** Once per process: a copy an earlier run left was looked for. */
        private var isLeftoverChecked = false
    }

    private val appContext = context.applicationContext
    private var ourLabel: String? = null
    private var ourIsSensitive = false
    private var isSecureAsked = false
    private val handler = Handler(Looper.getMainLooper())
    private val expire = Runnable { clearIfOurs() }

    /** The activity showing the app's screens now; null while none is. */
    private var activity: Activity? = null

    private val clipboard: ClipboardManager
        get() = appContext.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager

    /** [activity] shows the app's screens now: it gets the asked protection. */
    fun attach(activity: Activity) {
        this.activity = activity
        applySecure(activity)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setSecure" -> {
                setSecure(call.arguments as? Boolean ?: false)
                result.success(true)
            }
            "copy" -> {
                val text = call.argument<String>("text")
                if (text == null) {
                    result.error("badArguments", "text is missing", null)
                    return
                }
                val expiresInMs = call.argument<Number>("expiresInMs")?.toLong()
                copy(text, call.argument<Boolean>("sensitive") ?: false, expiresInMs)
                result.success(true)
            }
            "clearIfOurs" -> result.success(clearIfOurs())
            else -> result.notImplemented()
        }
    }

    private fun setSecure(isSecure: Boolean) {
        isSecureAsked = isSecure
        activity?.let(::applySecure)
    }

    private fun applySecure(activity: Activity) {
        if (isSecureAsked) {
            activity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            activity.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    private fun copy(text: String, isSensitive: Boolean, expiresInMs: Long?) {
        val label = LABEL_PREFIX + UUID.randomUUID()
        val clip = ClipData.newPlainText(label, text)
        if (isSensitive) {
            val key = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                ClipDescription.EXTRA_IS_SENSITIVE
            } else {
                EXTRA_IS_SENSITIVE
            }
            clip.description.extras = PersistableBundle().apply { putBoolean(key, true) }
        }
        clipboard.setPrimaryClip(clip)
        ourLabel = label
        ourIsSensitive = isSensitive
        handler.removeCallbacks(expire)
        if (isSensitive && expiresInMs != null && expiresInMs > 0) {
            handler.postDelayed(expire, expiresInMs)
        }
    }

    /**
     * The app has focus for the first time in this process: a copy an
     * earlier run made (its label, never its text, says so) and could not
     * clear because the process was killed goes now, as at a lock.
     */
    fun clearLeftover() {
        if (isLeftoverChecked) return
        isLeftoverChecked = true
        val label = clipboard.primaryClipDescription?.label?.toString() ?: return
        if (!label.startsWith(LABEL_PREFIX) || label == ourLabel) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            clipboard.clearPrimaryClip()
        } else {
            clipboard.setPrimaryClip(ClipData.newPlainText("", ""))
        }
    }

    /** [activity] is going away: a sensitive copy does not outlive it. */
    fun onDestroy(activity: Activity) {
        if (this.activity !== activity) return
        handler.removeCallbacks(expire)
        if (ourIsSensitive) clearIfOurs()
        this.activity = null
    }

    /** Answers `cleared`, `notOurs` or `unavailable` (see `ClipboardClearResult`). */
    private fun clearIfOurs(): String {
        val label = ourLabel ?: return "notOurs"
        // From Android 10 an app without focus sees no clipboard at all. A
        // sensitive copy is cleared blind; anything else waits for focus.
        if (activity?.hasWindowFocus() != true) {
            if (!ourIsSensitive || Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
                return "unavailable"
            }
            clipboard.clearPrimaryClip()
            forget()
            return "cleared"
        }
        val description = clipboard.primaryClipDescription
        if (description?.label?.toString() != label) {
            forget()
            return "notOurs"
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            clipboard.clearPrimaryClip()
        } else {
            clipboard.setPrimaryClip(ClipData.newPlainText("", ""))
        }
        forget()
        return "cleared"
    }

    private fun forget() {
        handler.removeCallbacks(expire)
        ourLabel = null
        ourIsSensitive = false
    }
}
