package com.fuzzzycore.ink.anywhere.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
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
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.fuzzzycore.ink.R
import com.fuzzzycore.ink.anywhere.LockProblem
import com.fuzzzycore.ink.anywhere.SheetActions
import com.fuzzzycore.ink.anywhere.UiState

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
            SelectedTextCard(selectedText)
        } else {
            val focus = remember { FocusRequester() }
            // "Write sealed" with the person already chosen: straight to the keyboard.
            LaunchedEffect(state.isPicking) {
                if (!state.isPicking) focus.requestFocus()
            }
            OutlinedTextField(
                value = state.draft,
                onValueChange = actions::onDraftChange,
                label = { Text(stringResource(R.string.lockKindMessage)) },
                placeholder = { Text(stringResource(R.string.lockWriteMessageHint)) },
                enabled = !state.isLocking,
                minLines = 3,
                maxLines = 8,
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
                modifier = Modifier
                    .fillMaxWidth()
                    .focusRequester(focus),
            )
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
                enabled = person != null && !state.isPicking,
                isBusy = state.isLocking,
            )
            if (person != null && !state.isPicking) {
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

/** What was selected, as it is; never selectable or copyable here. */
@Composable
private fun SelectedTextCard(text: String) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(
            text = stringResource(R.string.anywhereSheetSelectedText),
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Surface(
            shape = RoundedCornerShape(16.dp),
            color = MaterialTheme.colorScheme.surfaceContainerHighest,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text(
                text = text,
                style = MaterialTheme.typography.bodyLarge,
                maxLines = 5,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(16.dp),
            )
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
