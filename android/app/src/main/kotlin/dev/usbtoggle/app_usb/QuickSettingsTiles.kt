package dev.usbtoggle.app_usb

import android.app.Activity
import android.app.StatusBarManager
import android.content.ComponentName
import android.graphics.drawable.Icon
import android.os.Build
import android.service.quicksettings.TileService

object QuickSettingsTiles {
    fun add(activity: Activity, service: Class<out TileService>, label: Int, icon: Int, result: (String) -> Unit) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result("manual")
            return
        }
        val statusBar = activity.getSystemService(StatusBarManager::class.java)
        if (statusBar == null) {
            result("manual")
            return
        }
        statusBar.requestAddTileService(
            ComponentName(activity, service),
            activity.getString(label),
            Icon.createWithResource(activity, icon),
            activity.mainExecutor,
        ) { code ->
            result(when (code) {
                StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ADDED -> "added"
                StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ALREADY_ADDED -> "alreadyAdded"
                StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_NOT_ADDED -> "notAdded"
                else -> "manual"
            })
        }
    }
}
