package com.fuzzzycore.ink.anywhere

import android.view.inputmethod.EditorInfo
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.platform.ClipboardManager
import androidx.compose.ui.platform.TextToolbar
import androidx.compose.ui.platform.TextToolbarStatus
import androidx.compose.ui.text.AnnotatedString
import com.fuzzzycore.ink.anywhere.ui.PasteOnlyClipboard
import com.fuzzzycore.ink.anywhere.ui.PasteOnlyToolbar
import com.fuzzzycore.ink.anywhere.ui.withNoLearning
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** The sheet's own text fields: text typed there leaves only through Lock. */
class SealedTextInputTest {
    private class FakeToolbar : TextToolbar {
        var shown: List<(() -> Unit)?>? = null
        var hidden = 0
        override val status = TextToolbarStatus.Hidden

        override fun showMenu(
            rect: Rect,
            onCopyRequested: (() -> Unit)?,
            onPasteRequested: (() -> Unit)?,
            onCutRequested: (() -> Unit)?,
            onSelectAllRequested: (() -> Unit)?,
        ) {
            shown = listOf(onCopyRequested, onPasteRequested, onCutRequested, onSelectAllRequested)
        }

        override fun hide() {
            hidden++
        }
    }

    private class FakeClipboard(var held: AnnotatedString? = null) : ClipboardManager {
        override fun setText(annotatedString: AnnotatedString) {
            held = annotatedString
        }

        override fun getText(): AnnotatedString? = held
    }

    @Test
    fun `the selection toolbar offers Paste only`() {
        val system = FakeToolbar()
        val toolbar = PasteOnlyToolbar(system)
        toolbar.showMenu(Rect.Zero, onCopyRequested = {}, onPasteRequested = {}, onCutRequested = {}, onSelectAllRequested = {})
        val (copy, paste, cut, selectAll) = system.shown!!
        assertNull(copy)
        assertNotNull(paste)
        assertNull(cut)
        assertNull(selectAll)
    }

    @Test
    fun `with nothing to paste, no toolbar shows`() {
        val system = FakeToolbar()
        PasteOnlyToolbar(system).showMenu(Rect.Zero, onCopyRequested = {}, onCutRequested = {})
        assertNull(system.shown)
        assertEquals(1, system.hidden)
    }

    @Test
    fun `nothing typed in the sheet reaches the clipboard, and paste still reads it`() {
        val system = FakeClipboard(AnnotatedString("sealed link"))
        val clipboard = PasteOnlyClipboard(system)
        clipboard.setText(AnnotatedString("meet me at the bridge at six"))
        assertEquals("sealed link", system.held?.text)
        assertEquals("sealed link", clipboard.getText()?.text)
    }

    @Test
    fun `the keyboard is asked not to learn`() {
        val options = withNoLearning(EditorInfo.IME_ACTION_DONE)
        assertTrue(options and EditorInfo.IME_FLAG_NO_PERSONALIZED_LEARNING != 0)
        assertEquals(EditorInfo.IME_ACTION_DONE, options and EditorInfo.IME_MASK_ACTION)
    }
}
