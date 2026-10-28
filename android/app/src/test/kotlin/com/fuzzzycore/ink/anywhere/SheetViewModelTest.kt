package com.fuzzzycore.ink.anywhere

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

private const val SEALED = "https://ink.fuzzzycore.com/message#AwECc2VhbGVk"
private const val SECRET = "meet me at the bridge at six"
private const val FROM_NINO = "Fuzz/AwECbmlubw"
private const val INVITE = "Fuzz/AwEBaW52aXRl"
private const val PASSWORD = "violet-harbor-lantern-91"

/** The app as the sheet sees it: answers per method, every call kept. */
private class FakeApp : SheetPort, DraftNote, AutoCopy {
    var unlocked = false
    var biometric = "off"
    var settingKnown = true
    var enabled = true
    var setUp = true
    var missingCalls = 0
    val people: MutableList<Map<String, Any>> = mutableListOf(
        mapOf("id" to "nino", "name" to "Nino", "verified" to true, "lastUsedHere" to false),
        mapOf("id" to "giorgi", "name" to "Giorgi", "verified" to false, "lastUsedHere" to false),
    )
    val calls = mutableListOf<Pair<String, Map<String, Any?>>>()
    val overrides = mutableMapOf<String, ChannelAnswer>()
    var takenForPrompt = 0
    var broughtForward = 0
    val flow = MutableSharedFlow<AnywhereEvent>(extraBufferCapacity = 8)
    override var isSeen = false
    override var isOn = false

    override fun set(isOn: Boolean) {
        this.isOn = isOn
    }

    override val events get() = flow
    override var isStarting = false

    override fun takeEngineForPrompt() {
        takenForPrompt++
    }

    override fun bringInkForward() {
        broughtForward++
    }

    override fun markSeen() {
        isSeen = true
    }

    fun called(method: String) = calls.filter { it.first == method }.map { it.second }

    override suspend fun call(method: String, arguments: Map<String, Any?>): ChannelAnswer {
        calls += method to arguments
        if (missingCalls > 0) {
            missingCalls--
            return ChannelAnswer.Missing
        }
        overrides.remove(method)?.let { return it }
        return when (method) {
            "status" -> ChannelAnswer.Ok(
                mapOf(
                    "enabled" to (enabled && (settingKnown || unlocked)),
                    "settingKnown" to (settingKnown || unlocked),
                    "unlocked" to unlocked,
                    "setUp" to setUp,
                    "biometric" to biometric,
                ),
            )
            "unlock" -> {
                unlocked = true
                ChannelAnswer.Ok(mapOf("status" to "unlocked"))
            }
            "unlockWithPassword" -> if (arguments["password"] == PASSWORD) {
                unlocked = true
                ChannelAnswer.Ok(mapOf("status" to "unlocked"))
            } else {
                ChannelAnswer.Refused("wrongPassword")
            }
            "people" -> ChannelAnswer.Ok(mapOf("people" to people.toList()))
            "peek" -> ChannelAnswer.Ok(
                when (arguments["text"]) {
                    FROM_NINO -> mapOf("kind" to "message", "personId" to "nino", "personName" to "Nino")
                    INVITE -> mapOf("kind" to "invite")
                    else -> mapOf("kind" to "notFuzzzy")
                },
            )
            "lock" -> ChannelAnswer.Ok(
                mapOf("output" to SEALED, "kind" to "link", "copied" to (arguments["copy"] == true)),
            )
            "open" -> if (arguments["text"] == FROM_NINO) {
                ChannelAnswer.Ok(
                    mapOf("status" to "opened", "displayId" to "1", "personId" to "nino", "personName" to "Nino"),
                )
            } else {
                ChannelAnswer.Refused("notForAPerson")
            }
            "copy" -> ChannelAnswer.Ok(mapOf("copied" to true))
            "show", "openInApp" -> ChannelAnswer.Ok(mapOf("status" to "shown"))
            else -> ChannelAnswer.Missing
        }
    }
}

@OptIn(ExperimentalCoroutinesApi::class)
class SheetViewModelTest {
    private val dispatcher = StandardTestDispatcher()
    private val app = FakeApp()

    @Before
    fun setUp() = Dispatchers.setMain(dispatcher)

    @After
    fun tearDown() = Dispatchers.resetMain()

    private fun request(text: String?, canReplace: Boolean, sourceApp: String? = "com.whatsapp") =
        SheetRequest(selectedText = text, canReplace = canReplace, sourceApp = sourceApp)

    private fun TestScope.sheet(request: SheetRequest): SheetViewModel {
        val model = SheetViewModel(request, app, app, app)
        advanceUntilIdle()
        return model
    }

    private val SheetViewModel.writing get() = state.value as UiState.Writing

    @Test
    fun `closed while the app is still starting, the sheet stays closed`() = runTest(dispatcher) {
        app.isStarting = true
        app.missingCalls = 3
        val model = SheetViewModel(request(SECRET, canReplace = true), app, app, app)
        runCurrent()
        model.close()
        app.isStarting = false
        advanceUntilIdle()

        // A late status answer never brings a step back over the other app.
        assertEquals(UiState.Finished(null), model.state.value)
    }

    @Test
    fun `the first time, an editable selection gets it in place and Copy is offered`() = runTest(dispatcher) {
        app.unlocked = true
        val model = sheet(request(SECRET, canReplace = true))
        model.choose("nino")
        model.sawWholeSelection()
        model.lock()
        advanceUntilIdle()

        val lock = app.called("lock").single()
        assertEquals(SECRET, lock["text"])
        assertEquals(false, lock["copy"])
        assertEquals("com.whatsapp", lock["sourceApp"])
        assertEquals(UiState.Done("Nino", Outcome.PutInPlace, SEALED, canCopy = true), model.state.value)

        // Copy: the app copies this use's output (nothing is named), then the sheet goes.
        model.copy()
        runCurrent()
        assertEquals(emptyMap<String, Any?>(), app.called("copy").single())
        assertEquals(UiState.Done("Nino", Outcome.PutInPlaceAndCopied, SEALED), model.state.value)
        advanceUntilIdle()
        assertEquals(UiState.Finished(SEALED), model.state.value)
    }

    @Test
    fun `Done without Copy still puts it in place, nothing copied`() = runTest(dispatcher) {
        app.unlocked = true
        val model = sheet(request(SECRET, canReplace = true))
        model.choose("nino")
        model.sawWholeSelection()
        model.lock()
        advanceUntilIdle()
        model.close()
        assertEquals(UiState.Finished(SEALED), model.state.value)
        assertTrue(app.called("copy").isEmpty())
    }

    @Test
    fun `copy automatically, once turned on, copies at every Lock`() = runTest(dispatcher) {
        app.unlocked = true
        val first = sheet(request(SECRET, canReplace = true))
        first.choose("nino")
        first.sawWholeSelection()
        first.lock()
        advanceUntilIdle()
        first.setAutoCopy(true)
        assertTrue(app.isOn)
        assertEquals(true, (first.state.value as UiState.Done).copiesAutomatically)

        val next = sheet(request(SECRET, canReplace = true))
        next.choose("nino")
        next.sawWholeSelection()
        next.lock()
        runCurrent()
        assertEquals(true, app.called("lock").last()["copy"])
        assertEquals(
            UiState.Done("Nino", Outcome.PutInPlaceAndCopied, SEALED, copiesAutomatically = true),
            next.state.value,
        )
        advanceUntilIdle()
        assertEquals(UiState.Finished(SEALED), next.state.value)
    }

    @Test
    fun `a read-only selection offers Copy and nothing goes back`() = runTest(dispatcher) {
        app.unlocked = true
        val model = sheet(request(SECRET, canReplace = false))
        model.choose("giorgi")
        model.sawWholeSelection()
        model.lock()
        advanceUntilIdle()

        assertEquals(false, app.called("lock").single()["copy"])
        assertEquals(UiState.Done("Giorgi", Outcome.Ready, canCopy = true), model.state.value)
        model.copy()
        advanceUntilIdle()
        assertEquals(UiState.Finished(null), model.state.value)
    }

    @Test
    fun `selected text locks only after all of it was on screen`() = runTest(dispatcher) {
        app.unlocked = true
        val model = sheet(request(SECRET, canReplace = true))
        model.choose("nino")
        assertFalse(model.writing.hasSeenSelection)
        assertFalse(model.writing.canLock)
        model.lock()
        advanceUntilIdle()
        assertTrue("nothing is locked before the end was seen", app.called("lock").isEmpty())

        model.sawWholeSelection()
        assertTrue(model.writing.canLock)
        model.lock()
        advanceUntilIdle()
        assertEquals(SECRET, app.called("lock").single()["text"])
    }

    @Test
    fun `write sealed has nothing to read first`() = runTest(dispatcher) {
        app.unlocked = true
        val model = sheet(request(null, canReplace = false))
        assertTrue(model.writing.hasSeenSelection)
    }

    @Test
    fun `selected text shows what would hide or reorder words, and keeps emoji`() {
        val tricky = "pay Nino\u202Etxet\u200B\uFEFF ok"
        assertEquals("pay Nino[U+202E]txet[U+200B][U+FEFF] ok", SelectedText.visible(tricky))
        val family = "\uD83D\uDC69\u200D\uD83D\uDC67 \u2764\uFE0F\nline\tend"
        assertEquals(family, SelectedText.visible(family))
        assertEquals(15, SelectedText.length(family))
    }

    @Test
    fun `write sealed locks the sheet's own text and offers Copy`() = runTest(dispatcher) {
        app.unlocked = true
        val model = sheet(request(null, canReplace = false))
        model.choose("nino")
        model.lock()
        assertEquals(LockProblem.EmptyText, model.writing.problem)
        assertTrue(app.called("lock").isEmpty())

        model.onDraftChange(SECRET)
        model.lock()
        advanceUntilIdle()
        assertEquals(SECRET, app.called("lock").single()["text"])
        assertEquals(false, app.called("lock").single()["copy"])
        assertEquals(UiState.Done("Nino", Outcome.Ready, canCopy = true), model.state.value)
        assertTrue("nothing asks to peek at the sheet's own text", app.called("peek").isEmpty())
    }

    @Test
    fun `opening a sealed message shows it in the app and never hands text back`() = runTest(dispatcher) {
        app.unlocked = true
        val model = sheet(request(FROM_NINO, canReplace = true))
        assertEquals(UiState.Sealed(SealedKind.Message, "Nino"), model.state.value)
        assertTrue("nothing opens before the press", app.called("open").isEmpty())

        model.open()
        advanceUntilIdle()
        assertEquals(FROM_NINO, app.called("open").single()["text"])
        assertEquals("1", app.called("show").single()["displayId"])
        assertEquals(1, app.broughtForward)
        assertEquals(UiState.Finished(null), model.state.value)
        assertTrue(app.called("lock").isEmpty())
    }

    @Test
    fun `an invite goes to the app's Open screen`() = runTest(dispatcher) {
        app.unlocked = true
        val model = sheet(request(INVITE, canReplace = true))
        assertEquals(UiState.Sealed(SealedKind.ForTheApp, null), model.state.value)

        model.open()
        advanceUntilIdle()
        assertEquals(INVITE, app.called("openInApp").single()["text"])
        assertTrue(app.called("open").isEmpty())
        assertEquals(UiState.Finished(null), model.state.value)
    }

    @Test
    fun `open refused as not for a person offers Open in Fuzzzy Ink`() = runTest(dispatcher) {
        app.unlocked = true
        app.overrides["open"] = ChannelAnswer.Refused("notForAPerson")
        val model = sheet(request(FROM_NINO, canReplace = true))
        model.open()
        advanceUntilIdle()
        assertEquals(UiState.Sealed(SealedKind.ForTheApp, null), model.state.value)
    }

    @Test
    fun `already opened says so with the sender's name`() = runTest(dispatcher) {
        app.unlocked = true
        app.overrides["open"] = ChannelAnswer.Refused("alreadyOpened")
        val model = sheet(request(FROM_NINO, canReplace = true))
        model.open()
        advanceUntilIdle()
        assertEquals(UiState.Problem(ProblemKind.AlreadyOpened, "Nino"), model.state.value)
    }

    @Test
    fun `the password is cleared the moment it is sent, and a wrong one says so`() = runTest(dispatcher) {
        val model = sheet(request(SECRET, canReplace = true))
        assertEquals(UiState.Locked(canUseBiometric = false), model.state.value)

        model.onPasswordChange("tulip")
        model.unlockWithPassword()
        val sending = model.state.value as UiState.Locked
        assertEquals("", sending.password)
        assertTrue(sending.isBusy)
        advanceUntilIdle()
        val wrong = model.state.value as UiState.Locked
        assertTrue(wrong.isWrong)
        assertEquals("", wrong.password)

        model.onPasswordChange(PASSWORD)
        model.unlockWithPassword()
        advanceUntilIdle()
        assertTrue(model.state.value is UiState.Writing)
    }

    @Test
    fun `a wait after wrong passwords counts down and blocks the field`() = runTest(dispatcher) {
        app.overrides["unlockWithPassword"] = ChannelAnswer.Refused("lockedOut", waitSeconds = 3)
        val model = sheet(request(null, canReplace = false))
        model.onPasswordChange("tulip")
        model.unlockWithPassword()
        runCurrent()
        assertEquals(3, (model.state.value as UiState.Locked).waitSeconds)

        model.onPasswordChange(PASSWORD)
        model.unlockWithPassword()
        runCurrent()
        assertEquals(1, app.called("unlockWithPassword").size)

        advanceTimeBy(3_100)
        assertEquals(0, (model.state.value as UiState.Locked).waitSeconds)
    }

    @Test
    fun `fingerprint prompts once by itself, on the sheet`() = runTest(dispatcher) {
        app.biometric = "on"
        val model = sheet(request(null, canReplace = false))
        assertEquals(1, app.takenForPrompt)
        assertEquals(1, app.called("unlock").size)
        assertTrue(model.state.value is UiState.Writing)
    }

    @Test
    fun `a cancelled prompt stays on unlock and does not prompt again by itself`() = runTest(dispatcher) {
        app.biometric = "on"
        app.overrides["unlock"] = ChannelAnswer.Refused("notUnlocked")
        val model = sheet(request(null, canReplace = false))
        assertEquals(UiState.Locked(canUseBiometric = true), model.state.value)
        assertEquals(1, app.called("unlock").size)
    }

    @Test
    fun `the person last used in this app is chosen, and named`() = runTest(dispatcher) {
        app.unlocked = true
        app.people[1] = app.people[1] + ("lastUsedHere" to true)
        val model = sheet(request(SECRET, canReplace = true))
        assertEquals("com.whatsapp", app.called("people").single()["sourceApp"])
        assertEquals("giorgi", model.writing.selectedId)
        assertFalse(model.writing.isPicking)
        assertFalse(model.writing.selected!!.isVerified)
    }

    @Test
    fun `no calling app, no remembered person, and the choice is left to the person`() = runTest(dispatcher) {
        app.unlocked = true
        val model = sheet(request(SECRET, canReplace = false, sourceApp = null))
        assertFalse(app.called("people").single().containsKey("sourceApp"))
        assertNull(model.writing.selectedId)
        assertTrue(model.writing.isPicking)
        model.lock()
        assertTrue(app.called("lock").isEmpty())
    }

    @Test
    fun `the draft note shows once`() = runTest(dispatcher) {
        app.unlocked = true
        val first = sheet(request(SECRET, canReplace = true))
        assertTrue(first.writing.showsDraftNote)
        first.dismissDraftNote()
        assertTrue(app.isSeen)
        assertFalse(first.writing.showsDraftNote)

        val again = sheet(request(SECRET, canReplace = true))
        assertFalse(again.writing.showsDraftNote)
    }

    @Test
    fun `switched off in Settings, the sheet goes`() = runTest(dispatcher) {
        app.unlocked = true
        val model = sheet(request(SECRET, canReplace = true))
        app.flow.emit(AnywhereEvent.SettingsChanged(isOn = false))
        advanceUntilIdle()
        assertEquals(UiState.Finished(null), model.state.value)
    }

    @Test
    fun `the app locked elsewhere, the people and names go, unlock again`() = runTest(dispatcher) {
        app.unlocked = true
        val model = sheet(request(SECRET, canReplace = true))
        assertTrue(model.state.value is UiState.Writing)
        app.unlocked = false
        app.flow.emit(AnywhereEvent.LockChanged(isUnlocked = false))
        advanceUntilIdle()
        assertEquals(UiState.Locked(canUseBiometric = false), model.state.value)
    }

    @Test
    fun `while the app starts, the sheet waits for it`() = runTest(dispatcher) {
        app.isStarting = true
        app.missingCalls = 3
        app.unlocked = true
        val model = sheet(request(null, canReplace = false))
        assertTrue(model.state.value is UiState.Writing)
    }

    @Test
    fun `no feature in the app, it says so instead of waiting forever`() = runTest(dispatcher) {
        app.missingCalls = 1
        val model = sheet(request(null, canReplace = false))
        assertEquals(UiState.Problem(ProblemKind.NotReady), model.state.value)
    }

    @Test
    fun `not set up, offers to open the app`() = runTest(dispatcher) {
        app.setUp = false
        val model = sheet(request(SECRET, canReplace = true))
        assertEquals(UiState.Problem(ProblemKind.NotSetUp), model.state.value)
        model.openApp()
        assertEquals(1, app.broughtForward)
        assertEquals(UiState.Finished(null), model.state.value)
    }

    @Test
    fun `a request is replaced in place only from an editable field that waits for it`() {
        val own = "com.fuzzzycore.ink.dev"
        fun of(action: String?, readOnly: Boolean, forResult: Boolean, caller: String? = "com.whatsapp", text: String? = "hi") =
            SheetRequest.of(action, text, readOnly, forResult, caller, own)

        assertTrue(of(SheetRequest.ACTION_PROCESS_TEXT, readOnly = false, forResult = true).canReplace)
        assertFalse(of(SheetRequest.ACTION_PROCESS_TEXT, readOnly = true, forResult = true).canReplace)
        assertFalse(of(SheetRequest.ACTION_PROCESS_TEXT, readOnly = false, forResult = false).canReplace)
        assertFalse(of(null, readOnly = false, forResult = true).canReplace)
        assertNull(of(SheetRequest.ACTION_PROCESS_TEXT, false, true, text = "  ").selectedText)
        assertNull(of(SheetRequest.ACTION_PROCESS_TEXT, false, true, caller = own).sourceApp)
        assertEquals("com.whatsapp", of(SheetRequest.ACTION_PROCESS_TEXT, false, true).sourceApp)
    }
}
