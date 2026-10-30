package com.fuzzzycore.ink.anywhere

/** What the sheet was opened with. */
data class SheetRequest(
    /** Text the person selected in the other app; null for "Write sealed". */
    val selectedText: String?,
    /** The selection can be replaced with the sealed output (an editable field that waits for it). */
    val canReplace: Boolean,
    /** The calling app's package, for "the person last used here"; null when Android does not say. */
    val sourceApp: String?,
) {
    companion object {
        const val ACTION_PROCESS_TEXT = "android.intent.action.PROCESS_TEXT"

        /**
         * From the intent's parts. A blank selection means "Write sealed"; it
         * is still replaced in place when the field is editable. The calling
         * package is Android's own record of who asked (it cannot be faked);
         * a caller that started the sheet without waiting for a result has
         * none, and gets no remembered person (owner's answer, 2026-10-26).
         */
        fun of(
            action: String?,
            text: CharSequence?,
            isReadOnly: Boolean,
            isForResult: Boolean,
            callingPackage: String?,
            ownPackage: String,
        ): SheetRequest {
            val selected = text?.toString()?.takeIf { it.isNotBlank() }
            return SheetRequest(
                selectedText = selected,
                canReplace = action == ACTION_PROCESS_TEXT && !isReadOnly && isForResult,
                sourceApp = callingPackage?.takeIf { it.isNotBlank() && it != ownPackage },
            )
        }
    }
}

/**
 * Text another app selected, as the sheet shows it. Another app chooses
 * this text, so nothing in it may hide or reorder words: bidirectional
 * controls and invisible characters are shown as their codes ("[U+202E]").
 * Only the display changes; Lock takes the text as it came.
 */
object SelectedText {
    /**
     * Controls, direction marks and overrides, and characters that take no
     * space or look like a space. Joiners and variation selectors stay: emoji
     * and some scripts need them, and they hide no words.
     */
    private val hiding = Regex(
        "[\\u0000-\\u0008\\u000B\\u000C\\u000E-\\u001F\\u007F-\\u009F\\u00AD\\u061C\\u115F\\u1160\\u180E" +
            "\\u200B\\u200E\\u200F\\u202A-\\u202E\\u2060-\\u2064\\u2066-\\u2069\\u3164\\uFEFF\\uFFA0\\uFFF9-\\uFFFB]",
    )

    fun visible(text: String): String =
        hiding.replace(text) { match -> "[U+%04X]".format(match.value[0].code) }

    /** The length the person is told: characters as they count them. */
    fun length(text: String): Int = text.codePointCount(0, text.length)
}

/** One of the person's connected people. */
data class Person(
    val id: String,
    val name: String,
    val isVerified: Boolean,
    val isLastUsedHere: Boolean,
)

/** `status` (CHANNEL.md section 2). */
data class AnywhereStatus(
    val isOn: Boolean,
    val isSettingKnown: Boolean,
    val isUnlocked: Boolean,
    val isSetUp: Boolean,
    val canUseBiometric: Boolean,
    /** The app is still reading whether it has a master password. */
    val isStarting: Boolean = false,
) {
    companion object {
        fun of(answer: ChannelAnswer.Ok) = AnywhereStatus(
            isOn = answer.flag("enabled"),
            isSettingKnown = answer.flag("settingKnown"),
            isUnlocked = answer.flag("unlocked"),
            isSetUp = answer.flag("setUp"),
            canUseBiometric = answer.string("biometric") == "on",
            isStarting = answer.flag("starting"),
        )
    }
}

/** The sheet, one state at a time. Views only read it and send actions. */
sealed interface UiState {
    /** Asking the app where it stands (it may be starting). */
    data object Starting : UiState

    /** Unlock first: the fingerprint or face prompt, or the master password. */
    data class Locked(
        val canUseBiometric: Boolean,
        /** The master password being typed; cleared the moment it is sent. */
        val password: String = "",
        val isBusy: Boolean = false,
        val isWrong: Boolean = false,
        val waitSeconds: Int = 0,
        val isBiometricChanged: Boolean = false,
    ) : UiState

    /** Who it is for, and what: the selected text or the sheet's own field. */
    data class Writing(
        val people: List<Person>,
        val selectedId: String?,
        val isPicking: Boolean,
        val draft: String,
        val selectedText: String?,
        val showsDraftNote: Boolean,
        val isLocking: Boolean = false,
        val problem: LockProblem? = null,
        /** All of [selectedText] has been on screen (always true for "Write sealed"). */
        val hasSeenSelection: Boolean = selectedText == null,
    ) : UiState {
        val selected: Person? get() = people.firstOrNull { it.id == selectedId }

        /** A person is chosen and every word Lock would take has been seen. */
        val canLock: Boolean get() = selected != null && !isPicking && hasSeenSelection
    }

    /** The selected text is already locked: offer Open (or Open in Fuzzzy Ink). */
    data class Sealed(
        val kind: SealedKind,
        val personName: String?,
        val isBusy: Boolean = false,
    ) : UiState

    /**
     * Locked. [returnText] is the sealed output that replaces the selection,
     * if it does. [canCopy]: not copied yet, Copy is offered.
     */
    data class Done(
        val personName: String,
        val outcome: Outcome,
        val returnText: String? = null,
        val canCopy: Boolean = false,
        val copiesAutomatically: Boolean = false,
        /** Lock copied it by itself ("Copy automatically next time" was on). */
        val wasCopiedAutomatically: Boolean = false,
        val isCopying: Boolean = false,
    ) : UiState

    data class Problem(val kind: ProblemKind, val name: String? = null) : UiState

    /** The sheet goes away. [returnText] is sealed output only, never anything else. */
    data class Finished(val returnText: String?) : UiState
}

enum class SealedKind { Message, ForTheApp }

enum class Outcome { PutInPlace, PutInPlaceAndCopied, Copied, Ready }

enum class LockProblem { EmptyText, Failed }

enum class ProblemKind {
    NotSetUp,
    NotReady,
    NoPeople,
    AlreadyOpened,
    NotYours,
    Damaged,
    TooOld,
    NewerApp,
    NotFuzzzy,
    Failed;

    /** These are fixed in the app itself: the problem offers to open it. */
    val opensTheApp: Boolean get() = this == NotSetUp || this == NotReady || this == NoPeople
}
