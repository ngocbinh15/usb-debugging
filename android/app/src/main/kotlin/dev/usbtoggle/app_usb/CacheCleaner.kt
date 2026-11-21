package dev.usbtoggle.app_usb

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import rikka.shizuku.Shizuku

class CacheCleaner(private val activity: Activity, private val channel: MethodChannel) {
    private val handler = Handler(Looper.getMainLooper())
    private val trimmer = CacheTrimClient(activity)
    private var pending: MethodChannel.Result? = null
    private var permissionCode = 810
    private var awaitingPermission = false
    private val timeout = Runnable { finish(error = "Quá thời gian chờ Shizuku. Chưa xác nhận được kết quả dọn cache.") }
    private val permissionListener = Shizuku.OnRequestPermissionResultListener { request, grant ->
        handler.post {
            if (awaitingPermission && request == permissionCode) {
                finish(value = grant == PackageManager.PERMISSION_GRANTED)
            }
        }
    }
    private val deadListener = Shizuku.OnBinderDeadListener {
        handler.post {
            if (!Shizuku.pingBinder()) finish(error = "Shizuku đã ngắt kết nối. Hãy mở Shizuku và khởi động lại dịch vụ.")
        }
    }
    init {
        Shizuku.addRequestPermissionResultListener(permissionListener)
        Shizuku.addBinderDeadListener(deadListener)
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getStatus" -> result.success(CacheTrimClient.status())
                    "addCacheTile" -> QuickSettingsTiles.add(
                        activity, CacheCleanerTileService::class.java,
                        R.string.cache_tile_label, R.drawable.ic_cache, result::success,
                    )
                    "openShizuku" -> {
                        val intent = activity.packageManager.getLaunchIntentForPackage("moe.shizuku.privileged.api")
                            ?: Intent(Intent.ACTION_VIEW, Uri.parse("https://shizuku.rikka.app/download/"))
                        activity.startActivity(intent)
                        result.success(null)
                    }
                    "requestPermission", "clean" -> {
                        val status = CacheTrimClient.status()
                        check(status["supported"] == true) { "Dọn cache yêu cầu Android 8 trở lên." }
                        check(status["running"] == true) { "Hãy mở Shizuku và khởi động dịch vụ trước." }
                        check(pending == null) { "Đang xử lý một yêu cầu. Vui lòng chờ." }
                        if (call.method == "requestPermission" && status["granted"] == true) {
                            result.success(true)
                        } else {
                            if (call.method == "clean") {
                                check(status["granted"] == true) { "Cần cấp quyền Shizuku trước khi dọn cache." }
                            } else {
                                check(!Shizuku.shouldShowRequestPermissionRationale()) {
                                    "Quyền đã bị từ chối. Hãy cho phép app trong mục Ứng dụng được cấp quyền của Shizuku."
                                }
                            }
                            pending = result
                            if (call.method == "clean") {
                                trimmer.clean { value, error ->
                                    if (pending === result) finish(value, error)
                                }
                            } else {
                                handler.postDelayed(timeout, 90000)
                                awaitingPermission = true
                                Shizuku.requestPermission(++permissionCode)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                val message = error.message ?: "Không kết nối được Shizuku."
                if (pending === result) finish(error = message)
                else result.error("SHIZUKU_ERROR", message, null)
            }
        }
    }

    private fun finish(value: Any? = null, error: String? = null) {
        val result = pending ?: return
        pending = null
        awaitingPermission = false
        handler.removeCallbacks(timeout)
        if (error == null) result.success(value) else result.error("SHIZUKU_ERROR", error, null)
    }

    fun close() {
        channel.setMethodCallHandler(null)
        Shizuku.removeRequestPermissionResultListener(permissionListener)
        Shizuku.removeBinderDeadListener(deadListener)
        finish(error = "App đã đóng trong khi xử lý. Chưa xác nhận được kết quả.")
        trimmer.close()
    }
}
