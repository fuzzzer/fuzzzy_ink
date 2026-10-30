package com.fuzzzycore.ink.anywhere.ui

import android.os.Build
import android.view.HapticFeedbackConstants
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import com.fuzzzycore.ink.R
import com.fuzzzycore.ink.anywhere.Outcome
import com.fuzzzycore.ink.anywhere.ProblemKind
import com.fuzzzycore.ink.anywhere.SealedKind
import com.fuzzzycore.ink.anywhere.SheetActions
import com.fuzzzycore.ink.anywhere.UiState

/** The selected text is already locked: Open it here (once), or in Fuzzzy Ink. */
@Composable
internal fun SealedStep(state: UiState.Sealed, actions: SheetActions) {
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        when (state.kind) {
            SealedKind.Message -> StepHeading(
                title = state.personName?.let { stringResource(R.string.openLinkTitle, it) }
                    ?: stringResource(R.string.anywhereSheetOpenTitle),
                line = stringResource(R.string.openLinkLine),
            )
            SealedKind.ForTheApp -> StepHeading(
                title = stringResource(R.string.anywhereSheetOpenInInkTitle),
                line = stringResource(R.string.anywhereSheetOpenInInkLine),
            )
        }
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            MainButton(
                label = stringResource(
                    if (state.kind == SealedKind.Message) R.string.openLinkOpen else R.string.anywhereSheetOpenInInkAction,
                ),
                onClick = actions::open,
                isBusy = state.isBusy,
            )
            TextButton(onClick = actions::close, enabled = !state.isBusy, modifier = Modifier.fillMaxWidth()) {
                Text(stringResource(R.string.openLinkNotNow))
            }
        }
    }
}

/** Locked. A confirming tick on its own spring and the system's "confirm" haptic. */
@Composable
internal fun DoneStep(state: UiState.Done, actions: SheetActions) {
    val view = LocalView.current
    val scale = remember { Animatable(0.6f) }
    LaunchedEffect(Unit) {
        val feedback = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            HapticFeedbackConstants.CONFIRM
        } else {
            HapticFeedbackConstants.CONTEXT_CLICK
        }
        view.performHapticFeedback(feedback)
        scale.animateTo(1f, spring(dampingRatio = Spring.DampingRatioMediumBouncy, stiffness = Spring.StiffnessMedium))
    }
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        StepBadge(
            icon = Icons.Filled.Check,
            container = MaterialTheme.colorScheme.primaryContainer,
            content = MaterialTheme.colorScheme.onPrimaryContainer,
            modifier = Modifier.graphicsLayer {
                scaleX = scale.value
                scaleY = scale.value
            },
        )
        StepHeading(
            title = stringResource(R.string.anywhereSheetLockedFor, state.personName),
            line = stringResource(
                when (state.outcome) {
                    Outcome.PutInPlace -> R.string.anywhereSheetPutInPlace
                    Outcome.PutInPlaceAndCopied -> R.string.anywhereSheetPutInPlaceCopied
                    Outcome.Copied -> R.string.anywhereSheetCopied
                    Outcome.Ready -> R.string.anywhereSheetCopyToPaste
                },
            ),
        )
        if (state.canCopy) {
            MainButton(label = stringResource(R.string.anywhereSheetCopy), onClick = actions::copy, isBusy = state.isCopying)
            TextButton(onClick = actions::close, enabled = !state.isCopying, modifier = Modifier.fillMaxWidth()) {
                Text(stringResource(R.string.anywhereSheetDone))
            }
            AutoCopyRow(isOn = state.copiesAutomatically, onChange = actions::setAutoCopy)
        } else if (state.outcome == Outcome.Copied) {
            MainButton(label = stringResource(R.string.openErrorOk), onClick = actions::close)
            // Copied by itself: the switch shows that it is on, and turns it off here.
            if (state.copiesAutomatically || state.wasCopiedAutomatically) {
                AutoCopyRow(isOn = state.copiesAutomatically, onChange = actions::setAutoCopy)
            }
        }
    }
}

/** "Copy automatically next time", for people who use it often; the whole row toggles it. */
@Composable
private fun AutoCopyRow(isOn: Boolean, onChange: (Boolean) -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .toggleable(value = isOn, role = Role.Switch, onValueChange = onChange)
            .padding(vertical = 4.dp),
    ) {
        Text(
            text = stringResource(R.string.anywhereSheetCopyAutomatically),
            style = MaterialTheme.typography.bodyLarge,
            modifier = Modifier.weight(1f),
        )
        Switch(checked = isOn, onCheckedChange = null)
    }
}

/** Something stops the use: said in the app's own words, with the way on. */
@Composable
internal fun ProblemStep(state: UiState.Problem, actions: SheetActions) {
    val name = state.name
    val (title, line) = when (state.kind) {
        ProblemKind.NotSetUp -> R.string.anywhereSheetSetUpTitle to R.string.anywhereSheetSetUpLine
        ProblemKind.NotReady -> R.string.anywhereSheetNotReadyTitle to R.string.anywhereSheetNotReadyLine
        ProblemKind.NoPeople -> R.string.lockAddPersonFirst to R.string.anywhereSheetNoPeopleLine
        ProblemKind.AlreadyOpened -> R.string.openErrorAlreadyTitle to R.string.openErrorAlreadyLine
        ProblemKind.NotYours -> R.string.openErrorNotYoursTitle to R.string.openErrorNotYoursLine
        ProblemKind.Damaged -> R.string.openErrorDamagedTitle to R.string.openErrorDamagedLine
        ProblemKind.TooOld -> R.string.openErrorOldTitle to R.string.openErrorOldLine
        ProblemKind.NewerApp -> R.string.openErrorNewerTitle to R.string.openErrorNewerLine
        ProblemKind.NotFuzzzy -> R.string.openErrorNotFuzzzyTitle to R.string.openErrorNotFuzzzyLine
        ProblemKind.Failed -> R.string.anywhereSheetFailedTitle to R.string.openFailed
    }
    val needsName = state.kind == ProblemKind.AlreadyOpened || state.kind == ProblemKind.TooOld
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        StepBadge(Icons.Outlined.Info, MaterialTheme.colorScheme.surfaceContainerHighest, MaterialTheme.colorScheme.onSurfaceVariant)
        StepHeading(
            title = stringResource(title),
            // A line that names someone is left out when the name is not known.
            line = when {
                !needsName -> stringResource(line)
                name != null -> stringResource(line, name)
                else -> null
            },
        )
        if (state.kind.opensTheApp) {
            MainButton(label = stringResource(R.string.anywhereSheetOpenApp), onClick = actions::openApp)
        } else {
            MainButton(label = stringResource(R.string.openErrorOk), onClick = actions::close)
        }
    }
}

@Composable
private fun StepBadge(icon: ImageVector, container: Color, content: Color, modifier: Modifier = Modifier) {
    Surface(shape = CircleShape, color = container, contentColor = content, modifier = modifier.size(56.dp)) {
        Box(contentAlignment = Alignment.Center) {
            Icon(icon, contentDescription = null, modifier = Modifier.size(28.dp))
        }
    }
}
