package dev.usbtoggle.app_usb

import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import rikka.shizuku.Shizuku
import java.util.concurrent.Executors

class CacheCleaner(private val activity: Activity, private val channel: MethodChannel) {
    private val handler = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val serviceArgs = Shizuku.UserServiceArgs(ComponentName(activity, CacheTrimService::class.java))
        .daemon(false).processNameSuffix("cache_trim").tag("cache_trim").version(1)
    private var pending: MethodChannel.Result? = null
    private var connection: ServiceConnection? = null
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
    private fun connect(request: MethodChannel.Result) {
        val callback = object : ServiceConnection {
            override fun onServiceConnected(name: ComponentName, binder: IBinder) {
                handler.post {
                    if (pending !== request) return@post
                    worker.execute {
                        try {
                            val result = ICacheTrimmer.Stub.asInterface(binder).trim()
                            handler.post response@{
                                if (pending !== request) return@response
                                finish(value = mapOf(
                                    "exitCode" to result.getInt("exitCode"),
                                    "output" to result.getString("output").orEmpty(),
                                    "timedOut" to result.getBoolean("timedOut"),
                                    "freedBytes" to result.getLong("freedBytes"),
                                ))
                            }
                        } catch (error: Exception) {
                            handler.post {
                                if (pending === request) finish(error = error.message ?: "Mất kết nối với dịch vụ dọn cache.")
                            }
                        }
                    }
                }
            }

            override fun onServiceDisconnected(name: ComponentName) {
                handler.post {
                    if (pending === request) finish(error = "Dịch vụ dọn cache đã dừng; chưa xác nhận được kết quả.")
                }
            }
        }
        connection = callback
        Shizuku.bindUserService(serviceArgs, callback)
    }

    init {
        Shizuku.addRequestPermissionResultListener(permissionListener)
        Shizuku.addBinderDeadListener(deadListener)
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getStatus" -> result.success(status())
                    "openShizuku" -> {
                        val intent = activity.packageManager.getLaunchIntentForPackage("moe.shizuku.privileged.api")
                            ?: Intent(Intent.ACTION_VIEW, Uri.parse("https://shizuku.rikka.app/download/"))
                        activity.startActivity(intent)
                        result.success(null)
                    }
                    "requestPermission", "clean" -> {
                        val status = status()
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
                            handler.postDelayed(timeout, 90000)
                            if (call.method == "clean") {
                                connect(result)
                            } else {
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

    private fun status(): Map<String, Boolean> {
        val running = Shizuku.pingBinder() && !Shizuku.isPreV11()
        return mapOf(
            "supported" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O),
            "running" to running,
            "granted" to (running && Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED),
        )
    }

    private fun finish(value: Any? = null, error: String? = null) {
        val result = pending ?: return
        pending = null
        awaitingPermission = false
        handler.removeCallbacks(timeout)
        val callback = connection
        connection = null
        if (callback != null) {
            try {
                Shizuku.unbindUserService(serviceArgs, callback, true)
            } catch (_: RuntimeException) {
                // A dead Shizuku process has no service left to unbind.
            }
        }
        if (error == null) result.success(value) else result.error("SHIZUKU_ERROR", error, null)
    }

    fun close() {
        channel.setMethodCallHandler(null)
        Shizuku.removeRequestPermissionResultListener(permissionListener)
        Shizuku.removeBinderDeadListener(deadListener)
        finish(error = "App đã đóng trong khi xử lý. Chưa xác nhận được kết quả.")
        worker.shutdownNow()
    }
}
