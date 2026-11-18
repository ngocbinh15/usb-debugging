package dev.usbtoggle.app_usb

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.provider.Settings

class UsbDebugging(private val context: Context) {
    fun isEnabled(): Boolean =
        Settings.Global.getInt(context.contentResolver, Settings.Global.ADB_ENABLED, 0) == 1

    fun hasPermission(): Boolean =
        context.checkSelfPermission(Manifest.permission.WRITE_SECURE_SETTINGS) ==
            PackageManager.PERMISSION_GRANTED

    fun status(): Map<String, Boolean> = mapOf(
        "enabled" to isEnabled(),
        "hasPermission" to hasPermission(),
    )

    fun setEnabled(enabled: Boolean) {
        if (!hasPermission()) {
            throw SecurityException(context.getString(R.string.permission_required))
        }
        if (enabled && Settings.Global.getInt(
                context.contentResolver, Settings.Global.DEVELOPMENT_SETTINGS_ENABLED, 0,
            ) != 1
        ) {
            throw IllegalStateException(context.getString(R.string.developer_options_required))
        }
        if (!Settings.Global.putInt(
                context.contentResolver, Settings.Global.ADB_ENABLED, if (enabled) 1 else 0,
            ) || isEnabled() != enabled
        ) {
            throw IllegalStateException(context.getString(R.string.change_failed))
        }
    }
}
