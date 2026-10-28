package com.fuzzzycore.ink.anywhere

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import com.fuzzzycore.ink.R

/**
 * "Lock text" in Quick Settings: opens the same sheet in "Write sealed"
 * (the person writes in Fuzzzy Ink's own field; the sealed output is
 * copied). Declared off, in the development flavour only; it is switched
 * on with the selection menu item ([AnywhereSwitch]). It needs no
 * permission: the person adds the tile themselves.
 */
class InkTileService : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        qsTile?.apply {
            state = Tile.STATE_INACTIVE
            label = getString(R.string.anywhereSheetTileLabel)
            updateTile()
        }
    }

    override fun onClick() {
        super.onClick()
        // On the lock screen, the phone is unlocked first.
        if (isLocked) unlockAndRun(::openSheet) else openSheet()
    }

    @SuppressLint("StartActivityAndCollapseDeprecated")
    private fun openSheet() {
        // A fresh sheet every time, even while the last one is still sliding away.
        val intent = Intent(this, InkTextActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // Android 14+ takes only a PendingIntent here.
            startActivityAndCollapse(
                PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE),
            )
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }
}
