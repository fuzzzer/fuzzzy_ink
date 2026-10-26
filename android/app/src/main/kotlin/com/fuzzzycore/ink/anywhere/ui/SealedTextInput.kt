package com.fuzzzycore.ink.anywhere.ui

import android.view.inputmethod.EditorInfo
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.platform.ClipboardManager
import androidx.compose.ui.platform.InterceptPlatformTextInput
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalTextToolbar
import androidx.compose.ui.platform.PlatformTextInputMethodRequest
import androidx.compose.ui.platform.TextToolbar
import androidx.compose.ui.platform.TextToolbarStatus
import androidx.compose.ui.text.AnnotatedString

/**
 * Around the sheet's own text fields (the message on "Write sealed", the
 * master password): what is typed there stays there (RESEARCH native code
 * rule 6, security review 2026-10-26).
 *
 * - The selection toolbar offers Paste only: no Copy, Cut, Select all or
 *   another app's text action.
 * - Nothing in the fields can write the clipboard, so the copy and cut
 *   shortcuts of a hardware keyboard do nothing either. Paste still reads it.
 * - The keyboard is asked not to learn from what is typed
 *   (`IME_FLAG_NO_PERSONALIZED_LEARNING`); the fields also turn autocorrect
 *   off. A keyboard that ignores the request is outside the threat model.
 */
@OptIn(ExperimentalComposeUiApi::class)
@Composable
internal fun SealedTextInput(content: @Composable () -> Unit) {
    val systemToolbar = LocalTextToolbar.current
    val systemClipboard = LocalClipboardManager.current
    val toolbar = remember(systemToolbar) { PasteOnlyToolbar(systemToolbar) }
    val clipboard = remember(systemClipboard) { PasteOnlyClipboard(systemClipboard) }
    CompositionLocalProvider(LocalTextToolbar provides toolbar, LocalClipboardManager provides clipboard) {
        InterceptPlatformTextInput(
            interceptor = { request, nextHandler ->
                nextHandler.startInputMethod(NoLearningRequest(request))
            },
            content = content,
        )
    }
}

/** The system's selection toolbar with Paste as its only item. */
internal class PasteOnlyToolbar(private val system: TextToolbar) : TextToolbar {
    override val status: TextToolbarStatus get() = system.status

    override fun hide() = system.hide()

    override fun showMenu(
        rect: Rect,
        onCopyRequested: (() -> Unit)?,
        onPasteRequested: (() -> Unit)?,
        onCutRequested: (() -> Unit)?,
        onSelectAllRequested: (() -> Unit)?,
    ) {
        if (onPasteRequested == null) {
            system.hide()
        } else {
            system.showMenu(rect, onPasteRequested = onPasteRequested)
        }
    }
}

/** Reads the clipboard for Paste; never writes it. */
internal class PasteOnlyClipboard(private val system: ClipboardManager) : ClipboardManager {
    override fun setText(annotatedString: AnnotatedString) = Unit

    override fun getText(): AnnotatedString? = system.getText()

    override fun hasText(): Boolean = system.hasText()
}

/** The field's own input request, with the keyboard asked not to learn. */
private class NoLearningRequest(private val request: PlatformTextInputMethodRequest) :
    PlatformTextInputMethodRequest {
    override fun createInputConnection(outAttributes: EditorInfo) =
        request.createInputConnection(outAttributes).also {
            outAttributes.imeOptions = withNoLearning(outAttributes.imeOptions)
        }
}

internal fun withNoLearning(imeOptions: Int): Int = imeOptions or EditorInfo.IME_FLAG_NO_PERSONALIZED_LEARNING
