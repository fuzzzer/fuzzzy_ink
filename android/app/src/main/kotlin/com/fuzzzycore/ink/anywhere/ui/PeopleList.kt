package com.fuzzzycore.ink.anywhere.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.unit.dp
import com.fuzzzycore.ink.R
import com.fuzzzycore.ink.anywhere.Person

private val RowShape = RoundedCornerShape(16.dp)

/** Every connected person, one choice. Each row says "Not checked" where it applies. */
@Composable
internal fun PeopleList(people: List<Person>, selectedId: String?, onChoose: (String) -> Unit) {
    Column(
        verticalArrangement = Arrangement.spacedBy(4.dp),
        modifier = Modifier.selectableGroup(),
    ) {
        for (person in people) {
            val isSelected = person.id == selectedId
            PersonRow(
                person = person,
                isSelected = isSelected,
                modifier = Modifier
                    .selectable(
                        selected = isSelected,
                        role = Role.RadioButton,
                        onClick = { onChoose(person.id) },
                    )
                    .testTag("row.anywhere.person"),
                trailing = { RadioButton(selected = isSelected, onClick = null) },
            )
        }
    }
}

/** The chosen person, always named, with "Not checked" when it applies, and Change. */
@Composable
internal fun ChosenPerson(person: Person, canChange: Boolean, onChange: () -> Unit) {
    PersonRow(
        person = person,
        isSelected = true,
        trailing = {
            if (canChange) {
                TextButton(onClick = onChange, modifier = Modifier.testTag("btn.anywhere.change")) { Text(stringResource(R.string.anywhereSheetChange)) }
            }
        },
    )
}

@Composable
private fun PersonRow(
    person: Person,
    isSelected: Boolean,
    modifier: Modifier = Modifier,
    trailing: @Composable () -> Unit,
) {
    ListItem(
        headlineContent = {
            Text(person.name, style = MaterialTheme.typography.titleMedium, maxLines = 2)
        },
        supportingContent = if (person.isVerified) null else ({ NotCheckedMark() }),
        leadingContent = { Initial(person.name) },
        trailingContent = trailing,
        colors = ListItemDefaults.colors(
            containerColor = if (isSelected) MaterialTheme.colorScheme.surfaceContainerHighest else Color.Transparent,
        ),
        modifier = Modifier
            .clip(RowShape)
            .then(modifier),
    )
}

@Composable
private fun Initial(name: String) {
    Surface(
        shape = CircleShape,
        color = MaterialTheme.colorScheme.primaryContainer,
        contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
        // Decorative: the name next to it is what is read out.
        modifier = Modifier
            .size(40.dp)
            .clearAndSetSemantics { },
    ) {
        Box(contentAlignment = Alignment.Center) {
            Text(
                text = name.trim().take(1).uppercase(),
                style = MaterialTheme.typography.titleMedium,
            )
        }
    }
}
