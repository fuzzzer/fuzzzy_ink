package com.fuzzzycore.ink.anywhere.ui

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.SizeTransform
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.ModalBottomSheetProperties
import androidx.compose.material3.SheetValue
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.paneTitle
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.SecureFlagPolicy
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.fuzzzycore.ink.R
import com.fuzzzycore.ink.anywhere.SheetActions
import com.fuzzzycore.ink.anywhere.UiState
import kotlinx.coroutines.flow.StateFlow

/**
 * The sheet over the other app. It slides up on its own spring, changes
 * step in place (a short fade and rise; none when the system's animations
 * are off, which Compose follows), and slides down before the activity goes.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun InkSheet(
    state: StateFlow<UiState>,
    actions: SheetActions,
    onFinished: (returnText: String?) -> Unit,
) {
    val current by state.collectAsStateWithLifecycle()
    // The person (a swipe, the scrim, back) or the sheet itself is closing it.
    var isClosing by remember { mutableStateOf(false) }
    val sheetState = rememberModalBottomSheetState(
        skipPartiallyExpanded = true,
        confirmValueChange = { value ->
            if (value == SheetValue.Hidden) isClosing = true
            true
        },
    )
    // The last step on screen stays while the sheet slides away.
    var shown by remember { mutableStateOf<UiState>(UiState.Starting) }
    if (current !is UiState.Finished) shown = current

    LaunchedEffect(current) {
        val finished = current as? UiState.Finished ?: return@LaunchedEffect
        isClosing = true
        sheetState.hide()
        onFinished(finished.returnText)
    }

    // The other app's keyboard closes while the sheet slides up; the new
    // insets can cut the slide short and leave it hidden. Slide it up again
    // unless someone is closing it.
    LaunchedEffect(sheetState.currentValue, sheetState.targetValue, isClosing) {
        if (!isClosing &&
            sheetState.currentValue == SheetValue.Hidden &&
            sheetState.targetValue == SheetValue.Hidden
        ) {
            sheetState.show()
        }
    }

    ModalBottomSheet(
        onDismissRequest = {
            isClosing = true
            actions.close()
        },
        sheetState = sheetState,
        properties = ModalBottomSheetProperties(securePolicy = SecureFlagPolicy.SecureOn),
    ) {
        SheetBody(state = shown, actions = actions)
    }
}

/** The sheet's content for one state; previews render it directly. */
@Composable
fun SheetBody(state: UiState, actions: SheetActions) {
    val title = stringResource(R.string.fuzzzyInk)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .semantics { paneTitle = title }
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 24.dp)
            .padding(bottom = 24.dp)
            .navigationBarsPadding(),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        SheetHeader()
        AnimatedContent(
            targetState = state,
            contentKey = { it::class },
            transitionSpec = {
                (fadeIn(tween(durationMillis = 220, delayMillis = 60)) +
                    slideInVertically(spring(stiffness = Spring.StiffnessMediumLow)) { it / 10 })
                    .togetherWith(fadeOut(tween(durationMillis = 90)))
                    .using(SizeTransform(clip = false))
            },
            label = "sheet step",
        ) { step ->
            when (step) {
                UiState.Starting -> StartingStep()
                is UiState.Locked -> UnlockStep(step, actions)
                is UiState.Writing -> WritingStep(step, actions)
                is UiState.Sealed -> SealedStep(step, actions)
                is UiState.Done -> DoneStep(step, actions)
                is UiState.Problem -> ProblemStep(step, actions)
                is UiState.Finished -> Box(Modifier)
            }
        }
    }
}

@Composable
private fun SheetHeader() {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Surface(
            shape = CircleShape,
            color = MaterialTheme.colorScheme.secondaryContainer,
            contentColor = MaterialTheme.colorScheme.onSecondaryContainer,
            modifier = Modifier.size(32.dp),
        ) {
            Box(contentAlignment = Alignment.Center) {
                Icon(Icons.Filled.Lock, contentDescription = null, modifier = Modifier.size(18.dp))
            }
        }
        Text(
            text = stringResource(R.string.fuzzzyInk),
            style = MaterialTheme.typography.titleSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(start = 12.dp),
        )
    }
}
