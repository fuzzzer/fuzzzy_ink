package com.fuzzzycore.ink.anywhere

import android.content.Context

/**
 * The sheet's own two flags, never text: the one-time draft note was seen,
 * and "Copy automatically next time". Settings shows and changes the second
 * over the channel (`sheetFlags`, `setCopyAutomatically`), and "Erase
 * everything" forgets both (`forgetSheet`, CHANNEL.md section 3).
 */
object SheetPreferences {
    private const val NAME = "ink_anywhere_sheet"
    private const val DRAFT_NOTE_SEEN = "draftNoteSeen"
    private const val COPY_AUTOMATICALLY = "copyAutomatically"

    fun draftNote(context: Context): DraftNote = object : DraftNote {
        override val isSeen: Boolean get() = preferences(context).getBoolean(DRAFT_NOTE_SEEN, false)

        override fun markSeen() {
            preferences(context).edit().putBoolean(DRAFT_NOTE_SEEN, true).apply()
        }
    }

    fun autoCopy(context: Context): AutoCopy = object : AutoCopy {
        override val isOn: Boolean get() = preferences(context).getBoolean(COPY_AUTOMATICALLY, false)

        override fun set(isOn: Boolean) {
            preferences(context).edit().putBoolean(COPY_AUTOMATICALLY, isOn).apply()
        }
    }

    /** Both flags go: the next person starts with the note and with Copy. */
    fun forget(context: Context) {
        preferences(context).edit().clear().commit()
    }

    private fun preferences(context: Context) =
        context.getSharedPreferences(NAME, Context.MODE_PRIVATE)
}
