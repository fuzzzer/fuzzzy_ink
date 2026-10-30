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
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.paneTitle
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.SecureFlagPolicy
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.fuzzzycore.ink.R
import com.fuzzzycore.ink.anywhere.SheetActions
import com.fuzzzycore.ink.anywhere.UiState
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull

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
    // Set only by a real close, never by the sheet merely sliding down: the
    // other app's keyboard can slide it down by itself, and a sheet that
    // counted that as closing stayed hidden over the other app, an invisible
    // window that took every tap until Back (owner, 2026-10-28).
    var isClosing by remember { mutableStateOf(false) }
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    // The last step on screen stays while the sheet slides away.
    var shown by remember { mutableStateOf<UiState>(UiState.Starting) }
    if (current !is UiState.Finished) shown = current

    LaunchedEffect(current) {
        val finished = current as? UiState.Finished ?: return@LaunchedEffect
        isClosing = true
        // The activity goes even if the slide down is interrupted or never
        // ends: a window Android stopped drawing never finishes its animation.
        try {
            withTimeoutOrNull(HIDE_LIMIT_MS) { sheetState.hide() }
        } finally {
            onFinished(finished.returnText)
        }
    }

    // The other app's keyboard (or a fingerprint prompt) can slide the sheet
    // down by itself. One watcher for the whole sheet slides it up again,
    // unless someone is closing it, and if it is still headed off screen a
    // moment later, the activity goes: never an invisible window over the
    // other app that takes every tap until Back (owner, 2026-10-28).
    // It is not keyed on the sheet's values: a watcher restarted by every
    // change cancelled its own slide up, which changes them, over and over,
    // and never reached the close.
    val scope = rememberCoroutineScope()
    LaunchedEffect(Unit) {
        var reshow: Job? = null
        var offScreenFor = 0L
        while (true) {
            delay(WATCH_STEP_MS)
            if (sheetState.targetValue != SheetValue.Hidden) {
                offScreenFor = 0L
                continue
            }
            if (sheetState.currentValue == SheetValue.Hidden && !isClosing && reshow?.isActive != true) {
                reshow = scope.launch { withTimeoutOrNull(HIDE_LIMIT_MS) { sheetState.show() } }
            }
            offScreenFor += WATCH_STEP_MS
            if (offScreenFor >= HIDDEN_LIMIT_MS) {
                isClosing = true
                actions.close()
                onFinished((current as? UiState.Done)?.returnText ?: (current as? UiState.Finished)?.returnText)
                break
            }
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

/** How often the watcher looks at the sheet; also the moment a person's own swipe has to report its close. */
private const val WATCH_STEP_MS = 200L

/** How long the sheet may stay headed off screen before the activity goes. */
private const val HIDDEN_LIMIT_MS = 1_200L

/** The longest the slide down may take before the activity goes anyway. */
private const val HIDE_LIMIT_MS = 600L

/** The sheet's content for one state; previews render it directly. */
@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun SheetBody(state: UiState, actions: SheetActions) {
    val title = stringResource(R.string.fuzzzyInk)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            // Its tags are ids in the screen tree, for tests (Fuzzzy Tester).
            .semantics {
                paneTitle = title
                testTagsAsResourceId = true
            }
            .testTag("anywhere.sheet")
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
