package dev.usbtoggle.app_usb

import android.app.StatusBarManager
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val debugging = UsbDebugging(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.usbtoggle/usb_debugging")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "getStatus" -> result.success(debugging.status())
                        "setEnabled" -> {
                            val enabled = call.arguments as? Boolean
                                ?: throw IllegalArgumentException("Expected a Boolean")
                            debugging.setEnabled(enabled)
                            result.success(null)
                        }
                        "openDeveloperSettings" -> {
                            try {
                                startActivity(Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS))
                            } catch (_: ActivityNotFoundException) {
                                startActivity(Intent(Settings.ACTION_SETTINGS))
                            }
                            result.success(null)
                        }
                        "addTile" -> addTile(result)
                        else -> result.notImplemented()
                    }
                } catch (_: SecurityException) {
                    result.error("PERMISSION_DENIED", getString(R.string.permission_required), null)
                } catch (error: Exception) {
                    result.error("ANDROID_ERROR", error.message ?: getString(R.string.change_failed), null)
                }
            }
    }

    private fun addTile(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success("manual")
            return
        }
        val statusBar = getSystemService(StatusBarManager::class.java)
        if (statusBar == null) {
            result.success("manual")
            return
        }
        statusBar.requestAddTileService(
            ComponentName(this, UsbDebuggingTileService::class.java),
            getString(R.string.tile_label),
            Icon.createWithResource(this, R.drawable.ic_usb),
            mainExecutor,
        ) { code ->
            result.success(when (code) {
                StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ADDED -> "added"
                StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ALREADY_ADDED -> "alreadyAdded"
                StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_NOT_ADDED -> "notAdded"
                else -> "manual"
            })
        }
    }
}
