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
) {
    companion object {
        fun of(answer: ChannelAnswer.Ok) = AnywhereStatus(
            isOn = answer.flag("enabled"),
            isSettingKnown = answer.flag("settingKnown"),
            isUnlocked = answer.flag("unlocked"),
            isSetUp = answer.flag("setUp"),
            canUseBiometric = answer.string("biometric") == "on",
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
    ) : UiState {
        val selected: Person? get() = people.firstOrNull { it.id == selectedId }
    }

    /** The selected text is already locked: offer Open (or Open in Fuzzzy Ink). */
    data class Sealed(
        val kind: SealedKind,
        val personName: String?,
        val isBusy: Boolean = false,
    ) : UiState

    /** Locked. [returnText] is the sealed output that replaces the selection, if it does. */
    data class Done(
        val personName: String,
        val outcome: Outcome,
        val returnText: String? = null,
    ) : UiState

    data class Problem(val kind: ProblemKind, val name: String? = null) : UiState

    /** The sheet goes away. [returnText] is sealed output only, never anything else. */
    data class Finished(val returnText: String?) : UiState
}

enum class SealedKind { Message, ForTheApp }

enum class Outcome { PutInPlace, Copied }

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
