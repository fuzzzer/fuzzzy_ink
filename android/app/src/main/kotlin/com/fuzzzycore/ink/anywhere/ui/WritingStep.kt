package com.fuzzzycore.ink.anywhere.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.fuzzzycore.ink.R
import com.fuzzzycore.ink.anywhere.LockProblem
import com.fuzzzycore.ink.anywhere.SelectedText
import com.fuzzzycore.ink.anywhere.SheetActions
import com.fuzzzycore.ink.anywhere.UiState
import java.text.NumberFormat
import kotlinx.coroutines.flow.first

/**
 * Who it is for, then what: the text selected in the other app (shown, not
 * selectable) or the sheet's own field ("Write sealed"). The person's name,
 * and "Not checked" where it applies, are always on screen before Lock.
 */
@Composable
internal fun WritingStep(state: UiState.Writing, actions: SheetActions) {
    val person = state.selected
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        StepTitle(stringResource(R.string.lockWhoTitle))
        if (person == null || state.isPicking) {
            PeopleList(state.people, state.selectedId, actions::choose)
        } else {
            ChosenPerson(person, canChange = state.people.size > 1 && !state.isLocking, onChange = actions::changePerson)
        }
        val selectedText = state.selectedText
        if (selectedText != null) {
            AnimatedVisibility(visible = state.showsDraftNote) {
                DraftNoteCard(onDismiss = actions::dismissDraftNote)
            }
            SelectedTextCard(selectedText, onSeenToTheEnd = actions::sawWholeSelection)
        } else {
            val focus = remember { FocusRequester() }
            // "Write sealed" with the person already chosen: straight to the keyboard.
            LaunchedEffect(state.isPicking) {
                if (!state.isPicking) focus.requestFocus()
            }
            // What is typed here goes only to Lock (SealedTextInput).
            SealedTextInput {
                OutlinedTextField(
                    value = state.draft,
                    onValueChange = actions::onDraftChange,
                    label = { Text(stringResource(R.string.lockKindMessage)) },
                    placeholder = { Text(stringResource(R.string.lockWriteMessageHint)) },
                    enabled = !state.isLocking,
                    minLines = 3,
                    maxLines = 8,
                    keyboardOptions = KeyboardOptions(
                        capitalization = KeyboardCapitalization.Sentences,
                        autoCorrectEnabled = false,
                        keyboardType = KeyboardType.Text,
                    ),
                    modifier = Modifier
                        .fillMaxWidth()
                        .focusRequester(focus),
                )
            }
        }
        when (state.problem) {
            LockProblem.EmptyText -> StepError(stringResource(R.string.lockWriteSomethingFirst))
            LockProblem.Failed -> StepError(stringResource(R.string.lockFailed))
            null -> Unit
        }
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            MainButton(
                label = person?.let { stringResource(R.string.lockForName, it.name) }
                    ?: stringResource(R.string.lockWhoTitle),
                onClick = actions::lock,
                enabled = state.canLock,
                isBusy = state.isLocking,
            )
            if (!state.hasSeenSelection) {
                Text(
                    text = stringResource(R.string.anywhereSheetReadToTheEnd),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(horizontal = 4.dp),
                )
            } else if (person != null && !state.isPicking) {
                Text(
                    text = stringResource(R.string.lockOnlyNameOnce, person.name),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(horizontal = 4.dp),
                )
            }
        }
    }
}

/**
 * What was selected, all of it, as it is (never selectable or copyable
 * here): another app chose this text, and Lock puts the person's name on
 * every word of it (security review 2026-10-26). Long text scrolls inside
 * the card and can be shown larger; its length is said above it, and
 * characters that would hide or reorder text are shown as their codes.
 * [onSeenToTheEnd] runs once nothing of it is left below the card's edge.
 */
@Composable
private fun SelectedTextCard(text: String, onSeenToTheEnd: () -> Unit) {
    var isLarge by rememberSaveable { mutableStateOf(false) }
    val scroll = rememberScrollState()
    val shown = remember(text) { SelectedText.visible(text) }
    LaunchedEffect(scroll) {
        snapshotFlow { scroll.canScrollForward }.first { canScroll -> !canScroll }
        onSeenToTheEnd()
    }
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = stringResource(R.string.anywhereSheetSelectedText),
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.weight(1f),
            )
            Text(
                text = stringResource(
                    R.string.anywhereSheetSelectedLength,
                    NumberFormat.getIntegerInstance().format(SelectedText.length(text)),
                ),
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Surface(
            shape = RoundedCornerShape(16.dp),
            color = MaterialTheme.colorScheme.surfaceContainerHighest,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text(
                text = shown,
                style = MaterialTheme.typography.bodyLarge,
                modifier = Modifier
                    .heightIn(max = if (isLarge) 360.dp else 160.dp)
                    .verticalScroll(scroll)
                    .padding(16.dp),
            )
        }
        if (isLarge || scroll.maxValue in 1 until Int.MAX_VALUE) {
            TextButton(onClick = { isLarge = !isLarge }, modifier = Modifier.align(Alignment.End)) {
                Text(stringResource(if (isLarge) R.string.anywhereSheetShowLess else R.string.anywhereSheetShowMore))
            }
        }
    }
}

/** Once, ever: the other app may already have kept what was typed there. */
@Composable
private fun DraftNoteCard(onDismiss: () -> Unit) {
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.tertiaryContainer,
        contentColor = MaterialTheme.colorScheme.onTertiaryContainer,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(modifier = Modifier.padding(start = 16.dp, top = 16.dp, end = 8.dp, bottom = 4.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.Top) {
                Icon(Icons.Outlined.Info, contentDescription = null, modifier = Modifier.size(20.dp))
                Text(
                    text = stringResource(R.string.infoOtherAppsLine3),
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.weight(1f).padding(end = 8.dp),
                )
            }
            TextButton(
                onClick = onDismiss,
                colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.onTertiaryContainer),
                modifier = Modifier.align(Alignment.End),
            ) {
                Text(stringResource(R.string.anywhereSheetGotIt))
            }
        }
    }
}
