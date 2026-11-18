package dev.usbtoggle.app_usb

import android.app.PendingIntent
import android.content.Intent
import android.database.ContentObserver
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.widget.Toast

class UsbDebuggingTileService : TileService() {
    private val debugging by lazy { UsbDebugging(this) }
    private val observer = object : ContentObserver(Handler(Looper.getMainLooper())) {
        override fun onChange(selfChange: Boolean) = updateTile()
    }
    private var observing = false

    override fun onStartListening() {
        super.onStartListening()
        if (!observing) {
            contentResolver.registerContentObserver(
                Settings.Global.getUriFor(Settings.Global.ADB_ENABLED), false, observer,
            )
            observing = true
        }
        updateTile()
    }

    override fun onStopListening() {
        stopObserving()
        super.onStopListening()
    }

    override fun onDestroy() {
        stopObserving()
        super.onDestroy()
    }

    override fun onClick() {
        super.onClick()
        if (isLocked) unlockAndRun { toggle() } else toggle()
    }

    private fun toggle() {
        if (!debugging.hasPermission()) {
            openApp()
            return
        }
        try {
            debugging.setEnabled(!debugging.isEnabled())
        } catch (_: SecurityException) {
            openApp()
        } catch (error: Exception) {
            Toast.makeText(this, error.message ?: getString(R.string.change_failed), Toast.LENGTH_LONG).show()
        }
        updateTile()
    }

    private fun updateTile() {
        val tile = qsTile ?: return
        try {
            val enabled = debugging.isEnabled()
            val hasPermission = debugging.hasPermission()
            tile.state = if (hasPermission && enabled) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
            tile.label = getString(R.string.tile_label)
            val description = getString(when {
                !hasPermission -> R.string.tile_needs_permission
                enabled -> R.string.tile_on
                else -> R.string.tile_off
            })
            tile.contentDescription = "${getString(R.string.tile_label)}: $description"
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) tile.subtitle = description
        } catch (_: Exception) {
            tile.state = Tile.STATE_UNAVAILABLE
        }
        tile.updateTile()
    }

    private fun stopObserving() {
        if (observing) {
            contentResolver.unregisterContentObserver(observer)
            observing = false
        }
    }

    @Suppress("DEPRECATION")
    private fun openApp() {
        val intent = Intent(this, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startActivityAndCollapse(PendingIntent.getActivity(
                this, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            ))
        } else {
            startActivityAndCollapse(intent)
        }
    }
}
