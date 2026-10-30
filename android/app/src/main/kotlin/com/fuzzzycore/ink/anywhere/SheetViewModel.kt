package com.fuzzzycore.ink.anywhere

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/** What the sheet needs from the app around it; a fake in tests. */
interface SheetPort {
    suspend fun call(method: String, arguments: Map<String, Any?> = emptyMap()): ChannelAnswer

    val events: Flow<AnywhereEvent>

    /** The app's engine was started a moment ago: a missing answer means "wait". */
    val isStarting: Boolean

    /** The fingerprint or face prompt shows on the activity the engine is attached to. */
    fun takeEngineForPrompt()

    /** Brings Fuzzzy Ink's own screen forward. */
    fun bringInkForward()
}

/** "Text typed in another app may already be saved": shown once, ever. */
interface DraftNote {
    val isSeen: Boolean
    fun markSeen()
}

/**
 * "Copy automatically next time": off at first, so the first Lock shows a
 * Copy button; on, every Lock copies by itself (owner, 2026-10-28). A flag
 * only, never text.
 */
interface AutoCopy {
    val isOn: Boolean
    fun set(isOn: Boolean)
}

/** Everything a person can do on the sheet. */
interface SheetActions {
    fun unlockWithBiometrics() {}
    fun onPasswordChange(value: String) {}
    fun unlockWithPassword() {}
    fun choose(personId: String) {}
    fun changePerson() {}
    fun onDraftChange(value: String) {}
    fun dismissDraftNote() {}
    fun sawWholeSelection() {}
    fun lock() {}
    fun copy() {}
    fun setAutoCopy(isOn: Boolean) {}
    fun open() {}
    fun openApp() {}
    fun close() {}
}

/**
 * The sheet's one state owner (RESEARCH native code rule 2). It only asks
 * the app over the channel: no cryptography, no network, no logs, and
 * nothing it holds is stored. Opened text never reaches it; the only text it
 * hands back to the other app is sealed output from `lock`.
 */
class SheetViewModel(
    private val request: SheetRequest,
    private val port: SheetPort,
    private val note: DraftNote,
    private val autoCopy: AutoCopy,
) : ViewModel(), SheetActions {
    private val mutableState = MutableStateFlow<UiState>(UiState.Starting)
    val state: StateFlow<UiState> = mutableState.asStateFlow()

    private var flow: Job? = null
    private var countdown: Job? = null
    private var hasPrompted = false

    /** Whose message the selected text is (from `peek`), for the Open wording. */
    private var senderName: String? = null

    init {
        viewModelScope.launch { port.events.collect(::onEvent) }
        restart()
    }

    private fun restart() {
        if (mutableState.value is UiState.Finished) return
        flow?.cancel()
        flow = viewModelScope.launch { start() }
    }

    private suspend fun start() {
        val status = readStatus() ?: return
        when {
            !status.isSetUp -> problem(ProblemKind.NotSetUp)
            status.isSettingKnown && !status.isOn -> finish()
            !status.isUnlocked -> showLocked(status.canUseBiometric)
            else -> continueUnlocked()
        }
    }

    /** `status`, waiting while the app is still starting. */
    private suspend fun readStatus(): AnywhereStatus? {
        while (true) {
            when (val answer = port.call("status")) {
                is ChannelAnswer.Ok -> {
                    val status = AnywhereStatus.of(answer)
                    // Not set up and done starting: there is no master password.
                    if (status.isSetUp || !status.isStarting || !port.isStarting) return status
                }
                ChannelAnswer.Missing -> if (!port.isStarting) {
                    problem(ProblemKind.NotReady)
                    return null
                }
                is ChannelAnswer.Refused -> {
                    refused(answer)
                    return null
                }
            }
            delay(STARTING_POLL_MS)
        }
    }

    private fun showLocked(canUseBiometric: Boolean) {
        mutableState.value = UiState.Locked(canUseBiometric = canUseBiometric)
        // Once, as the app's own unlock screen does: the person chose Fuzzzy Ink.
        if (canUseBiometric && !hasPrompted) {
            hasPrompted = true
            unlockWithBiometrics()
        }
    }

    override fun unlockWithBiometrics() {
        val locked = mutableState.value as? UiState.Locked ?: return
        if (locked.isBusy || locked.waitSeconds > 0 || !locked.canUseBiometric) return
        mutableState.value = locked.copy(isBusy = true, isWrong = false)
        flow = viewModelScope.launch {
            port.takeEngineForPrompt()
            when (val answer = port.call("unlock")) {
                is ChannelAnswer.Ok -> continueUnlocked()
                is ChannelAnswer.Refused -> when (answer.code) {
                    "biometricOff" -> mutableState.value = locked.copy(canUseBiometric = false)
                    "biometricGone" -> mutableState.value =
                        locked.copy(canUseBiometric = false, isBiometricChanged = true)
                    "notUnlocked" -> mutableState.value = locked
                    else -> refused(answer)
                }
                ChannelAnswer.Missing -> problem(ProblemKind.NotReady)
            }
        }
    }

    override fun onPasswordChange(value: String) {
        val locked = mutableState.value as? UiState.Locked ?: return
        if (locked.isBusy) return
        mutableState.value = locked.copy(password = value, isWrong = false)
    }

    override fun unlockWithPassword() {
        val locked = mutableState.value as? UiState.Locked ?: return
        if (locked.isBusy || locked.waitSeconds > 0 || locked.password.isEmpty()) return
        val password = locked.password
        // Sent once and cleared at once (CHANNEL.md, unlockWithPassword).
        val sent = locked.copy(password = "", isWrong = false)
        mutableState.value = sent.copy(isBusy = true)
        flow = viewModelScope.launch {
            when (val answer = port.call("unlockWithPassword", mapOf("password" to password))) {
                is ChannelAnswer.Ok -> continueUnlocked()
                is ChannelAnswer.Refused -> when (answer.code) {
                    "wrongPassword" -> wait(sent.copy(isWrong = true), answer.waitSeconds)
                    "lockedOut" -> wait(sent, answer.waitSeconds)
                    "notUnlocked", "badRequest" -> mutableState.value = sent
                    else -> refused(answer)
                }
                ChannelAnswer.Missing -> problem(ProblemKind.NotReady)
            }
        }
    }

    /** The app's own wait after wrong passwords, counted down on the sheet. */
    private fun wait(locked: UiState.Locked, seconds: Int) {
        countdown?.cancel()
        mutableState.value = locked.copy(waitSeconds = seconds)
        if (seconds <= 0) return
        countdown = viewModelScope.launch {
            for (left in seconds - 1 downTo 0) {
                delay(1_000)
                val current = mutableState.value as? UiState.Locked ?: return@launch
                mutableState.value = current.copy(waitSeconds = left)
            }
        }
    }

    /** Unlocked: what was selected decides what comes next. */
    private suspend fun continueUnlocked() {
        // The switch is sealed in the store: it is known now.
        val status = port.call("status")
        if (status is ChannelAnswer.Ok) {
            val known = AnywhereStatus.of(status)
            if (known.isSettingKnown && !known.isOn) return finish()
        }
        val text = request.selectedText
        if (text != null && !isPlainText(text)) return
        loadPeople()
    }

    /**
     * `peek`: is the selected text already locked? The person brought it to
     * Fuzzzy Ink themselves (they chose the menu item); nothing is opened.
     */
    private suspend fun isPlainText(text: String): Boolean {
        when (val answer = port.call("peek", mapOf("text" to text))) {
            is ChannelAnswer.Ok -> when (answer.string("kind")) {
                "message" -> {
                    senderName = answer.string("personName")
                    mutableState.value = UiState.Sealed(SealedKind.Message, senderName)
                }
                "invite", "reply", "passwordText" ->
                    mutableState.value = UiState.Sealed(SealedKind.ForTheApp, null)
                "newerApp" -> problem(ProblemKind.NewerApp)
                "damaged" -> problem(ProblemKind.Damaged)
                else -> return true
            }
            is ChannelAnswer.Refused -> refused(answer)
            ChannelAnswer.Missing -> problem(ProblemKind.NotReady)
        }
        return false
    }

    private suspend fun loadPeople() {
        val arguments = request.sourceApp?.let { mapOf("sourceApp" to it) } ?: emptyMap()
        when (val answer = port.call("people", arguments)) {
            is ChannelAnswer.Ok -> {
                val people = peopleOf(answer)
                if (people.isEmpty()) return problem(ProblemKind.NoPeople)
                val preselected = people.firstOrNull { it.isLastUsedHere } ?: people.singleOrNull()
                mutableState.value = UiState.Writing(
                    people = people,
                    selectedId = preselected?.id,
                    isPicking = preselected == null,
                    draft = "",
                    selectedText = request.selectedText,
                    showsDraftNote = request.selectedText != null && !note.isSeen,
                )
            }
            is ChannelAnswer.Refused -> refused(answer)
            ChannelAnswer.Missing -> problem(ProblemKind.NotReady)
        }
    }

    override fun choose(personId: String) {
        val writing = mutableState.value as? UiState.Writing ?: return
        if (writing.isLocking) return
        mutableState.value = writing.copy(selectedId = personId, isPicking = false)
    }

    override fun changePerson() {
        val writing = mutableState.value as? UiState.Writing ?: return
        if (writing.isLocking) return
        mutableState.value = writing.copy(isPicking = true)
    }

    override fun onDraftChange(value: String) {
        val writing = mutableState.value as? UiState.Writing ?: return
        if (writing.isLocking) return
        mutableState.value = writing.copy(draft = value, problem = null)
    }

    /** The selected text has been on screen to its end: Lock may take it. */
    override fun sawWholeSelection() {
        val writing = mutableState.value as? UiState.Writing ?: return
        if (writing.hasSeenSelection) return
        mutableState.value = writing.copy(hasSeenSelection = true)
    }

    override fun dismissDraftNote() {
        val writing = mutableState.value as? UiState.Writing ?: return
        note.markSeen()
        mutableState.value = writing.copy(showsDraftNote = false)
    }

    /**
     * `lock` for the chosen person. An editable selection gets the sealed
     * output back in its place. With "Copy automatically" on, the app's copy
     * guard also copies it at once (sealed only, cleared after 2 minutes);
     * off, the Done step offers Copy (owner, 2026-10-28).
     */
    override fun lock() {
        val writing = mutableState.value as? UiState.Writing ?: return
        val person = writing.selected ?: return
        // Never words the person could not see (security review 2026-10-26).
        if (writing.isLocking || !writing.canLock) return
        val text = writing.selectedText ?: writing.draft
        if (text.isBlank()) {
            mutableState.value = writing.copy(problem = LockProblem.EmptyText)
            return
        }
        if (writing.showsDraftNote) note.markSeen()
        mutableState.value = writing.copy(isLocking = true, problem = null, showsDraftNote = false)
        val arguments = buildMap<String, Any?> {
            put("personId", person.id)
            put("text", text)
            put("copy", autoCopy.isOn)
            request.sourceApp?.let { put("sourceApp", it) }
        }
        flow = viewModelScope.launch {
            when (val answer = port.call("lock", arguments)) {
                is ChannelAnswer.Ok -> locked(writing, person, answer)
                is ChannelAnswer.Refused -> when (answer.code) {
                    "emptyText" -> mutableState.value = writing.copy(problem = LockProblem.EmptyText)
                    "unknownPerson" -> loadPeople()
                    "failed" -> mutableState.value = writing.copy(problem = LockProblem.Failed)
                    else -> refused(answer)
                }
                ChannelAnswer.Missing -> problem(ProblemKind.NotReady)
            }
        }
    }

    private suspend fun locked(writing: UiState.Writing, person: Person, answer: ChannelAnswer.Ok) {
        val output = answer.string("output")
        if (output == null) {
            mutableState.value = writing.copy(problem = LockProblem.Failed)
            return
        }
        val isCopied = answer.flag("copied")
        val returnText = output.takeIf { request.canReplace }
        val outcome = when {
            returnText != null && isCopied -> Outcome.PutInPlaceAndCopied
            returnText != null -> Outcome.PutInPlace
            isCopied -> Outcome.Copied
            else -> Outcome.Ready
        }
        mutableState.value = UiState.Done(
            personName = person.name,
            outcome = outcome,
            returnText = returnText,
            canCopy = !isCopied,
            copiesAutomatically = autoCopy.isOn,
            wasCopiedAutomatically = isCopied,
        )
        // Copied at once and put in place: nothing left to do here.
        if (outcome == Outcome.PutInPlaceAndCopied) {
            delay(DONE_PAUSE_MS)
            finish(output)
        }
    }

    /** The person's own Copy press: the app copies this use's sealed output, nothing else. */
    override fun copy() {
        val done = mutableState.value as? UiState.Done ?: return
        if (!done.canCopy || done.isCopying) return
        mutableState.value = done.copy(isCopying = true)
        flow = viewModelScope.launch {
            when (val answer = port.call("copy")) {
                is ChannelAnswer.Ok -> if (answer.flag("copied")) {
                    val outcome = if (done.returnText != null) Outcome.PutInPlaceAndCopied else Outcome.Copied
                    mutableState.value = done.copy(outcome = outcome, canCopy = false, isCopying = false)
                    delay(DONE_PAUSE_MS)
                    finish(done.returnText)
                } else {
                    mutableState.value = done.copy(isCopying = false)
                }
                is ChannelAnswer.Refused -> refused(answer)
                ChannelAnswer.Missing -> problem(ProblemKind.NotReady)
            }
        }
    }

    override fun setAutoCopy(isOn: Boolean) {
        autoCopy.set(isOn)
        val done = mutableState.value as? UiState.Done ?: return
        mutableState.value = done.copy(copiesAutomatically = isOn)
    }

    /**
     * The person's own Open press: `open`, then `show` on the app's private
     * screen. The opened text never comes here and never goes back to the
     * other app. An invite, a reply or a password-locked text goes to the
     * app's Open screen instead (`openInApp`).
     */
    override fun open() {
        val sealed = mutableState.value as? UiState.Sealed ?: return
        val text = request.selectedText ?: return
        if (sealed.isBusy) return
        mutableState.value = sealed.copy(isBusy = true)
        flow = viewModelScope.launch {
            if (sealed.kind == SealedKind.ForTheApp) {
                port.bringInkForward()
                when (val answer = port.call("openInApp", mapOf("text" to text))) {
                    is ChannelAnswer.Ok -> finish()
                    is ChannelAnswer.Refused -> refused(answer)
                    ChannelAnswer.Missing -> problem(ProblemKind.NotReady)
                }
                return@launch
            }
            when (val answer = port.call("open", mapOf("text" to text))) {
                is ChannelAnswer.Ok -> show(answer.string("displayId"))
                is ChannelAnswer.Refused -> if (answer.code == "notForAPerson") {
                    mutableState.value = UiState.Sealed(SealedKind.ForTheApp, null)
                } else {
                    refused(answer)
                }
                ChannelAnswer.Missing -> problem(ProblemKind.NotReady)
            }
        }
    }

    private suspend fun show(displayId: String?) {
        if (displayId == null) return problem(ProblemKind.Failed)
        port.bringInkForward()
        when (val answer = port.call("show", mapOf("displayId" to displayId))) {
            is ChannelAnswer.Ok -> finish()
            is ChannelAnswer.Refused -> refused(answer)
            ChannelAnswer.Missing -> problem(ProblemKind.NotReady)
        }
    }

    override fun openApp() {
        port.bringInkForward()
        finish()
    }

    override fun close() {
        val done = mutableState.value as? UiState.Done
        finish(done?.returnText)
    }

    private fun onEvent(event: AnywhereEvent) {
        when (event) {
            // Off, or no master password (Erase everything, Android's Clear
            // storage): ask again, so a cleared app says to set it up first.
            is AnywhereEvent.SettingsChanged -> if (!event.isOn) restart()
            is AnywhereEvent.LockChanged -> if (!event.isUnlocked) onLockedElsewhere()
            AnywhereEvent.ShownClosed -> Unit
        }
    }

    /** The app locked (auto-lock, Lock now): no person list or name stays on screen. */
    private fun onLockedElsewhere() {
        when (val current = mutableState.value) {
            is UiState.Writing, is UiState.Sealed -> restart()
            is UiState.Done -> if (current.returnText == null) finish()
            else -> Unit
        }
    }

    /** A refusal any call can get (CHANNEL.md section 4). */
    private fun refused(answer: ChannelAnswer.Refused) {
        when (answer.code) {
            "locked" -> restart()
            "disabled" -> finish()
            "notSetUp" -> problem(ProblemKind.NotSetUp)
            "notReady" -> problem(ProblemKind.NotReady)
            "alreadyOpened" -> problem(ProblemKind.AlreadyOpened, senderName)
            "notFromYourPeople" -> problem(ProblemKind.NotYours)
            "damaged" -> problem(ProblemKind.Damaged)
            "tooOld" -> problem(ProblemKind.TooOld, senderName)
            "newerApp" -> problem(ProblemKind.NewerApp)
            "notFuzzzy" -> problem(ProblemKind.NotFuzzzy)
            else -> problem(ProblemKind.Failed)
        }
    }

    private fun problem(kind: ProblemKind, name: String? = null) {
        mutableState.value = UiState.Problem(kind, name)
    }

    /** Final: nothing still running (a status read, an unlock) can bring a step back. */
    private fun finish(returnText: String? = null) {
        if (mutableState.value is UiState.Finished) return
        flow?.cancel()
        countdown?.cancel()
        mutableState.value = UiState.Finished(returnText)
    }

    companion object {
        const val STARTING_POLL_MS = 150L
        const val DONE_PAUSE_MS = 650L

        fun peopleOf(answer: ChannelAnswer.Ok): List<Person> =
            (answer.values["people"] as? List<*>).orEmpty().mapNotNull { item ->
                val person = item as? Map<*, *> ?: return@mapNotNull null
                val id = person["id"] as? String ?: return@mapNotNull null
                Person(
                    id = id,
                    name = person["name"] as? String ?: return@mapNotNull null,
                    isVerified = person["verified"] == true,
                    isLastUsedHere = person["lastUsedHere"] == true,
                )
            }
    }
}
