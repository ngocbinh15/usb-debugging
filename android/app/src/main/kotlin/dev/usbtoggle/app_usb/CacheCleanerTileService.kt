package dev.usbtoggle.app_usb

import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.widget.Toast
import rikka.shizuku.Shizuku

class CacheCleanerTileService : TileService() {
    private val receivedListener = Shizuku.OnBinderReceivedListener { updateTile() }
    private val deadListener = Shizuku.OnBinderDeadListener { updateTile() }

    override fun onCreate() {
        super.onCreate()
        Shizuku.addBinderReceivedListenerSticky(receivedListener)
        Shizuku.addBinderDeadListener(deadListener)
    }

    override fun onStartListening() {
        super.onStartListening()
        updateTile()
    }

    override fun onDestroy() {
        Shizuku.removeBinderReceivedListener(receivedListener)
        Shizuku.removeBinderDeadListener(deadListener)
        super.onDestroy()
    }

    override fun onClick() {
        super.onClick()
        if (isLocked) unlockAndRun { clean() } else clean()
    }

    private fun clean() {
        if (CacheTrimClient.isCleaning) {
            Toast.makeText(this, R.string.cache_cleaning, Toast.LENGTH_SHORT).show()
            return
        }
        val ready = try {
            CacheTrimClient.status().values.all { it }
        } catch (_: Exception) {
            false
        }
        if (!ready) {
            Toast.makeText(this, R.string.cache_setup_hint, Toast.LENGTH_LONG).show()
        }
        open(if (ready) CacheCleanActivity::class.java else MainActivity::class.java)
    }

    private fun updateTile() {
        val tile = qsTile ?: return
        val description = try {
            val status = CacheTrimClient.status()
            when {
                status["supported"] != true -> R.string.cache_unsupported
                CacheTrimClient.isCleaning -> R.string.cache_cleaning
                status["running"] != true -> R.string.cache_needs_shizuku
                status["granted"] != true -> R.string.cache_needs_permission
                else -> R.string.cache_ready
            }
        } catch (_: Exception) {
            R.string.cache_needs_shizuku
        }
        tile.label = getString(R.string.cache_tile_label)
        tile.state = Tile.STATE_INACTIVE
        tile.contentDescription = "${tile.label}: ${getString(description)}"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) tile.subtitle = getString(description)
        tile.updateTile()
    }

    @Suppress("DEPRECATION")
    private fun open(activity: Class<out android.app.Activity>) {
        val intent = Intent(this, activity)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startActivityAndCollapse(PendingIntent.getActivity(
                this, 2, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            ))
        } else {
            startActivityAndCollapse(intent)
        }
    }
}
