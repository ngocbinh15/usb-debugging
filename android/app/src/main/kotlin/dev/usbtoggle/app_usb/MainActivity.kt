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
    private var cacheCleaner: CacheCleaner? = null

    override fun onDestroy() {
        cacheCleaner?.close()
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        cacheCleaner?.close()
        cacheCleaner = CacheCleaner(this, MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.usbtoggle/cache_cleaner"))
        val debugging = UsbDebugging(this)
        val dns = PrivateDns(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.usbtoggle/usb_debugging")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "getStatus" -> result.success(debugging.status() + dns.status())
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
                        "setDnsPrivate" -> {
                            val enabled = call.arguments as? Boolean
                                ?: throw IllegalArgumentException("Expected a Boolean")
                            dns.setPrivate(enabled)
                            result.success(null)
                        }
                        "openDnsSettings" -> {
                            try {
                                startActivity(Intent(Settings.ACTION_WIRELESS_SETTINGS))
                            } catch (_: ActivityNotFoundException) {
                                startActivity(Intent(Settings.ACTION_SETTINGS))
                            }
                            result.success(null)
                        }
                        "addTile" -> addTile(result)
                        "addDnsTile" -> {
                            check(Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                                getString(R.string.dns_unsupported)
                            }
                            addTile(result, privateDns = true)
                        }
                        else -> result.notImplemented()
                    }
                } catch (_: SecurityException) {
                    result.error("PERMISSION_DENIED", getString(R.string.permission_required), null)
                } catch (error: Exception) {
                    result.error("ANDROID_ERROR", error.message ?: getString(R.string.change_failed), null)
                }
            }
    }

    private fun addTile(result: MethodChannel.Result, privateDns: Boolean = false) {
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
            ComponentName(this, if (privateDns) PrivateDnsTileService::class.java else UsbDebuggingTileService::class.java),
            getString(if (privateDns) R.string.dns_tile_label else R.string.tile_label),
            Icon.createWithResource(this, if (privateDns) R.drawable.ic_dns else R.drawable.ic_usb),
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
