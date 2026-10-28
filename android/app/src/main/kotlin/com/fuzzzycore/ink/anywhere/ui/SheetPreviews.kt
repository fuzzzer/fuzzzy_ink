package com.fuzzzycore.ink.anywhere.ui

import android.content.res.Configuration
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.ui.tooling.preview.Preview
import com.fuzzzycore.ink.anywhere.LockProblem
import com.fuzzzycore.ink.anywhere.Outcome
import com.fuzzzycore.ink.anywhere.Person
import com.fuzzzycore.ink.anywhere.ProblemKind
import com.fuzzzycore.ink.anywhere.SealedKind
import com.fuzzzycore.ink.anywhere.SheetActions
import com.fuzzzycore.ink.anywhere.UiState

// One preview per state (RESEARCH native code rule 1), in the Ink colours.

private val nino = Person(id = "1", name = "Nino", isVerified = true, isLastUsedHere = true)
private val giorgi = Person(id = "2", name = "Giorgi", isVerified = false, isLastUsedHere = false)

@Composable
private fun SheetPreview(state: UiState, isDark: Boolean = false) {
    InkSheetTheme(isDark = isDark, isDynamic = false) {
        Surface(color = MaterialTheme.colorScheme.surfaceContainerLow) {
            SheetBody(state = state, actions = object : SheetActions {})
        }
    }
}

@Preview(name = "Starting")
@Composable
private fun StartingPreview() = SheetPreview(UiState.Starting)

@Preview(name = "Locked")
@Composable
private fun LockedPreview() = SheetPreview(UiState.Locked(canUseBiometric = true))

@Preview(name = "Unlocking", uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun UnlockingPreview() =
    SheetPreview(UiState.Locked(canUseBiometric = false, isBusy = true), isDark = true)

@Preview(name = "Wrong password, wait")
@Composable
private fun WaitPreview() =
    SheetPreview(UiState.Locked(canUseBiometric = false, isWrong = true, waitSeconds = 30))

@Preview(name = "Choosing")
@Composable
private fun ChoosingPreview() = SheetPreview(
    UiState.Writing(
        people = listOf(nino, giorgi),
        selectedId = null,
        isPicking = true,
        draft = "",
        selectedText = null,
        showsDraftNote = false,
    ),
)

@Preview(name = "Write sealed")
@Composable
private fun WritePreview() = SheetPreview(
    UiState.Writing(
        people = listOf(nino, giorgi),
        selectedId = nino.id,
        isPicking = false,
        draft = "See you at six",
        selectedText = null,
        showsDraftNote = false,
    ),
)

@Preview(name = "Selected text, first time", uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun SelectedPreview() = SheetPreview(
    UiState.Writing(
        people = listOf(giorgi),
        selectedId = giorgi.id,
        isPicking = false,
        draft = "",
        selectedText = "The code for the gate is the year we met",
        showsDraftNote = true,
    ),
    isDark = true,
)

@Preview(name = "Locking")
@Composable
private fun LockingPreview() = SheetPreview(
    UiState.Writing(
        people = listOf(nino),
        selectedId = nino.id,
        isPicking = false,
        draft = "See you at six",
        selectedText = null,
        showsDraftNote = false,
        isLocking = true,
    ),
)

@Preview(name = "Write something first")
@Composable
private fun EmptyPreview() = SheetPreview(
    UiState.Writing(
        people = listOf(nino),
        selectedId = nino.id,
        isPicking = false,
        draft = "",
        selectedText = null,
        showsDraftNote = false,
        problem = LockProblem.EmptyText,
    ),
)

@Preview(name = "Open")
@Composable
private fun OpenPreview() = SheetPreview(UiState.Sealed(SealedKind.Message, "Nino"))

@Preview(name = "Open in Fuzzzy Ink")
@Composable
private fun OpenInAppPreview() = SheetPreview(UiState.Sealed(SealedKind.ForTheApp, null))

@Preview(name = "Done, copied")
@Composable
private fun DonePreview() = SheetPreview(UiState.Done("Nino", Outcome.Copied))

@Preview(name = "Error, already opened", uiMode = Configuration.UI_MODE_NIGHT_YES)
@Composable
private fun ProblemPreview() = SheetPreview(UiState.Problem(ProblemKind.AlreadyOpened, "Nino"), isDark = true)

@Preview(name = "Error, set up first")
@Composable
private fun SetUpPreview() = SheetPreview(UiState.Problem(ProblemKind.NotSetUp))
