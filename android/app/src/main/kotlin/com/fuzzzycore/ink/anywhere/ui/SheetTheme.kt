package com.fuzzzycore.ink.anywhere.ui

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext

/**
 * Material You: the person's own wallpaper colours on Android 12+, Fuzzzy
 * Ink's paper and night colours below (fuzzzy_ui_kit `inkPaper`/`inkNight`).
 * Type is the system's, at the system's font size.
 */
@Composable
fun InkSheetTheme(
    isDark: Boolean = isSystemInDarkTheme(),
    isDynamic: Boolean = true,
    content: @Composable () -> Unit,
) {
    val colors = when {
        isDynamic && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (isDark) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }
        isDark -> InkNight
        else -> InkPaper
    }
    MaterialTheme(colorScheme = colors, content = content)
}

private val InkPaper: ColorScheme = lightColorScheme(
    primary = Color(0xFF1C1B15),
    onPrimary = Color(0xFFF2F0E9),
    primaryContainer = Color(0xFFE6E3D9),
    onPrimaryContainer = Color(0xFF1C1B15),
    secondary = Color(0xFF3B6E97),
    onSecondary = Color(0xFFF2F0E9),
    secondaryContainer = Color(0xFFDCE6EF),
    onSecondaryContainer = Color(0xFF1C1B15),
    tertiary = Color(0xFF8F5B36),
    onTertiary = Color(0xFFF2F0E9),
    tertiaryContainer = Color(0xFFF1E2D5),
    onTertiaryContainer = Color(0xFF3A2414),
    error = Color(0xFFA32218),
    onError = Color(0xFFFBF4F2),
    errorContainer = Color(0xFFF6DCD8),
    onErrorContainer = Color(0xFF5C120C),
    background = Color(0xFFF2F0E9),
    onBackground = Color(0xFF1C1B15),
    surface = Color(0xFFF8F7F2),
    onSurface = Color(0xFF1C1B15),
    surfaceVariant = Color(0xFFE6E3D9),
    onSurfaceVariant = Color(0xFF6B6961),
    outline = Color(0xFFB9B6AC),
    outlineVariant = Color(0xFFD6D4CC),
    surfaceContainerLowest = Color(0xFFFFFFFF),
    surfaceContainerLow = Color(0xFFF8F7F2),
    surfaceContainer = Color(0xFFF2F0E9),
    surfaceContainerHigh = Color(0xFFECEAE2),
    surfaceContainerHighest = Color(0xFFE6E3D9),
)

private val InkNight: ColorScheme = darkColorScheme(
    primary = Color(0xFFEEF0F4),
    onPrimary = Color(0xFF0B0C0F),
    primaryContainer = Color(0xFF393B3E),
    onPrimaryContainer = Color(0xFFEEF0F4),
    secondary = Color(0xFF77A4CA),
    onSecondary = Color(0xFF0B0C0F),
    secondaryContainer = Color(0xFF26384A),
    onSecondaryContainer = Color(0xFFEEF0F4),
    tertiary = Color(0xFFC39271),
    onTertiary = Color(0xFF0B0C0F),
    tertiaryContainer = Color(0xFF4A3527),
    onTertiaryContainer = Color(0xFFF4E3D6),
    error = Color(0xFFEA6C5C),
    onError = Color(0xFF0B0C0F),
    errorContainer = Color(0xFF7C130D),
    onErrorContainer = Color(0xFFFBF4F2),
    background = Color(0xFF121417),
    onBackground = Color(0xFFEEF0F4),
    surface = Color(0xFF1A1C1F),
    onSurface = Color(0xFFEEF0F4),
    surfaceVariant = Color(0xFF252729),
    onSurfaceVariant = Color(0xFFBBBEC2),
    outline = Color(0xFF535559),
    outlineVariant = Color(0xFF393B3E),
    surfaceContainerLowest = Color(0xFF121417),
    surfaceContainerLow = Color(0xFF1A1C1F),
    surfaceContainer = Color(0xFF1E2023),
    surfaceContainerHigh = Color(0xFF252729),
    surfaceContainerHighest = Color(0xFF2E3033),
)
