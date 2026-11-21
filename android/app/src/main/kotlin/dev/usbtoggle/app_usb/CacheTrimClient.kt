package dev.usbtoggle.app_usb

import android.content.ComponentName
import android.content.Context
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import rikka.shizuku.Shizuku
import java.util.concurrent.Executors

class CacheTrimClient(context: Context) {
    companion object {
        // All callers run on the main thread and share one Shizuku UserService.
        private var owner: CacheTrimClient? = null
        val isCleaning: Boolean get() = owner != null

        fun status(): Map<String, Boolean> {
            val running = Shizuku.pingBinder() && !Shizuku.isPreV11()
            return mapOf(
                "supported" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O),
                "running" to running,
                "granted" to (running && Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED),
            )
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val serviceArgs = Shizuku.UserServiceArgs(ComponentName(context, CacheTrimService::class.java))
        .daemon(false).processNameSuffix("cache_trim").tag("cache_trim").version(1)
    private var pending: ((Map<String, Any>?, String?) -> Unit)? = null
    private var connection: ServiceConnection? = null
    private val timeout = Runnable {
        finish(error = "Quá thời gian chờ Shizuku. Chưa xác nhận được kết quả dọn cache.")
    }
    private val deadListener = Shizuku.OnBinderDeadListener {
        handler.post {
            if (!Shizuku.pingBinder()) finish(error = "Shizuku đã ngắt kết nối. Chưa xác nhận được kết quả dọn cache.")
        }
    }

    init {
        Shizuku.addBinderDeadListener(deadListener)
    }

    fun clean(callback: (Map<String, Any>?, String?) -> Unit) {
        try {
            check(!isCleaning) { "Đang dọn cache. Vui lòng chờ." }
            val status = status()
            check(status["supported"] == true) { "Dọn cache yêu cầu Android 8 trở lên." }
            check(status["running"] == true) { "Hãy mở Shizuku và khởi động dịch vụ trước." }
            check(status["granted"] == true) { "Cần cấp quyền Shizuku trước khi dọn cache." }
        } catch (error: Exception) {
            callback(null, error.message ?: "Không kết nối được Shizuku.")
            return
        }
        owner = this
        pending = callback
        handler.postDelayed(timeout, 90000)
        val connection = object : ServiceConnection {
            override fun onServiceConnected(name: ComponentName, binder: IBinder) {
                handler.post {
                    if (pending !== callback) return@post
                    worker.execute {
                        try {
                            val result = ICacheTrimmer.Stub.asInterface(binder).trim()
                            handler.post {
                                if (pending === callback) finish(value = mapOf(
                                    "exitCode" to result.getInt("exitCode"),
                                    "output" to result.getString("output").orEmpty(),
                                    "timedOut" to result.getBoolean("timedOut"),
                                    "freedBytes" to result.getLong("freedBytes"),
                                ))
                            }
                        } catch (error: Exception) {
                            handler.post {
                                if (pending === callback) finish(error = error.message ?: "Mất kết nối với dịch vụ dọn cache.")
                            }
                        }
                    }
                }
            }

            override fun onServiceDisconnected(name: ComponentName) {
                handler.post {
                    if (pending === callback) finish(error = "Dịch vụ dọn cache đã dừng; chưa xác nhận được kết quả.")
                }
            }
        }
        this.connection = connection
        try {
            Shizuku.bindUserService(serviceArgs, connection)
        } catch (error: Exception) {
            finish(error = error.message ?: "Không kết nối được dịch vụ dọn cache.")
        }
    }

    private fun finish(value: Map<String, Any>? = null, error: String? = null) {
        val callback = pending ?: return
        pending = null
        if (owner === this) owner = null
        handler.removeCallbacks(timeout)
        val connection = this.connection
        this.connection = null
        if (connection != null) {
            try {
                Shizuku.unbindUserService(serviceArgs, connection, true)
            } catch (_: RuntimeException) {
                // A dead Shizuku process has no service left to unbind.
            }
        }
        callback(value, error)
    }

    fun close() {
        Shizuku.removeBinderDeadListener(deadListener)
        finish(error = "Màn hình đã đóng trong khi xử lý. Chưa xác nhận được kết quả.")
        worker.shutdownNow()
    }
}
