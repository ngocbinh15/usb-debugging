package dev.usbtoggle.app_usb

import android.os.Build
import android.os.Bundle
import androidx.annotation.Keep
import java.io.File
import java.io.IOException
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread
import kotlin.system.exitProcess

@Keep
class CacheTrimService : ICacheTrimmer.Stub() {
    @Volatile private var process: Process? = null

    @Synchronized
    override fun trim(): Bundle {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            throw UnsupportedOperationException("Cần Android 8 trở lên.")
        }
        val before = File("/data").usableSpace
        // Request maximum trimming; Android can retain caches and does not report per-app results.
        val command = ProcessBuilder("/system/bin/pm", "trim-caches", Long.MAX_VALUE.toString(), "internal")
            .redirectErrorStream(true).start()
        process = command
        val output = StringBuffer()
        val reader = thread(name = "cache-trim-output") {
            try {
                command.inputStream.bufferedReader().useLines { lines ->
                    lines.forEach { line ->
                        if (output.length < 4096) output.append((line + "\n").take(4096 - output.length))
                    }
                }
            } catch (_: IOException) {
                // The stream closes when a timed-out subprocess is stopped.
            }
        }
        try {
            val completed = command.waitFor(60, TimeUnit.SECONDS)
            if (!completed) command.destroyForcibly()
            reader.join(1000)
            return Bundle().apply {
                putInt("exitCode", if (completed) command.exitValue() else -1)
                putString("output", output.toString().trim())
                putBoolean("timedOut", !completed)
                putLong("freedBytes", (File("/data").usableSpace - before).coerceAtLeast(0))
            }
        } finally {
            command.destroy()
            process = null
        }
    }

    override fun destroy() {
        process?.destroy()
        exitProcess(0)
    }
}
