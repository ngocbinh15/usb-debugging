package dev.usbtoggle.app_usb

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings

class PrivateDns(private val context: Context) {
    companion object {
        // Android's setting keys are hidden constants; use their AOSP names.
        const val MODE = "private_dns_mode"
        const val DEFAULT_MODE = "private_dns_default_mode"
        const val HOSTNAME = "private_dns_specifier"
        const val AUTOMATIC = "opportunistic"
        const val PRIVATE = "hostname"
    }

    fun mode(): String {
        val mode = Settings.Global.getString(context.contentResolver, MODE)
            ?.takeIf { it.isNotEmpty() }
            ?: Settings.Global.getString(context.contentResolver, DEFAULT_MODE)
        return when (mode) {
            "off", PRIVATE -> mode
            else -> AUTOMATIC
        }
    }

    fun hostname(): String =
        Settings.Global.getString(context.contentResolver, HOSTNAME).orEmpty().trim()

    fun hasPermission(): Boolean =
        context.checkSelfPermission(Manifest.permission.WRITE_SECURE_SETTINGS) ==
            PackageManager.PERMISSION_GRANTED

    fun status(): Map<String, Any> {
        val supported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.P
        return mapOf(
            "dnsSupported" to supported,
            "dnsMode" to if (supported) mode() else "",
            "dnsHostname" to if (supported) hostname() else "",
        )
    }

    fun setPrivate(enabled: Boolean) {
        check(Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            context.getString(R.string.dns_unsupported)
        }
        if (!hasPermission()) {
            throw SecurityException(context.getString(R.string.permission_required))
        }
        check(!enabled || hostname().isNotEmpty()) {
            context.getString(R.string.dns_hostname_required)
        }
        val nextMode = if (enabled) PRIVATE else AUTOMATIC
        check(Settings.Global.putString(context.contentResolver, MODE, nextMode) && mode() == nextMode) {
            context.getString(R.string.dns_change_failed)
        }
    }
}
