package com.fuzzzycore.ink.anywhere

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager

/**
 * Turns the "Lock from other apps" entry points (the selection menu items and
 * the Quick Settings tile) on and off. They are declared off
 * (`android:enabled="false"`) and only in the development flavour; they are
 * on only while the build has the flag and Settings → Lock from other apps is
 * on, so the menu item never shows for anyone who did not turn it on.
 */
object AnywhereSwitch {
    /** By name: the code is in every flavour, the declarations only in development. */
    val components = listOf(
        "com.fuzzzycore.ink.anywhere.InkTextActivity",
        "com.fuzzzycore.ink.anywhere.LockTextAlias",
        "com.fuzzzycore.ink.anywhere.OpenTextAlias",
        "com.fuzzzycore.ink.anywhere.InkTileService",
    )

    fun apply(context: Context, isOn: Boolean) {
        val state = if (isOn && InkEngine.isInBuild(context)) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED
        } else {
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED
        }
        val packageManager = context.packageManager
        for (name in components) {
            val component = ComponentName(context.packageName, name)
            try {
                if (packageManager.getComponentEnabledSetting(component) == state) continue
                packageManager.setComponentEnabledSetting(component, state, PackageManager.DONT_KILL_APP)
            } catch (notDeclared: IllegalArgumentException) {
                // Not declared in this flavour: nothing to switch.
            }
        }
    }
}
