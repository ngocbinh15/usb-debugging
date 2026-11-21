package dev.usbtoggle.app_usb

import android.app.Activity
import android.os.Bundle
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.ScrollView
import android.widget.TextView
import java.util.Locale

class CacheCleanActivity : Activity() {
    private lateinit var trimmer: CacheTrimClient

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setFinishOnTouchOutside(false)
        setTitle(R.string.cache_tile_label)
        val padding = (24 * resources.displayMetrics.density).toInt()
        val progress = ProgressBar(this)
        val message = TextView(this).apply {
            textSize = 17f
            setText(R.string.cache_cleaning)
            setPadding(0, padding, 0, padding)
            accessibilityLiveRegion = View.ACCESSIBILITY_LIVE_REGION_POLITE
        }
        val close = Button(this).apply {
            setText(R.string.cache_close)
            setOnClickListener { finish() }
        }
        setContentView(ScrollView(this).apply {
            addView(LinearLayout(this@CacheCleanActivity).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(padding, padding, padding, padding)
                addView(progress)
                addView(message)
                addView(close)
            })
        })
        trimmer = CacheTrimClient(this)
        if (savedInstanceState != null) {
            progress.visibility = View.GONE
            message.setText(R.string.cache_unknown_result)
            return
        }
        trimmer.clean { result, error ->
            if (isFinishing || isDestroyed) return@clean
            progress.visibility = View.GONE
            message.text = when {
                error != null -> error
                result?.get("timedOut") == true -> getString(R.string.cache_unknown_result)
                result?.get("exitCode") != 0 -> getString(R.string.cache_failed, result?.get("output").toString())
                else -> {
                    val freed = result["freedBytes"] as Long
                    getString(R.string.cache_finished, String.format(Locale.getDefault(), "%.1f", freed / 1048576.0))
                }
            }
        }
    }

    override fun onDestroy() {
        trimmer.close()
        super.onDestroy()
    }
}
