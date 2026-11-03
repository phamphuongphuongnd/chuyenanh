package com.phuong.pdfoffice

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException

/**
 * Nén ảnh bằng bộ mã hoá của Android (libjpeg-turbo), nhanh hơn nhiều lần gói `image` Dart thuần
 * trên máy 32-bit yếu.
 *
 * Kênh `com.phuong.pdfoffice/image_codec`:
 *  - `encodeJpeg({rgba, width, height, quality})` -> ByteArray: điểm ảnh RGBA (alpha nhân sẵn, như
 *    `ui.ImageByteFormat.rawRgba`) trộn lên nền trắng rồi nén JPEG.
 */
class ImageCodecChannel(messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.phuong.pdfoffice/image_codec"
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private val mainHandler = Handler(Looper.getMainLooper())

    // 2 luồng: slide sau nén song song với slide trước mà không chiếm hết CPU.
    private val executor: ExecutorService = Executors.newFixedThreadPool(2)

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        executor.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "encodeJpeg") {
            result.notImplemented()
            return
        }
        val rgba = call.argument<ByteArray>("rgba")
        val width = call.argument<Int>("width") ?: 0
        val height = call.argument<Int>("height") ?: 0
        val quality = (call.argument<Int>("quality") ?: 90).coerceIn(1, 100)
        if (rgba == null || width <= 0 || height <= 0 || rgba.size < width * height * 4) {
            result.error("bad_args", "rgba/width/height", null)
            return
        }
        try {
            executor.execute {
                val out = try {
                    encode(rgba, width, height, quality)
                } catch (e: Throwable) {
                    // OutOfMemoryError, IllegalArgumentException…: Dart tự nén lại bằng gói `image`.
                    null
                }
                mainHandler.post {
                    if (out != null) result.success(out) else result.error("encode_failed", null, null)
                }
            }
        } catch (e: RejectedExecutionException) {
            result.error("encode_failed", "executor closed", null)
        }
    }

    private fun encode(rgba: ByteArray, width: Int, height: Int, quality: Int): ByteArray {
        // ARGB_8888 lưu từng điểm theo thứ tự byte R, G, B, A (nhân sẵn alpha) = đúng rawRgba.
        val src = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        try {
            src.copyPixelsFromBuffer(ByteBuffer.wrap(rgba, 0, width * height * 4))
            val flat = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            try {
                Canvas(flat).apply {
                    drawColor(Color.WHITE)
                    drawBitmap(src, 0f, 0f, null)
                }
                val bos = ByteArrayOutputStream(width * height / 4)
                if (!flat.compress(Bitmap.CompressFormat.JPEG, quality, bos)) {
                    throw IllegalStateException("compress returned false")
                }
                return bos.toByteArray()
            } finally {
                flat.recycle()
            }
        } finally {
            src.recycle()
        }
    }
}
