package com.fuzzzycore.ink.anywhere.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Face
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import com.fuzzzycore.ink.R
import com.fuzzzycore.ink.anywhere.SheetActions
import com.fuzzzycore.ink.anywhere.UiState

@Composable
internal fun StartingStep() {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(16.dp),
        modifier = Modifier.heightIn(min = 72.dp),
    ) {
        CircularProgressIndicator(modifier = Modifier.size(24.dp), strokeWidth = 3.dp)
        StepLine(stringResource(R.string.anywhereSheetStarting))
    }
}

/**
 * Unlock first: the app's own fingerprint or face prompt (system UI), or the
 * master password in a native password field that is sent once and cleared.
 */
@Composable
internal fun UnlockStep(state: UiState.Locked, actions: SheetActions) {
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        StepHeading(
            title = stringResource(R.string.chatUnlockTitle),
            line = stringResource(R.string.anywhereSheetUnlockLine),
        )
        if (state.canUseBiometric) {
            FilledTonalButton(
                onClick = actions::unlockWithBiometrics,
                enabled = !state.isBusy && state.waitSeconds == 0,
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 52.dp)
                    .testTag("btn.anywhere.biometric"),
            ) {
                Icon(Icons.Filled.Face, contentDescription = null, modifier = Modifier.size(ButtonDefaults.IconSize))
                Text(stringResource(R.string.accessUseBio), modifier = Modifier.padding(start = ButtonDefaults.IconSpacing))
            }
        }
        PasswordField(state, actions)
        MainButton(
            label = stringResource(R.string.chatAuthUnlock),
            onClick = actions::unlockWithPassword,
            tag = "btn.anywhere.unlock",
            enabled = state.password.isNotEmpty() && state.waitSeconds == 0,
            isBusy = state.isBusy,
        )
    }
}

@Composable
private fun PasswordField(state: UiState.Locked, actions: SheetActions) {
    var isVisible by rememberSaveable { mutableStateOf(false) }
    val focus = remember { FocusRequester() }
    // No fingerprint here: straight to the keyboard.
    LaunchedEffect(state.canUseBiometric) {
        if (!state.canUseBiometric) focus.requestFocus()
    }
    val message = when {
        state.waitSeconds > 0 -> stringResource(R.string.lockoutWaitLeft, minutesAndSeconds(state.waitSeconds))
        state.isWrong -> stringResource(R.string.safeWrongPassword)
        state.isBiometricChanged -> stringResource(R.string.accessBioChanged)
        else -> null
    }
    // Never copied, shown or hidden (SealedTextInput).
    SealedTextInput {
        OutlinedTextField(
            value = state.password,
            onValueChange = actions::onPasswordChange,
            label = { Text(stringResource(R.string.masterPassword)) },
            singleLine = true,
            enabled = !state.isBusy && state.waitSeconds == 0,
            isError = state.isWrong,
            visualTransformation = if (isVisible) VisualTransformation.None else PasswordVisualTransformation(),
            keyboardOptions = KeyboardOptions(
                autoCorrectEnabled = false,
                keyboardType = KeyboardType.Password,
                imeAction = ImeAction.Done,
            ),
            keyboardActions = KeyboardActions(onDone = { actions.unlockWithPassword() }),
            trailingIcon = {
                IconButton(onClick = { isVisible = !isVisible }) {
                    Icon(
                        painter = painterResource(
                            if (isVisible) R.drawable.anywhere_visibility_off else R.drawable.anywhere_visibility,
                        ),
                        contentDescription = stringResource(
                            if (isVisible) R.string.safeHidePassword else R.string.accessShowPassword,
                        ),
                    )
                }
            },
            supportingText = message?.let { { StepErrorText(it, isError = state.isWrong || state.waitSeconds > 0) } },
            modifier = Modifier
                .fillMaxWidth()
                .focusRequester(focus)
                .testTag("field.anywhere.password"),
        )
    }
}

@Composable
private fun StepErrorText(text: String, isError: Boolean) {
    if (isError) StepError(text) else Text(text, color = MaterialTheme.colorScheme.onSurfaceVariant)
}

internal fun minutesAndSeconds(seconds: Int): String = "%d:%02d".format(seconds / 60, seconds % 60)
