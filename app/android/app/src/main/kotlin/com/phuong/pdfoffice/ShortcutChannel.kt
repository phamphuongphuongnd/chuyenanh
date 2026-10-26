package com.phuong.pdfoffice

import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Lối tắt màn hình chính cho một file PDF (Android 8.0+).
 *
 * Kênh `com.phuong.pdfoffice/shortcut`:
 *  - `isSupported` -> Boolean: launcher có hỗ trợ ghim lối tắt không (false trên Android 7).
 *  - `requestPinShortcut({path, label})` -> Boolean: yêu cầu ghim; người dùng xác nhận trên launcher.
 *  - `takeInitialPath` -> String?: đường dẫn file của intent đã mở app (trả một lần rồi xoá).
 *  - Native -> Dart `openPath(path)`: gọi khi app đang chạy và nhận intent mới (`onNewIntent`).
 *
 * Intent của lối tắt là intent tường minh tới [MainActivity] (action [ACTION_OPEN_PDF],
 * extra [EXTRA_PATH]) nên không cần khai thêm intent-filter trong Manifest.
 */
class ShortcutChannel(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.phuong.pdfoffice/shortcut"
        const val ACTION_OPEN_PDF = "com.phuong.pdfoffice.action.OPEN_PDF"
        const val EXTRA_PATH = "com.phuong.pdfoffice.extra.PDF_PATH"
    }

    private val channel = MethodChannel(messenger, CHANNEL)

    /** Intent đã mở app lúc khởi động; Dart lấy qua `takeInitialPath`. */
    private var launchIntent: Intent? = null

    init {
        channel.setMethodCallHandler(this)
    }

    /** Gọi từ `configureFlutterEngine` với intent mở Activity. */
    fun handleLaunchIntent(intent: Intent?) {
        launchIntent = intent
    }

    /** Gọi từ `onNewIntent`: báo cho Dart mở file ngay. */
    fun handleNewIntent(intent: Intent?) {
        val path = extractPath(intent) ?: return
        consume(intent)
        channel.invokeMethod("openPath", path)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        launchIntent = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(isSupported())
            "requestPinShortcut" -> {
                val path = call.argument<String>("path")
                val label = call.argument<String>("label")
                if (path.isNullOrEmpty()) {
                    result.error("bad_args", "path is required", null)
                } else {
                    result.success(requestPin(path, label))
                }
            }
            "takeInitialPath" -> {
                val intent = launchIntent
                val path = extractPath(intent)
                consume(intent)
                launchIntent = null
                result.success(path)
            }
            else -> result.notImplemented()
        }
    }

    private fun extractPath(intent: Intent?): String? {
        if (intent == null || intent.action != ACTION_OPEN_PDF) return null
        return intent.getStringExtra(EXTRA_PATH)?.takeIf { it.isNotEmpty() }
    }

    /** Xoá dấu vết để không mở lại khi Activity được dựng lại từ lịch sử. */
    private fun consume(intent: Intent?) {
        intent?.removeExtra(EXTRA_PATH)
        intent?.action = Intent.ACTION_MAIN
    }

    private fun shortcutManager(): ShortcutManager? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.getSystemService(ShortcutManager::class.java)
        } else {
            null
        }

    private fun isSupported(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        return shortcutManager()?.isRequestPinShortcutSupported == true
    }

    private fun requestPin(path: String, label: String?): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val manager = shortcutManager() ?: return false
        if (!manager.isRequestPinShortcutSupported) return false

        val name = (label ?: "").ifBlank { path.substringAfterLast('/') }.ifBlank { "PDF" }
        val intent = Intent(context, MainActivity::class.java).apply {
            action = ACTION_OPEN_PDF
            putExtra(EXTRA_PATH, path)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val info = ShortcutInfo.Builder(context, "pdf_" + path.hashCode())
            .setShortLabel(name.take(24))
            .setLongLabel(name)
            .setIcon(Icon.createWithResource(context, R.mipmap.ic_launcher))
            .setIntent(intent)
            .build()
        return manager.requestPinShortcut(info, null)
    }
}
